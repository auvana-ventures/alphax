# AlphaX Progress-event Suppression and Coalescing

Task 39 is a focused integration-cost optimization. It does not change the
transport architecture, body-stream semantics, cancellation contract, protocol
selection, chunk size, or credit window. Production remains 64 KiB chunks and
four credits.

## 1. Decision

The selected result is `SUPPRESS_ONLY`:

- progress interest is passed per operation;
- native progress events are not constructed or sent when the operation has no
  upload/download observer;
- Dart IO avoids constructing progress values when no callback exists;
- requested progress retains the existing per-provider-read behavior;
- no public cadence option or global mutable switch was added.

The focused measurements prove a large reduction in unused native progress
traffic. Trace replay shows that coalescing could reduce requested progress
traffic on large transfers, but it was not a provider-side coalescer and did
not establish a user-visible frame benefit. Coalescing is left for a separate
measured follow-up rather than adding timer, terminal-flush, and cancellation
state to this path.

## 2. Old and new behavior

Previously, Android and Apple native operations emitted a progress map for each
provider read/delegate callback regardless of whether Dart had registered an
observer. Dart then converted that map to `AlphaXProgress` and used a nullable
callback invocation. The application callback could be absent, but native map
construction, event-channel scheduling, and Dart event handling still occurred.

The new path is:

```text
request observers/body observer
  -> operation-local interest flags
  -> native/provider callback updates authoritative byte counters
  -> interest guard
       false: stop; no AlphaX progress map or channel event
       true:  construct/send progress event -> Dart observer(s)
```

Internal byte counters remain active in every branch. Completion metrics,
native-file accounting, cancellation, and body correctness do not depend on a
progress observer.

## 3. Observer detection and operation isolation

The private Dart helper
[`alpha_x_progress_arguments.dart`](../packages/alphax_native/lib/src/alpha_x_progress_arguments.dart)
adds two request arguments:

- `downloadProgressRequested` when `AlphaXRequest.onDownloadProgress` is set;
- `uploadProgressRequested` when `AlphaXRequest.onUploadProgress` is set or an
  `AlphaXFileBody.onProgress` observer is set.

The flags are created from the immutable request being started and retained by
one native operation. They are not global and are not read from another
request. Concurrent operations can therefore independently represent download,
upload, or no interest.

The Dart handlers retain a defensive observer check after the platform
boundary. It is not the optimization boundary; it prevents an unexpected or
stale native event from constructing a Dart progress value without a matching
observer.

## 4. Exact progress paths

### Android response streaming

```text
Cronet UrlRequest
  -> CronetRequestOperation.onReadCompleted(ByteBuffer)
  -> ByteBuffer -> ByteArray conversion
  -> internal bytesDownloaded accounting
  -> bounded chunk EventChannel event -> Dart _AndroidOperation.bodyStream
  -> AlphaX response stream/middleware/caller

progress side:
  onReadCompleted -> emitProgress("download", ...)
  -> operation-local interest guard
  -> progress map/EventChannel only when requested
  -> Dart AlphaXProgress -> request.onDownloadProgress
```

The response chunk and byte-array conversion are unchanged. Suppression only
prevents progress-map construction and its event-channel delivery.

### Android native download

```text
Cronet onReadCompleted(ByteBuffer)
  -> ByteBuffer -> ByteArray conversion
  -> FileOutputStream.write(ByteArray)
  -> internal bytesDownloaded/native-file accounting
  -> completion metrics -> AlphaXTransferResult -> caller
```

There is no response body chunk event for the payload. A progress event is
created/sent only when `downloadProgressRequested` is true.

### Android upload

```text
local file:
  FileInputStream/FileUploadProvider -> Cronet upload ByteBuffer -> network

Dart-backed body:
  Dart AlphaX body -> uploadDemand MethodChannel -> native ByteBuffer
  -> Cronet upload provider -> network

both:
  provider bytes -> bytesUploaded accounting -> interest guard
              -> optional upload progress EventChannel event
```

Upload-demand messages and byte accounting remain active for Dart-backed
uploads. No upload runtime harness arm was available; the request/body-interest
mapping and Dart IO upload tests cover the observer split.

### Apple response streaming

