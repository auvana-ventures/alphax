# AlphaX transform extension implementation

Status: implementation complete; maintainer review pending.

## Executive result

`alphax_transform` is implemented as an optional, independently publishable,
pure-Dart package. It exposes one explicit operation, `decodeJson`, which takes
already-buffered `Uint8List` bytes and a caller-supplied transform. Native Dart
VM and native Flutter targets use one `Isolate.run` per call. Browser targets
fail closed with `AlphaXTransformUnsupportedException` rather than claiming
background execution.

No `alphax` core semantics, `alphax_native` transport, chunk/window default,
automatic response transformation, persistent worker, Flutter dependency,
streaming parser, FFI/shared buffer, or public transport API was added.

## 1. Final public API

The package exports the following operation and typedef:

```dart
typedef AlphaXJsonTransform<T> = T Function(Object? decodedJson);

Future<T> decodeJson<T>({
  required Uint8List bytes,
  required AlphaXJsonTransform<T> transform,
  AlphaXCancellationToken? cancellationToken,
  String? debugName,
});
```

It also exports the package-specific `AlphaXTransformUnsupportedException`
used by the Web implementation. `AlphaXCancellationToken` remains defined and
owned by `alphax`; callers import that package for the token.

The API is intentionally one operation rather than a class hierarchy. The
caller decides when to buffer a response and when the measured UI benefit is
worth the isolate and memory cost.

## 2. Package dependency graph

```text
alphax_transform
└── alphax                 cancellation token and normalized cancellation error

alphax                      does not depend on alphax_transform
alphax_native                does not depend on alphax_transform
```

The package uses only Dart libraries beyond `alphax`: `dart:async`,
`dart:convert`, `dart:isolate`, and `dart:typed_data` on native targets. The
Web implementation does not import `dart:isolate`. There is no Flutter, Dio,
`package:http`, platform-plugin, native-engine, C++, Rust, libcurl, or FFI
dependency.

The package is registered in the repository workspace but remains separately
publishable. The root package list and architecture map describe it as an
optional post-1.0 extension; `alphax` does not re-export or automatically use
it.

## 3. Native execution model

The native sequence is:

```text
caller Uint8List
  │
  ├─ cancellation check
  ├─ TransferableTypedData.fromList([bytes])
  ├─ cancellation check
  ├─ one Isolate.run(debugName: ...)
  │    ├─ materialize bytes
  │    ├─ UTF-8 decode
  │    ├─ jsonDecode
  │    └─ caller transform
  └─ return result, or discard it if cancellation wins after dispatch
```

There is no `SendPort`, `ReceivePort`, worker handle, queue, scheduler, or
worker reuse. Each call is one-shot. `debugName` is passed only as isolate
diagnostic metadata and never contains payload data.

`Isolate.run` forwards computation and result errors through its Future. The
implementation does not catch JSON, UTF-8, transform, isolate-dispatch, or
result-sendability failures and relabel them as transport errors.

