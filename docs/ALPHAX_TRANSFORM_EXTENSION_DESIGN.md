# AlphaX optional large-payload transform extension design

Status: Design only. No package, production code, or `alphax` core interface is
implemented by this task.

## Executive decision

Task 37 found a real user-visible problem, but only for a specific workload:
synchronous JSON decode and model mapping on the caller isolate. On the measured
Android device, a 5 MiB payload produced an approximately 69 ms main-isolate
gap and a 10 MiB payload produced an approximately 122 ms gap. One-shot worker
modes reduced the main-isolate gap to roughly 20–34 ms, at the cost of higher
total latency, transfer work, and often higher memory. A persistent worker did
not consistently beat one-shot isolation after those costs were included.

The recommended product shape is a small, opt-in pure-Dart `alphax_transform`
package. It should provide one deep module at a small seam: collect or receive
already-buffered bytes, run a caller-supplied sendable JSON transform once on a
native Dart isolate, and return either the sendable result or a normalized
cancellation/error. It must not become transport middleware, a model registry,
or a worker framework.

This recommendation is for a future implementation task. It does not authorize
implementation in Task 40.

## 1. Measured motivation

The evidence is the retained Task 37 parsing microbenchmark, not a claim about
all devices or all JSON shapes. It used deterministic JSON at 100 KiB, 1 MiB,
5 MiB, and 10 MiB and separated preparation, parse, model mapping, total
latency, event-loop gaps, frame observations, memory, and checksums.

| Payload | Caller-isolate total median | Caller-isolate main-loop gap | One-shot worker direction | Interpretation |
| --- | ---: | ---: | --- | --- |
| 100 KiB | 3.60 ms | 5.70 ms | 6.49–7.03 ms total | Synchronous work is normally the better tradeoff. |
| 1 MiB | 17.68 ms | 17.89 ms | 42.77–50.96 ms total | Worker protects responsiveness but costs substantially more. |
| 5 MiB | 68.63 ms | 69.05 ms | 79.64–95.27 ms total | A frame-visible stall; one-shot isolation is worth considering. |
| 10 MiB | 122.25 ms | 122.49 ms | 178.34–202.83 ms total | A severe frame-visible stall; isolation is a plausible UX trade. |

The same direction appeared on macOS with lower absolute cost: approximately
34 ms synchronous versus 42–44 ms worker total time at 5 MiB, and approximately
66 ms synchronous versus 82–95 ms worker total time at 10 MiB. The macOS host
does not establish an iPhone threshold.

The current AlphaX response interface intentionally leaves `readAsJson()` on
the caller isolate after the response body is available. This is correct and
predictable for the core, but it means the application owns the decision about
large parsing. The proposed extension addresses ergonomics around that
decision; it does not move transport delivery, backpressure, or response
completion into an isolate.

Evidence: [Task 37](../tasks/37-post-1-0-integration-cost-spike.md) and the
[integration-cost results](ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md).

## 2. Alternatives

| Option | Depth and leverage | Cost and limitation | Decision |
| --- | --- | --- | --- |
| A. Documentation only | Keeps the seam in the caller; no package cost. `Isolate.run` is already a small interface for occasional work. | Every caller repeats byte preparation, sendability warnings, cancellation/discard handling, and profiling labels. | Viable baseline and required documentation even if a package is added. |
| B. Tiny `alphax_transform` helper | One AlphaX-shaped interface hides the repeatable isolate/UTF-8/JSON plumbing while keeping policy opt-in. | Adds a package interface and must be strict about sendability and Web behavior. | Recommended. |
| C. Tiny `alphax_compute` package | A generic name could serve non-JSON transforms. | It invites a shallow grab-bag of worker utilities and has less AlphaX-specific leverage. | Not the first package name; reconsider only if non-JSON demand is measured. |
| D. Automatic transform middleware in `alphax` | Could make large JSON appear effortless at call sites. | It would silently change CPU, memory, ordering, errors, and Web behavior; middleware cannot infer a safe model transform. | Reject. Core remains synchronous and transport-independent. |
| E. Persistent worker or pool | Could amortize startup for repeated compatible jobs. | Requires a queue, lifecycle, cancellation, fairness, error routing, memory-retention policy, and worker affinity. Task 37 did not show a consistent win. | Reject for now. |

The deletion test favors the small optional helper only when it removes repeated
caller ceremony. It must not merely forward `Isolate.run` with a larger
interface; the implementation should earn its seam by making input transfer,
JSON decoding, diagnostics, and discard semantics consistent.

## 3. Proposed interface sketches

The following is deliberately a sketch, not a frozen public interface.

```dart
import 'dart:typed_data';

import 'package:alphax/alphax.dart';

typedef AlphaXJsonTransform<T> = T Function(Object? decodedJson);

Future<T> decodeJson<T>({
  required Uint8List bytes,
  required AlphaXJsonTransform<T> transform,
  AlphaXCancellationToken? cancellationToken,
  String? debugName,
});
```

The small interface has one operation and makes the important facts visible:

- `bytes` are already buffered. The first version does not own an AlphaX
  response stream and does not pretend to provide streaming JSON decoding.