```text
URLSession data delegate didReceive(Data)
  -> AlphaXURLSessionBackpressure.receive(Data)
  -> bounded 64 KiB pieces / pending window
  -> chunk EventChannel event -> Dart body stream -> caller

progress side:
  didReceive(Data) -> bytesDownloaded accounting -> emitDownloadProgress()
  -> operation-local interest guard
  -> optional progress EventChannel event -> Dart observer
```

The Task 38 backpressure state machine is untouched. Progress suppression does
not modify credits, pending chunks, suspension, resumption, or completion order.

### Apple native download

```text
URLSession download delegate didWriteDownload
  -> native temporary-file write/accounting
  -> optional progress EventChannel event
  -> didFinishDownloading -> existing finalizer -> completion metrics/result
```

The payload remains native. The observer guard is after native byte accounting
and before progress-event construction/delivery.

### Apple upload

```text
URLSession didSendBodyData
  -> bytesUploaded accounting
  -> operation-local interest guard
  -> optional progress EventChannel event -> Dart request/body observer
```

The Dart-backed upload bridge and upload-demand behavior are unchanged.

### Dart IO and Web

Dart IO has no platform event channel. It retains internal upload/download
counters and now explicitly constructs `AlphaXProgress` only inside a non-null
observer branch. Generic base file upload uses a private counting source so an
unknown-length upload still reports transferred bytes without constructing a
progress value when no observer exists.

The current Web Fetch boundary does not provide reliable upload progress and
marks upload progress unsupported. Download progress is unknown because the
browser adapter has no progress observation stream. No synthetic browser
progress events were added.

## 5. Instrumentation discipline

Native counters are private, disabled by default, and enabled only through the
existing debug/test harness seam. They are not public AlphaX API. The counters
distinguish provider reads, AlphaX chunks, emitted native progress events,
credit messages, upload-demand messages, native-file writes, and platform-copy
observations. They do not replace authoritative completion metrics.

## 6. Before/after focused results

Raw results are retained in
[`benchmarks/results/raw/integration-cost`](../benchmarks/results/raw/integration-cost/).
Task 37 files are the before baseline. Task 39 files use the `task39-after-`
prefix. Runs used one long-lived AlphaX client, profile builds, the fixed LAN
fixture, and 64 KiB/four-credit settings. Measured sample counts were seven for
repeated/concurrent requests, one for the 2 MiB stream, and two for the 32 MiB
file trace. These are diagnostic runs, not publication-quality benchmark
samples.

Totals below are across the measured samples in each raw file. Native/Dart
counts are `native_progress_event_count` / `progress_callback_count`.

| Platform/scenario | Progress | Bytes | Native/Dart progress | Events/MiB |
| --- | ---: | ---: | ---: | ---: |
| Android repeated small | off, Task 37 | 224 KiB | 224 / 0 | 1024 |
| Android repeated small | off, Task 39 | 224 KiB | 0 / 0 | 0 |
| Android repeated small | on, Task 39 | 224 KiB | 224 / 224 | 1024 |
| Android 64 concurrent | off, Task 37 | 448 KiB | 448 / 0 | 1024 |
| Android 64 concurrent | off, Task 39 | 448 KiB | 0 / 0 | 0 |
| Android 64 concurrent | on, Task 39 | 448 KiB | 448 / 448 | 1024 |
| Android 2 MiB stream | off, Task 37 | 14 MiB | 232 / 0 | 16.6 |
| Android 2 MiB stream | off, Task 39 | 2 MiB | 0 / 0 | 0 |
| Android 2 MiB stream | on, Task 39 | 2 MiB | 33 / 33 | 16.5 |
| Android 32 MiB native file | off, Task 37 | 96 MiB | 1539 / 0 | 16.0 |
| Android 32 MiB native file | off, Task 39 | 64 MiB | 0 / 0 | 0 |
| Android 32 MiB native file | on, Task 39 | 64 MiB | 1026 / 1026 | 16.0 |
| macOS repeated small | off, Task 37 | 224 KiB | 224 / 0 | 1024 |
| macOS repeated small | off, Task 39 | 224 KiB | 0 / 0 | 0 |
| macOS repeated small | on, Task 39 | 224 KiB | 224 / 222 | 1024 |
| macOS 64 concurrent | off, Task 37 | 448 KiB | 448 / 0 | 1024 |
| macOS 64 concurrent | off, Task 39 | 448 KiB | 0 / 0 | 0 |
| macOS 64 concurrent | on, Task 39 | 448 KiB | 448 / 446 | 1024 |
| macOS 2 MiB stream | off, Task 37 | 14 MiB | 224 / 0 | 16.0 |
| macOS 2 MiB stream | off, Task 39 | 2 MiB | 0 / 0 | 0 |
| macOS 2 MiB stream | on, Task 39 | 2 MiB | 33 / 33 | 16.5 |
| macOS 32 MiB native file | off, Task 37 | 96 MiB | baseline counter unavailable | n/a |
| macOS 32 MiB native file | off, Task 39 | 64 MiB | 0 / 0 | 0 |
| macOS 32 MiB native file | on, Task 39 | 64 MiB | 993 / 993 | 15.5 |