References: [Dart `Isolate.run`](https://api.dart.dev/dart-isolate/Isolate/run.html),
[Dart `TransferableTypedData`](https://api.dart.dev/dart-isolate/TransferableTypedData-class.html),
and [Dart isolate sendability](https://api.dart.dev/dart-isolate/SendPort/send.html).

## 4. Transfer representation

The public input remains `Uint8List`. Native code internally creates
`TransferableTypedData` so the API does not expose an isolate-specific type.
This is an implementation detail, not a zero-copy promise:

- constructing the transferable has work proportional to the input size;
- the worker materializes a byte view before UTF-8 decoding;
- UTF-8 decoding creates a worker-side `String`;
- `jsonDecode` creates a JSON object graph;
- the caller transform creates or returns its result graph; and
- the result still has to cross the isolate boundary.

The package does not deliberately create a second `Uint8List` from the public
input. If an AlphaX compatibility response returns `List<int>`, the caller may
need an explicit `Uint8List.fromList` conversion before calling the package;
that is a consequence of the current core response contract and was not
changed here.

The native function does not retain a separate input/transfer/string/decoded
graph by design after the worker is dispatched. The Dart VM may retain objects
until the asynchronous invocation and garbage collection release them; the
package makes no stronger memory-lifetime guarantee.

## 5. Sendability rules

The transform closure and returned `T` must be isolate-sendable. The README
and Dartdoc recommend top-level functions, static functions, or simple
closures with safely sendable captures. They explicitly reject examples that
capture or return `BuildContext`, sockets, files, `AlphaXClient`, plugin or
database handles, platform handles, native resources, or other unsendable
state.

No runtime serializer, model registry, reflection, code generation, or
arbitrary-object conversion was added. If dispatch or result transfer cannot
send the supplied closure/value, the actual isolate failure reaches the caller.

## 6. Cancellation and discard semantics

The implementation uses the existing `AlphaXCancellationToken`:

| Point of cancellation | Behavior |
| --- | --- |
| Before preparation | Cancellation error; no preparation or dispatch. |
| Before dispatch | Second check prevents isolate creation when cancelled. |
| After dispatch | Cancel caller Future; discard the worker result/error. |
| Worker first | Deliver result/error; later cancellation cannot rewrite it. |

The implementation uses a guarded completer and keeps handlers attached to the
worker Future after cancellation. This provides one terminal outcome and
prevents a late worker error from becoming an unhandled asynchronous error.
Post-dispatch cancellation is discard semantics, not hard worker termination:
the one-shot worker may continue consuming CPU until it returns. If the caller
also owns a live AlphaX network operation, it must cancel that operation with
its own token.

Tests cover pre-cancelled calls, post-dispatch cancellation while a transform is
busy, a worker error after cancellation, and a successful result followed by a
late cancellation. A deterministic non-sendable result test also confirms that
the isolate boundary surfaces a failure rather than serializing arbitrary
values.

## 7. Web behavior

The Web conditional implementation checks cancellation and then throws
`AlphaXTransformUnsupportedException`. It does not call `jsonDecode`
synchronously and does not imply browser background execution. This is
fail-closed behavior; callers that need a synchronous Web path must choose and
name that path themselves.

The package therefore does not claim Web background execution, Web worker
support, or Flutter Web frame isolation.

## 8. Error propagation

Invalid UTF-8 and invalid JSON remain their `dart:convert` failures. Exceptions
from the caller transform remain their original type where the isolate runtime
can forward them. Isolate dispatch and result-sendability failures are not
converted to `AlphaXTransportException` or `AlphaXResponseBodyException`.
Only cancellation uses the existing AlphaX normalized cancellation vocabulary;
unsupported Web execution uses a package-specific exception because it is not a
transport failure.

## 9. Memory and copy behavior

The actual native path has these meaningful allocation boundaries:

```text
caller bytes
  → transferable preparation (proportional preparation cost)
  → worker materialized bytes
  → UTF-8 String
  → decoded JSON graph
  → transformed result graph
  → isolate result transfer
```

This is fewer caller-side scheduling steps than repeating the pattern in every
application, but it is not literal zero-copy JSON. The package intentionally
does not use FFI external typed data, shared native buffers, memory mapping,
file descriptors, or a transport-specific file/network path. It also does not
retain a persistent worker that would retain buffers between calls.

## 10. Deterministic parsing benchmark

The package-local benchmark is
[`packages/alphax_transform/tool/benchmark_transform.dart`](../packages/alphax_transform/tool/benchmark_transform.dart).
It uses the same repeated-string JSON shape and target sizes as the Task 37
parsing study: 100 KiB, 1 MiB, 5 MiB, and 10 MiB. It compares synchronous
decode/model summary, direct `Isolate.run` with a captured String, direct
`TransferableTypedData`, and `alphax_transform`. Each arm receives one warm-up
run and three measured runs. The benchmark emits JSON lines but no raw output
was added to the repository.

Environment: Dart 3.13.0 stable, macOS arm64 Dart VM, local host; this is not
an Android device or iPhone measurement. `event_loop_gap_us` is the delay
until a scheduled main-isolate timer runs, not a Flutter frame metric. The RSS
field is a process-RSS observation after a sample, not a controlled peak-memory
measurement. Results therefore guide implementation behavior but are not a
public performance claim.

### Median local observations

| Target / actual payload | Arm | Total median | Event-loop gap median |
| ---: | --- | ---: | ---: |
| 100 KiB / 102,711 B | synchronous | 0.363 ms | 0.363 ms |
| 100 KiB / 102,711 B | direct isolate + String | 0.616 ms | 0.137 ms |
| 100 KiB / 102,711 B | direct isolate + transferable | 0.616 ms | 0.046 ms |
| 100 KiB / 102,711 B | `alphax_transform` | 0.912 ms | 0.101 ms |
| 1 MiB / 1,050,632 B | synchronous | 2.996 ms | 2.996 ms |
| 1 MiB / 1,050,632 B | direct isolate + String | 2.994 ms | 0.804 ms |
| 1 MiB / 1,050,632 B | direct isolate + transferable | 2.788 ms | 0.167 ms |
| 1 MiB / 1,050,632 B | `alphax_transform` | 3.025 ms | 0.228 ms |
| 5 MiB / 5,249,008 B | synchronous | 13.106 ms | 13.106 ms |
| 5 MiB / 5,249,008 B | direct isolate + String | 13.747 ms | 3.886 ms |
| 5 MiB / 5,249,008 B | direct isolate + transferable | 15.254 ms | 0.718 ms |
| 5 MiB / 5,249,008 B | `alphax_transform` | 14.040 ms | 0.403 ms |
| 10 MiB / 10,496,978 B | synchronous | 26.411 ms | 26.411 ms |
| 10 MiB / 10,496,978 B | direct isolate + String | 30.993 ms | 10.318 ms |
| 10 MiB / 10,496,978 B | direct isolate + transferable | 31.657 ms | 1.252 ms |
| 10 MiB / 10,496,978 B | `alphax_transform` | 28.606 ms | 0.536 ms |

The local run shows the intended direction: the helper substantially reduces
the caller event-loop gap for the larger shapes while adding approximately 7%
total latency at 5 MiB and approximately 8% at 10 MiB versus that run's
synchronous arm. The 100 KiB and 1 MiB results do not justify automatic
offloading. The benchmark is too small and host-specific to establish a
universal cutoff.

The process-RSS samples rose from approximately 208 MiB to 297 MiB over the
sequential run. The larger 5–10 MiB transferable/helper samples were observed
around 269–297 MiB, while synchronous samples were around 235–285 MiB. These
are not peak or isolated-arm measurements: allocator reuse, JIT state, garbage
collection, and earlier arms all affect the later samples. They confirm that
large worker paths can have a meaningful memory footprint, but do not justify
an arm ranking or a memory guarantee. A controlled per-process/profile run is
required before making a production memory claim.

Task 37 remains the stronger UI-motivation evidence on the measured Android
device: approximately 69 ms synchronous main-isolate gap at 5 MiB and 122 ms
at 10 MiB, with one-shot worker modes reducing the gap to roughly 20–34 ms at
the cost of higher total latency and memory. The current implementation is
consistent with that evidence; it does not claim to reproduce Android results
on this macOS host.

## 11. Main-isolate responsiveness result

The package meets the intended one-shot responsiveness objective for native
targets in the bounded local experiment: at 5 MiB and 10 MiB, the scheduled
main-isolate timer ran in under 1 ms for the helper while synchronous decoding
occupied the isolate for approximately 13 ms and 26 ms in this host run.

This is not a Flutter frame test and must not be read as a 60/120 Hz guarantee.
The Android Task 37 evidence demonstrates why the explicit seam is useful for
large UI workloads, while the package remains opt-in because the same worker
tradeoff can increase total latency, process memory, and CPU.

## 12. Total-latency tradeoff

`alphax_transform` is not intended to win a raw parsing-throughput ranking. It
adds transferable preparation, isolate scheduling, and result-transfer work.
The helper is valuable when avoiding a caller-isolate stall matters more than
minimum elapsed time. Small payloads should usually remain synchronous; the
caller should profile its payload shape, model mapping, device, and active UI
load before opting in.

No automatic byte threshold was added. The retained Task 37 guidance is:

- around 100 KiB: synchronous work was cheaper in the measured evidence;
- around 1 MiB: measure first;
- around 5 MiB: consider one-shot isolation during active UI work; and
- around 10 MiB: likely frame-risk on the measured Android device class.

These are observations, not package policy.

## 13. Package size and publication readiness

`dart pub publish --dry-run` completed successfully:

| Check | Result |
| --- | --- |
| Archive contents | Docs, assets, code, tests, and benchmark tool |
| Compressed archive | 13 KB |
| Warnings | 0 |
| Benchmark raw data | Not included |
| Local machine paths/secrets | None found |
| Flutter/native/plugin dependencies | None |
| Publication | Not performed |

The package remains independently publishable, but this task does not publish
it or make a public performance claim.

## 14. Public documentation status

Completed documentation includes:

- package README covering motivation, explicit buffering, one-shot behavior,
  sendability, cancellation/discard, Web failure, measured guidance, and when
  not to use the helper;
- Dartdoc for the public typedef, operation, and unsupported exception;
- package changelog and Apache-2.0 license;
- root README package list and post-publication install note;
- architecture overview and package map entries;
- roadmap entry for the optional post-1.0 extension; and
- this implementation report.

No historical 1.0 release-gate claim was rewritten to say that the new package
has been published.

## 15. Limitations

- Input must already be buffered; transport streams and native file paths are
  intentionally outside the package boundary.
- JSON decoding is one-shot and non-streaming.
- Web background execution is unsupported and fails closed.
- A transform and result must be isolate-sendable.
- Post-dispatch cancellation discards the result but cannot immediately kill
  worker CPU work.
- Each call starts a new isolate; no persistent worker/pool is provided.
- No automatic byte threshold, middleware, model mapping registry, serializer,
  FFI/shared buffer, or native engine is included.
- The package does not provide a Flutter frame instrumentation API.
- The current AlphaX response compatibility API returns `List<int>` from
  `readAsBytes`, so callers may make one explicit `Uint8List.fromList` copy.
- Task 37 Android measurements and the local macOS benchmark are not a
  substitute for a future device-specific Flutter UI study.

## 16. Future non-goals

The implementation deliberately does not begin any of the following:

- persistent workers, pools, queues, worker affinity, or scheduling;
- automatic response transformation or hidden payload thresholds;
- streaming JSON parsing or transport-aware backpressure;
- model registries, annotations, code generation, Freezed/json_serializable,
  or protobuf integration;
- Web worker/background execution;
- FFI/shared-memory/zero-copy transport work;
- Android `ByteBuffer` copy reduction or Apple `Data` slicing replacement;
- progress coalescing, credit batching, or chunk/window tuning; or
- changes to AlphaX core or native transport architecture.

## Validation conclusion

The package implementation, focused native tests, deterministic payload tests,
native benchmark, analyzer, formatter, and publication dry-run are green. The
remaining repository-level validation is recorded in Task 41 and must pass
before maintainer approval. No production transport defaults or public core
APIs were changed.

ALPHAX_TRANSFORM READY FOR RC