- `transform` runs in the worker after `jsonDecode`. It must be a top-level or
  static function, or another closure whose captured state is safely sendable.
  It must not capture a `BuildContext`, socket, file handle, client, plugin
  object, or other native resource.
- `T` must be safe to return across the isolate seam. A caller that creates a
  platform-bound or isolate-unsendable object must instead return a portable
  representation or perform that final attachment on the caller isolate.
- `debugName` is diagnostic metadata only; it does not alter scheduling.
- The optional token is the existing `AlphaXCancellationToken`, so the package
  does not invent a second cancellation vocabulary or change the core contract.

The conceptual native implementation is:

```text
caller Uint8List
  -> check cancellation
  -> create TransferableTypedData when supported
  -> Isolate.run
       -> materialize bytes
       -> UTF-8 decode
       -> jsonDecode
       -> caller-supplied transform
  -> return/discard result according to cancellation state
```

The extension should not add a response middleware that automatically calls
this function. The caller should make the performance decision explicitly:

```dart
final bytes = await response.readAsBytes();
final model = await decodeJson(
  bytes: Uint8List.fromList(bytes),
  transform: UserModel.fromDecodedJson,
  cancellationToken: token,
  debugName: 'user-model-decode',
);
```

The exact convenience around `List<int>` versus `Uint8List` should be settled
in implementation review. Avoiding an unnecessary `Uint8List.fromList` is
preferable, but the interface must not imply ownership of a mutable caller
buffer.

## 4. Package boundary and seam

Place the module in a separately publishable `alphax_transform` package:

```text
alphax_transform
  -> alphax (only for AlphaXCancellationToken and shared error vocabulary)
  -> dart:isolate / dart:convert / dart:typed_data

alphax       remains unaware of alphax_transform
alphax_native remains unaware of alphax_transform
```

This preserves the accepted architecture. `alphax` remains pure Dart and
transport-independent; `alphax_native` continues to own Cronet and URLSession
integration; and applications decide whether a buffered response should be
transformed away from the caller isolate.

The package should be a deep module at the application seam: one small
interface, with the implementation responsible for the isolate entry point,
transfer representation, JSON decoding, error forwarding, cancellation race,
and diagnostic name. It should not expose a `SendPort`, `ReceivePort`, worker
handle, queue, or transport-specific type in its first interface.

Do not add a Flutter dependency. Flutter callers can use the pure-Dart module;
Flutter's `compute` remains a caller-owned alternative when a Flutter-specific
callback shape is preferable.

## 5. Dart, Flutter, and Web behavior

### Native Dart and Flutter

Use `Isolate.run` as the default implementation seam. It creates a fresh
isolate per call, awaits an asynchronous computation in that isolate, forwards
errors, and requires the computation and result to be sendable. This is
available without importing Flutter. `compute` is a Flutter convenience with
equivalent native-isolate behavior, but using it in the package would make the
package Flutter-dependent.

The worker must not access AlphaX transports, open files, sockets, UI objects,
or mutable application singletons. All required state crosses the seam as
explicit data or as the sendable transform closure.

### Web

The first interface must not claim browser background execution. A browser
implementation has two honest choices:

1. report background transformation as unsupported and let the caller choose
   synchronous `jsonDecode`; or
2. provide an explicitly documented synchronous fallback with a name/option
   that makes the absence of background execution clear.

The recommended first version is option 1. It fails closed rather than making a
large Web transform look asynchronous while still running on the browser event
loop. A future Web-specific implementation would need a separate experiment;
it must not be inferred from native isolate results.

This differs from Flutter's `compute` contract, which documents that on Web the
callback runs on the current event loop. That behavior is useful knowledge for
callers, but it is not background execution and should not be hidden behind a
claim of UI offload.

## 6. Cancellation and discard model

Cancellation is cooperative and must be documented as such:

1. Before byte preparation, check the token and throw the existing normalized
   AlphaX cancellation exception if already cancelled.
2. Before dispatch, check again. If cancellation wins the race, do not create a
   worker or transfer the bytes.
3. After `Isolate.run` has been dispatched, cancellation completes the helper
   with cancellation and discards a later result. The one-shot computation may
   continue consuming CPU until it returns because `Isolate.run` does not give
   the caller a worker handle to kill.
4. A late worker result must never be delivered as a successful model after the
   caller has cancelled. No synthetic partial or 100% result is produced.

If the caller is still receiving the response, it should cancel the AlphaX
request token separately. The first helper should accept bytes rather than a
`Stream<List<int>>`, so it cannot accidentally own a transport subscription or
weaken native backpressure. A future stream-aware module would require its own
design and cancellation tests.

Errors thrown by JSON decoding or the transform should complete the returned
future with the worker error and stack information available from the isolate
mechanism. The helper must not wrap ordinary parse errors as transport errors.

## 7. TransferableTypedData assessment

`TransferableTypedData` is useful but is not zero-copy transport. The official
Dart contract says construction takes time proportional to the byte count,
sending the transferable between isolates is constant-time, and materializing
it creates a `ByteBuffer` in the receiving isolate. It can remove a large
message-copy cost, but it does not remove:

- the caller's initial body buffering;
- the preparation cost of creating the transferable;
- the worker's materialization and UTF-8 conversion;
- JSON token/object allocation;
- model allocation;
- the result transfer back to the caller.

Task 37 measured the tradeoff rather than assuming it. At 5 MiB,
`TransferableTypedData` preparation was approximately 3.21 ms versus 10.91 ms
for the one-shot string path, and its total median was approximately 79.64 ms
versus 95.27 ms. At 10 MiB, the transferable total was approximately 202.83 ms
versus 191.44 ms for the string path. The helper may choose the transferable
representation on native VM targets, but it must not promise that it wins for
every payload or model.

The implementation should retain one owned reference per phase, release local
references promptly after materialization, and avoid retaining both the full
input bytes and a full decoded string longer than necessary. These are
implementation goals, not a reason to expose native buffers or FFI.

## 8. Threshold guidance

Do not hard-code a universal byte threshold in `alphax` core or in the first
extension interface. Payload shape, nesting, string content, model mapping,
device speed, concurrent work, and frame rate matter as much as bytes.

Measured guidance for application profiling is:

- around 100 KiB: synchronous work was clearly the lower-total-cost choice in
  the retained run;
- around 1 MiB: measure before offloading; isolation protected some main-loop
  time but cost materially more total time;
- around 5 MiB: begin considering one-shot isolation when the transform occurs
  during active UI work;
- around 10 MiB: treat synchronous decode/model mapping as a likely frame-risk
  and validate the isolated alternative on the target device.

These are starting points derived from one measured device and schema, not
defaults. The package documentation should show how an application can profile
its own transform and choose synchronously for small/cheap work.

## 9. Binary, dependency, and compatibility impact

- No `alphax` core dependency or public core interface changes.
- `alphax_transform` adds no native engine, C/C++/Rust code, FFI, or platform
  plugin.
- Dart-only users pay the package's code size only when they depend on it; the
  core package remains unchanged.
- A pure-Dart package avoids forcing Flutter into command-line, server, test,
  and package consumers.
- The optional dependency on `alphax` is one-way and independently publishable.
- The first release should not add a persistent isolate, background service,
  cache, queue, or code-generation dependency.
- There is no transport protocol or binary-format impact; the extension works
  after `readAsBytes()` regardless of whether the response came from Cronet,
  URLSession, Dart IO, or another AlphaX transport.

## 10. Risks and mitigations

| Risk | Mitigation in the proposed interface |
| --- | --- |
| Caller sends a closure that captures non-sendable or excessive state. | Require top-level/static/sendable transforms; document closure capture costs and fail with the isolate error. |
| Worker lowers frame time but raises total CPU/RSS. | Report main-isolate blocking, total latency, CPU, heap, and RSS separately; keep the helper opt-in. |
| Cancellation appears to stop work but the worker continues. | Document post-dispatch discard semantics; do not promise hard cancellation. |
| Model instances cannot cross the isolate seam safely. | Require sendable results and show portable result alternatives; no hidden model registry. |
| Web callers assume asynchronous means background. | Prefer explicit unsupported behavior in the first version; document current-event-loop limitations. |
| A JSON helper grows into a general worker framework. | One operation, one-shot execution, no ports/pools/queue in the initial interface. |
| A byte threshold becomes a misleading global policy. | Provide measured guidance only; let applications choose based on payload and device profiling. |
| The helper is used after a stream has already caused avoidable buffering. | Accept already-buffered bytes explicitly and state that streaming transformation is out of scope. |

## 11. Recommendation and validation gate for implementation

Implement only after maintainer approval as a separate package task. That task
should prove the interface with:

- deterministic 100 KiB, 1 MiB, 5 MiB, and 10 MiB JSON fixtures;
- synchronous caller decode versus one-shot helper, with and without
  `TransferableTypedData` where supported;
- top-level/static transform success and sendability failures;
- JSON and transform error forwarding;
- cancellation before dispatch and cancellation after dispatch with result
  discard;
- native Dart and Flutter profile measurements for main-isolate blocked time,
  total latency, CPU, heap/RSS, and GC observations;
- an explicit Web test proving the selected unsupported/fallback semantics;
- package size and dependency checks.

Do not add automatic transformation to AlphaX responses, a persistent worker,
or a public byte threshold until a later workload supplies evidence that the
small one-shot module is insufficient.

### Official API references

- [Dart `Isolate.run`](https://api.dart.dev/dart-isolate/Isolate/run.html)
- [Dart `TransferableTypedData`](https://api.dart.dev/dart-isolate/TransferableTypedData-class.html)
- [Dart `SendPort.send`](https://api.dart.dev/dart-isolate/SendPort/send.html)
- [Dart `Isolate.spawn`](https://api.dart.dev/dart-isolate/Isolate/spawn.html)
- [Flutter `compute`](https://api.flutter.dev/flutter/foundation/compute.html)

IMPLEMENT OPTIONAL TRANSFORM EXTENSION