The macOS concurrent/small on-arm Dart totals are two below native totals in
the raw harness summary. The native counter is incremented before EventChannel
delivery, while the harness snapshots its Dart observer after the operation
window. This is a measurement-order limitation, not evidence that suppression
dropped a requested event; the single-stream and file runs matched. The source
still emits progress before its native completion path.

The unambiguous result is that every Task 39 progress-off run had zero native
progress events while byte, chunk, credit, and file accounting continued.

## 7. Frame, wall-time, and RSS observations

The harness used a 60 Hz frame budget of 16,667 microseconds. Values are
progress-off / progress-on p95 frame total, with wall-time p50 in parentheses.

| Platform/scenario | Frame p95 (us) off / on | Wall p50 (us) off / on | Janky frames off / on |
| --- | ---: | ---: | ---: |
| Android repeated small | 15,128 / 16,050 | 553,654 / 537,993 | 6 / 8 |
| Android 64 concurrent | 13,708 / 14,321 | 248,820 / 265,648 | 4 / 3 |
| Android 2 MiB stream | 9,910 / 11,716 | 88,711 / 136,190 | 0 / 0 |
| Android 32 MiB native file | 19,571 / 15,288 | 877,641 / 1,105,334 | 11 / 2 |
| macOS repeated small | 2,321 / 2,383 | 53,890 / 50,977 | 0 / 0 |
| macOS 64 concurrent | 5,838 / 5,638 | 35,346 / 33,328 | 0 / 0 |
| macOS 2 MiB stream | 2,190 / 2,024 | 35,827 / 28,101 | 0 / 0 |
| macOS 32 MiB native file | 2,306 / 2,235 | 432,494 / 429,884 | 0 / 0 |

The samples do not show a repeatable frame-tail regression from requested
progress. Android stream progress-on had a higher p95 in this run, but no
missed frames and one sample cannot establish causality. The Android file p95
was lower with progress enabled, illustrating run variance. No wall-time
improvement is expected from suppression and none is claimed.

Peak process RSS was also not directionally stable: Android off/on maxima were
approximately 221/223 MiB (small), 226/227 MiB (concurrent), 237/232 MiB
(stream), and 274/265 MiB (file); macOS maxima were approximately 156/162,
170/170, 159/159, and 171/163 MiB respectively. RSS includes native/shared
pages and is not Dart heap. In-app Dart CPU, Dart heap, GC, and process CPU
attribution were unavailable through trustworthy public APIs.

## 8. Coalescing experiment

Requested progress remained provider-read based. The harness replayed the
observed progress trace against two diagnostic candidate policies; it did not
change native delivery:

- `time_16ms`: emit at most once per 16 ms, with the first/final observation;
- `byte_256k_or_16ms`: emit on 256 KiB delta or 16 ms, with the first/final
  observation.

| Platform/scenario | Per-read trace | Time-only replay | Byte/time replay |
| --- | ---: | ---: | ---: |
| Android 2 MiB stream | 33 | 7 (-78.8%) | 8 (-75.8%) |
| macOS 2 MiB stream | 33 | 2 (-93.9%) | 8 (-75.8%) |
| Android 32 MiB native file | 1026 | 118 (-88.5%) | 262 (-74.5%) |
| macOS 32 MiB native file | 993 | 51 (-94.9%) | 254 (-74.4%) |

Small and concurrent requests showed little or no reduction because each
operation had a short, independent trace. The replay has no provider-clock
guarantee, does not measure callback smoothness, and does not test final-event
ordering, cancellation, or backpressure under a real coalescer. It establishes
headroom, not a cadence to hard-code.

## 9. Correctness and cancellation

The interest guard does not alter byte counters or body state machines. Existing
and focused tests cover no-observer suppression, direction-specific delivery,
concurrent interest isolation, exact Dart IO byte counts, unknown totals,
terminal native suppression, and unchanged streamed/native-file cancellation
and backpressure behavior.

The automatic harness cancellation probe used an operation without a progress
observer. It validates that suppression does not affect cancellation, but is not
a requested-progress cancellation trace. Upload cancellation was not run on
device because the focused harness has no reliable upload scenario. A future
coalescing task must test cancellation during a pending cadence timer and final
successful observation explicitly.

## 10. Ordering and redirect/retry semantics

No redirect/retry semantics were changed. Progress remains the existing
provider/attempt observation stream; authoritative completion byte metrics are
separate. Native progress is emitted from the same provider callbacks as before
when enabled, and no synthetic 100% progress is created on cancellation.

For successful operations, a provider's final callback supplies the final known
byte observation where that provider reports one. Completion metrics remain the
authoritative final byte count. Any future coalescer must flush a final progress
observation before successful completion and never flush one after cancellation.

## 11. Public API impact

No public AlphaX type, constructor, field, cadence setting, or global switch was
added. Existing callbacks and `AlphaXFileBody.onProgress` behavior are
preserved when requested. The only transport-neutral source addition is a
private generic upload counting wrapper, required to preserve unknown-length
transfer accounting while unused progress construction is suppressed.

## 12. Implementation classification

| Candidate | Decision | Rationale |
| --- | --- | --- |
| Suppress native progress when unused | `IMPLEMENT_NOW` | Zero native progress events in all focused off arms; counters/contracts remain intact. |
| Suppress Dart IO progress construction when unused | `IMPLEMENT_NOW` | Equivalent semantics with no channel; direct and testable. |
| Requested progress coalescing | `MEASURE_MORE` | Replay shows 74–95% possible reduction on large traces, but no real cadence/frame/cancellation evidence. |
| Public progress cadence API | `DO_NOT_IMPLEMENT` | Not necessary for normal use; exposes provider policy prematurely. |
| Credit batching | `DO_NOT_IMPLEMENT` | Outside this task; no measurement here isolates its cost. |
| Chunk/window tuning | `DO_NOT_IMPLEMENT` | 64 KiB × 4 remains unchanged. |
| Android ByteBuffer copy rewrite | `DO_NOT_IMPLEMENT` | No user-visible benefit was established by the prior spike. |
| Apple Data.subdata rewrite | `DO_NOT_IMPLEMENT` | No user-visible benefit was established and it is not needed for correctness. |
| FFI/shared buffers | `DO_NOT_IMPLEMENT` | No user-visible cost is attributed specifically to the channel byte boundary. |
| Isolate transform package | `DO_NOT_IMPLEMENT` | Separate parsing decision; unrelated to progress traffic. |

## 13. Remaining limitations

- The device sample is small and diagnostic, not a public performance claim.
- Dart CPU, heap, and GC attribution were unavailable in-app.
- No reliable upload runtime arm exists in the current harness.
- The iPhone is visible to Flutter, but physical execution remains unavailable
  because Runner lacks provisioning; macOS evidence is not iPhone evidence.
- macOS concurrent/small observer totals can lag native totals by a small amount
  during the harness snapshot window.
- Browser Fetch progress remains capability-limited and unchanged.

## 14. Focused validation

Passed:

- Dart formatting, `dart analyze`, and `dart test` for `packages/alphax`;
- Flutter analysis and tests for `packages/alphax_native`;
- Flutter analysis for `benchmarks/mobile_gate`;
- private Apple URLSession correctness suite;
- macOS profile build, iOS profile no-code-sign build, and Android profile APK
  build;
- focused Android/macOS AlphaX progress-off/on scenarios;
- `git diff --check`.

The package dry-runs completed with the expected dirty-worktree warning. The
Android plugin's standalone Gradle test could not resolve `com.android.library`
from its existing plugin configuration; Flutter's Android profile build and
physical Android runs compiled the changed source. No build configuration was
changed to work around that pre-existing limitation.

## 15. Maintainer follow-up

A separate performance task may implement a conservative requested-progress
coalescer only after a real provider-side experiment measures callback
smoothness, final ordering, cancellation, backpressure, and frame-tail
behavior. It should remain automatic/internal unless a public configuration need
is shown.

**PROGRESS SUPPRESSION HARDENED**
