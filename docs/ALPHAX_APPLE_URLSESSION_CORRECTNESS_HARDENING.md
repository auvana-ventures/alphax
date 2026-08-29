# AlphaX Apple URLSession Correctness Hardening

Status: maintainer review required. This was a correctness spike and focused
rerun, not a new benchmark phase.

## 1. Executive summary

The Apple adapter had two correctness defects:

1. `TimeInterval` values in seconds were multiplied by `1000` in the caller and
   then multiplied by `1000` again in the millisecond helper. Apple phase and
   total metrics were therefore inflated by approximately `1000`.
2. The data delegate split an entire `Data` callback into an array before
   applying the 64 KiB/four-credit/256 KiB bounded window. When a callback was
   larger than the window, the callback remainder continued to be appended to
   the pending queue after the task had been suspended. A deterministic 5 MiB
   response consequently timed out with the production settings.

The timing conversion is now centralized and converts seconds to milliseconds
once. The response state machine now incrementally splits callbacks, bounds the
AlphaX pending queue, commits one logical suspend transition, and resumes only
after pending and deferred data are drained. Completion waits for accepted body
data and the final completion metrics path.

Evidence:

- The pre-fix 5 MiB macOS run failed with
  `AlphaXTimeoutException: ... NSURLErrorDomain:-1001` using 64 KiB × 4.
- The deterministic native suite is green, including timing, invalid dates,
  callback sizes through 1 MiB, a 5 MiB-equivalent callback, slow consumers,
  cancellation cleanup, completion ordering, and file finalization.
- The focused macOS 5 MiB discard/decode, 2 MiB stream, slow-consumer,
  backpressured-cancellation, 32 MiB native download, and replacement runs all
  completed with 64 KiB × 4.
- A physical iPhone was visible to Flutter, but execution was blocked because
  `Runner` has no provisioning profile. The macOS result is not iPhone proof.

No production transport architecture, public AlphaX API, global chunk/window
default, progress behavior, native-copy path, FFI boundary, or advanced H3
control was changed.

## 2. Environment and raw-result locations

| Item | Value |
| --- | --- |
| macOS test host | MacBookPro-class physical Mac, arm64 |
| macOS | 26.6.2, build 25G83 |
| Flutter/Dart | Flutter 3.47.0 / Dart 3.13.0 |
| Build | Flutter profile build; standalone native test compiled with Xcode Swift toolchain |
| Display | 240 Hz reported; harness requested 60 Hz |
| Fixture | `benchmarks/server`, plain HTTP LAN fixture at `192.168.50.204:18080` |
| AlphaX window | 64 KiB chunks, 4 credits, 256 KiB pending-byte bound |
| Apple provider | URLSession; observed protocol was `http11` for the plain HTTP fixture |
| Official reference | `package:http` 1.6.0 + `cupertino_http` 3.0.2 |
| Other harness packages | Dio 5.11.0, `native_dio_adapter` 1.7.0 |
| iPhone discovered | iOS 18.7.10, device `00008020-001528860E03002E` |
| iPhone execution | Not available: Xcode reported no provisioning profile for `Runner` |

Raw machine-readable results and logs are retained under
[`benchmarks/results/raw/integration-cost`](../benchmarks/results/raw/integration-cost/).
The most relevant files are:

- [pre-fix 5 MiB timeout](../benchmarks/results/raw/integration-cost/task38-before-fix-macos-alphax-json_discard-progress-off-file-default-chunk-65536-credits-4.json)
- [5 MiB discard after fix](../benchmarks/results/raw/integration-cost/task38-macos-json-discard-v2-macos-alphax-json_discard-progress-off-file-default-chunk-65536-credits-4.json)
- [5 MiB decode after fix](../benchmarks/results/raw/integration-cost/task38-macos-json-decode-v2-macos-alphax-json_decode-progress-off-file-default-chunk-65536-credits-4.json)
- [2 MiB stream](../benchmarks/results/raw/integration-cost/task38-macos-stream-macos-alphax-stream_binary-progress-off-file-default-chunk-65536-credits-4.json)
- [slow consumer](../benchmarks/results/raw/integration-cost/task38-macos-stream-slow-v2-macos-alphax-stream_slow-progress-off-file-default-chunk-65536-credits-4.json)
- [backpressured cancellation](../benchmarks/results/raw/integration-cost/task38-macos-cancel-backpressured-v2-macos-alphax-cancel_backpressured-progress-off-file-default-chunk-65536-credits-4.json)
- [32 MiB native file](../benchmarks/results/raw/integration-cost/task38-macos-file-download-macos-alphax-file_download-progress-off-file-default-chunk-65536-credits-4.json)
- [32 MiB replacement](../benchmarks/results/raw/integration-cost/task38-macos-file-replace-macos-alphax-file_download_replace-progress-off-file-default-chunk-65536-credits-4.json)
- [Cupertino correctness reference](../benchmarks/results/raw/integration-cost/task38-macos-cupertino-reference-macos-package_http_cupertino-json_discard-progress-off-file-default-chunk-65536-credits-4.json)
- [iPhone provisioning limitation](../benchmarks/results/raw/integration-cost/task38-iphone-json-discard-ios-alphax-json_discard-progress-off-file-default-chunk-65536-credits-4.run.log)

Early task-38 raw files contain an operator-supplied stale Flutter label in
their metadata. The actual toolchain was Flutter 3.47.0 / Dart 3.13.0; the
later `v2` stream result has the corrected label. This metadata issue does not
alter the native result values, but it is noted so the raw data is not
misrepresented.

## 3. Timing bug root cause

The old Apple helper was effectively:

```text
interval = start.distance(to: end) * 1000
milliseconds(interval) = interval * 1000
```

`Date.distance`/`TimeInterval` is seconds. The first multiplication was an
incorrect pre-conversion and the helper performed the required conversion a
second time. A 1 ms interval could therefore be reported as 1000 ms; a 1 s
interval could be reported as 1,000,000 ms.

The bug affected the URLSession metrics fields populated from that helper:

- `dnsDurationMs`
- `connectDurationMs`
- `tlsDurationMs`
- `timeToFirstByteMs`
- `transferDurationMs`
- `totalDurationMs`
- fallback total duration using the same elapsed-time source

The timeout parser is a separate helper that accepts Dart integer milliseconds
and converts request timeout values to `TimeInterval` seconds. It was not
changed by the timing fix.

## 4. Timing fix and field map

[`AlphaXURLSessionTiming.swift`](../packages/alphax_native/ios/Classes/AlphaXURLSessionTiming.swift)
now has one conversion boundary:

```swift
guard interval.isFinite, interval >= 0 else { return nil }
return Int((interval * 1000).rounded())
```

The operation passes native seconds directly to this helper. Negative,
non-finite, overflowed, or unavailable values return `nil`, which the existing
`optionalInt` mapping emits as `NSNull` for the Dart side.

| AlphaX field | URLSession source | Unit conversion |
| --- | --- | --- |
| `dnsDurationMs` | `domainLookupStartDate` → `domainLookupEndDate` | Date interval seconds → ms once |
| `connectDurationMs` | `connectStartDate` → `connectEndDate` | Date interval seconds → ms once |
| `tlsDurationMs` | `secureConnectionStartDate` → `secureConnectionEndDate` | Date interval seconds → ms once |
| `timeToFirstByteMs` | `requestStartDate` → `responseStartDate` | Date interval seconds → ms once |
| `transferDurationMs` | `responseStartDate` → `responseEndDate` | Date interval seconds → ms once |
| `totalDurationMs` | `URLSessionTaskMetrics.taskInterval.duration` | seconds → ms once |
| fallback `totalDurationMs` | `Date().timeIntervalSince(responseDate)` | seconds → ms once |
| request timeout values | Dart `Duration.inMilliseconds` | integer ms → `TimeInterval` seconds for URLSession |
| expiry timestamp | `Date().timeIntervalSince1970 * 1000` | absolute epoch ms, not a phase duration |

The full Apple adapter search found no other phase conversion involving
`TimeInterval`, `Date.distance`, microseconds, nanoseconds, or `Duration` that
duplicates the conversion. Dart-side `Duration(milliseconds: value)` mapping
remains one integer-ms boundary.

The implementation continues to use completion-time URLSession metrics as the
authoritative final metadata path required by
[ADR 0005](decisions/0005-completion-time-protocol-metadata.md). Response-start
protocol values remain best-effort/unknown when Apple cannot prove them at that
point.

## 5. Timing regression tests

The standalone native test runner is
[`AlphaXURLSessionCorrectnessTests.swift`](../packages/alphax_native/ios/Tests/AlphaXURLSessionCorrectnessTests.swift),
invoked by
[`run_apple_urlsession_correctness_tests.sh`](../packages/alphax_native/tool/run_apple_urlsession_correctness_tests.sh).

It passes deterministic checks for:

- 1 ms → 1 ms;
- 10 ms → 10 ms;
- 100 ms → 100 ms;
- 1 second → 1000 ms;
- a 1.234 second total → 1234 ms;
- a coherent timeline where phase values remain within the 250 ms total;
- missing start/end timestamps → unavailable;
- negative, infinity, and NaN intervals → unavailable;
- completion only after body state is drained, preserving ADR 0005’s
  completion-time authority.

The suite was intentionally run while the helper still contained the old
double-scaling expression. That red run failed at the 1 ms assertion with an
actual value of 1000. After the correction, the full suite passed.

## 6. Backpressure root cause

### Old state machine

The old operation performed this sequence:

```text
URLSession didReceive(Data)
  → split the entire Data into [Data] pieces
  → emit pieces while credits > 0
  → append every remaining piece to pendingChunks
  → suspend once pendingBytes reached 256 KiB
  → flush the already-expanded queue later
```

The `suspended` flag prevented repeated calls in the ordinary path, but it did
not stop the current callback from appending all remaining pieces. A large
callback could therefore turn the bounded pending window into a multi-megabyte
queue. Completion only checked the old pending array and did not represent the
separate “callback remainder is still being drained” state.

The required deterministic reproduction was:

```text
64 KiB chunk size × 4 credits × 256 KiB pending window
5 MiB nominal JSON response
```

The pre-fix macOS AlphaX run timed out with `NSURLErrorDomain:-1001`.

### Corrected state machine

[`AlphaXURLSessionBackpressure.swift`](../packages/alphax_native/ios/Classes/AlphaXURLSessionBackpressure.swift)
now owns the response-delivery state:

```text
receive(Data)
  → emit at most the available credited chunks
  → queue at most four 64 KiB chunks (256 KiB)
  → retain the current callback remainder as an offset source
  → commit suspended = true once, before dispatching those chunks

grant(N)
  → drain pending chunks first
  → drain the callback remainder in order
  → resume only when no pending/deferred bytes remain and credits > 0

markInputCompleted()
  → record completion requested
  → drain accepted body data
  → allow completion only after the state is drained and not suspended
```

This avoids eagerly materializing every piece of a large callback. It does not
claim a universal process-memory bound: URLSession controls the size of the
incoming `Data` callback. The private counters distinguish the bounded AlphaX
pending queue from the callback/provider retention. If a provider violates the
normal suspend contract and delivers additional callbacks while one is
deferred, the helper retains them to preserve byte order rather than dropping
data; the URLSession delegate queue is serial and the task is suspended before
the current callback’s chunks are dispatched.

## 7. Suspend/resume invariants

The corrected implementation and tests use these invariants:

1. The AlphaX operation has one logical upstream state: running or suspended
   for AlphaX backpressure. The state controller, not each split piece, decides
   transitions.
2. A state already marked suspended never emits another `suspendTask` action.
   `redundantSuspendChecks` is diagnostic evidence of repeated checks; it is
   not a count of native `URLSessionTask.suspend()` calls.
3. A resume is emitted only when credits are positive, pending chunks are empty,
   and deferred callback bytes are empty.
4. A normal logical pause has one suspend transition and one resume transition.
   Cancellation is the explicit exception: it marks the state terminal and
   invalidates future resume work because the URLSession task is canceled.
5. Cancellation clears pending chunks, deferred sources, and credits before the
   native task is canceled. No post-cancellation resume action is emitted.
6. Completion cannot be emitted while pending chunks, deferred bytes, or a
   suspended state remain.
7. A native callback is split in input order; each accepted byte is emitted at
   most once, and tests verify total length and checksum.

The operation applies a suspend action before emitting the callback’s chunks.
Every chunk checks the terminal flag before dispatch, so cancellation during a
split stops further native-to-Dart event emission.

## 8. Deterministic oversized-callback coverage

The native state tests cover callback-equivalent inputs of:

- 64 KiB;
- 128 KiB;
- 256 KiB;
- 257 KiB;
- 1 MiB;
- 5 MiB.

For each input the tests verify ordered byte conservation, no duplicate/lost
bytes, pending bytes never exceeding 256 KiB, one suspend/resume pair when
credits are exhausted, and zero retained logical bytes after draining. The
5 MiB test also verifies that the bounded queue and current callback remainder
are represented separately and that no second suspend action is emitted while
the original pause is active.

## 9. Focused 5 MiB default-window result

The post-fix macOS discard run used the production settings and four measured
runs. All four completed:

| Observation | Result |
| --- | --- |
| Actual body | 5,242,878 bytes |
| Body chunks | 82–83 |
| Credit messages | 80–81; credit units 83–84 |
| Native progress events with progress observer off | 4–6 |
| Dart progress callbacks | 0 |
| Peak bounded pending queue | exactly 262,144 bytes |
| Peak logically retained AlphaX data | 2,063,700–3,981,770 bytes, driven by provider callback size plus the bounded queue |
| Final pending/deferred/logical bytes | 0 |
| Native suspend/resume calls | 2–4 / 2–4, balanced per run |
| Diagnostic redundant suspend checks | 19–68; no corresponding repeated native suspend calls |
| Explicit `Data.subdata` split count | 3–6 |
| Corrected TTFB metric | 148–150 ms |
| Corrected total metric | 152–164 ms |
| Negotiated protocol | `http11` on the plain HTTP fixture |

These are correctness observations from four macOS runs, not a performance
claim. The corrected metrics are now in the same unit scale as the wall-clock
operation and are suitable for future measurement.

## 10. Slow-consumer result

The focused 2 MiB stream deliberately delayed each Dart chunk by 8 ms. It
completed with:

- 2,097,152 bytes and 33 AlphaX chunks;
- 256 KiB peak pending bytes;
- 393,216 bytes peak logical retained data because one 64 KiB callback/source
  can coexist with the four-chunk pending window;
- six suspend and six resume calls;
- 11 credit messages / 44 credit units;
- zero final pending/deferred/logical bytes;
- no timeout and no data-integrity failure.

The macOS UI harness recorded no missed frame at its 16.667 ms / 60 Hz budget
in this run. The timer-gap proxy reached 37 ms, so this is not evidence that a
heavier Flutter UI or iPhone would be unaffected; it is evidence that the
backpressure path drained correctly under a deliberately slow consumer.

## 11. Pause/resume coverage

The native state tests cover:

- initial credit exhaustion before the queue is drained;
- partial drain that remains suspended;
- a final grant that drains the remainder and resumes once;
- repeated state checks while suspended without repeated suspend actions;
- cancellation while pending data exists, which clears data and suppresses
  resume;
- operation-close behavior through the same terminal/cancel state path.

The focused slow-consumer run adds a real Dart stream pause/resume path. Its
six suspend/six resume calls remained balanced and its final state was clear.
The cancellation run intentionally cancels while the URLSession task is
suspended; cancellation completes as an AlphaX cancellation rather than a
timeout.

## 12. Cancellation result and ordering nuance

The backpressured cancellation probe pauses the Dart subscription after the
first 64 KiB chunk, allows the native window to suspend, waits 100 ms to make
the suspended state observable, cancels the token, then resumes the Dart
subscription only to observe its terminal signal.

The result was:

- cancellation-to-terminal signal: 234 microseconds in the focused sample;
- terminal error: `AlphaXCancellationException`;
- native reads/chunks: 262,144 bytes / 4 chunks; no additional native callback
  was observed, and the terminal guard prevents later chunk emission;
- logical pending/deferred bytes after cancellation: 0;
- native task state in the final counter snapshot: not suspended;
- three 64 KiB chunks were delivered by Dart after the cancellation request.

The last item is not a new native delivery: those chunks had already been
accepted into the paused Dart `StreamController` before cancellation and were
released when the probe resumed the subscription. The native bridge itself
does not emit a chunk after its terminal flag is set. This distinction is
important: the transport cancellation boundary is correct and prompt, while a
strict “discard all already-queued Dart stream events” guarantee is not added
to the public stream contract in this task.

The state-machine cancellation test separately verifies that canceling the
native controller produces no future chunks, no future resume, and no future
completion. No timeout was substituted for cancellation.

## 13. Completion ordering and ADR 0005

The intended ordering remains:

```text
started
  → accepted body chunks and progress events
  → URLSession task metrics collected
  → completion requested
  → all pending/deferred body bytes drained
  → final completion metrics/protocol event
  → Dart response stream closes
```

`didFinishCollecting(metrics:)` stores corrected metrics, while
`didComplete(error:nil)` requests body completion. The operation does not emit
the final `completed` event until the backpressure controller reports no
pending chunks, no deferred bytes, and no suspended state. Dart continues to
resolve `completionMetrics` from that final event, so completion-time protocol
and timing metadata remain authoritative under ADR 0005.

The deterministic completion test calls input completion while data is still
pending, confirms no completion is emitted, drains the data, grants the final
credit needed to resume, and then confirms completion is emitted last.

## 14. File finalization contract

The Apple native download path remains:

```text
URLSession download task
  → Foundation temporary file
  → FileManager finalization
  → requested destination
```

[`AlphaXURLSessionFileFinalizer.swift`](../packages/alphax_native/ios/Classes/AlphaXURLSessionFileFinalizer.swift)
now uses `FileManager.replaceItemAt` when the destination already exists and a
move when it does not. Apple’s
[FileManager replacement documentation](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat%28_%3Awithitemat%3Abackupitemname%3Aoptions%3A%29)
describes replacement/no-data-loss behavior but does not establish a universal
atomicity guarantee for every filesystem and deployment target. AlphaX makes no
atomic-replacement claim.

The 1.x contract is:

- successful native download produces the requested final file;
- destination directories are created as needed;
- an error or cancellation does not report a completed destination;
- a failed replacement preserves the old destination when Foundation leaves it
  in place;
- finalization failure is reported as a response-body error and the temporary
  provider file is cleaned up on a best-effort basis;
- replacement is best-effort/platform-safe, not promised atomic;
- no generic transactional filesystem API is introduced.

Deterministic native tests cover destination absent, existing destination,
successful replacement, missing temporary source/finalization failure, and
preservation of the old destination on that failure. The focused macOS runtime
replacement run confirmed that a pre-existing destination was replaced by a
32 MiB final file and that its on-disk length matched the reported bytes.

For a transport failure or cancellation before `didFinishDownloading`, the
temporary URL is never adopted as the requested destination. Foundation owns
the provider temporary-file lifecycle; AlphaX does not claim a persistent
partial destination. A future platform-specific test can add a stronger
failure-injection seam if maintainers need to distinguish every FileManager
failure mode.

## 15. Native-file result

The focused 32 MiB native download ran twice. Each run recorded:

- 33,554,432 response bytes;
- zero AlphaX response chunks and zero response reads through the Dart body;
- 494 native file-write observations totaling the full 33,554,432 bytes;
- zero pending/logical response-buffer bytes;
- 482–494 native progress events despite progress being off;
- successful finalization and no frame misses in the macOS harness.

This confirms the existing Apple native-file path keeps payload bytes out of
Dart. It does not prove that Foundation’s internal buffering or the provider’s
write path is zero-copy. No Data-slicing or native-copy rewrite was attempted.

## 16. Apple `Data` splitting observation

The 5 MiB body runs observed provider callbacks as large as approximately
2.3–3.1 MiB and peak logical retention of approximately 2.1–4.0 MiB. The
corrected helper uses `Data.subdata` only to materialize the individual
64 KiB-equivalent chunks needed for the Dart boundary. The explicit split
counter was 3–6 per 5 MiB run, with approximately 5.23–5.24 MiB of copied
split data across those runs.

This establishes that `Data.subdata` copies exist, but this task did not
establish a user-visible CPU, RSS, or frame benefit from replacing them. The
correctness fix removes the larger problem—eagerly retaining every split piece
in the pending queue—without changing the underlying copy strategy.

## 17. Progress and credit observations

Progress optimization was explicitly out of scope. The required off-observer
baseline remains visible:

- 5 MiB discard: 4–6 native progress events, 0 Dart progress callbacks;
- 2 MiB stream: 32 native progress events, 0 Dart callbacks;
- 32 MiB native file: 482–494 native progress events, 0 Dart callbacks.

This confirms that progress events are still constructed/emitted natively when
no observer is installed. The run did not claim that this overhead is
user-visible; no matched progress-on/off CPU or frame experiment was added to
this correctness task. Progress suppression/coalescing remains a separate P1
candidate.

The 5 MiB run used approximately one credit message per delivered body chunk
after initial credits. The state machine stayed bounded and correct, but this
task did not test `credit(N)` batching. There is no evidence here that one
credit per chunk is materially harmful, and no batching change is justified
without a separate UI/backpressure experiment.

## 18. Flutter, CPU, memory, and performance interpretation

The in-app harness can report frame timings, a timer-gap proxy, and coarse
process RSS. It cannot isolate Dart heap, VM GC, native allocator usage, or
per-client CPU without an external profiler. Therefore:

- 5 MiB discard: 300 raw frame samples across four runs, zero missed frames,
  per-run frame p95 approximately 2.1–2.3 ms at a 16.667 ms budget;
- 2 MiB stream: 50 raw frame samples, zero missed frames, frame p95 2.45 ms;
- slow stream: 167 raw frame samples, zero missed frames, frame p95 4.50 ms;
- 32 MiB native file: 249 raw frame samples across two runs, zero missed
  frames, frame p95 approximately 2.2–2.4 ms;
- 5 MiB decode: the synchronous decode path recorded no FrameTiming samples in
  these macOS runs, so it must not be described as zero-jank. Its JSON
  preparation was 3.96–4.71 ms and parse was 7.39–8.69 ms; the timer-gap proxy
  reached 21.97 ms in one run;
- process RSS included shared/native pages and varied by run. The raw files
  retain the start/peak/end samples; they are not a Dart-heap measurement.

The macOS host is useful for state-machine correctness and unit validation, not
for a cross-client mobile performance conclusion. No Apple CPU profiler was
run, and no iPhone runtime result was available.

## 19. Official Cupertino reference

The fixed 5 MiB discard scenario was also run four times with one long-lived
`package:http` `CupertinoClient` using the same URLSession-backed provider
family. All four completed and consumed the full 5,242,878 bytes. Its body
chunk count varied from 3–6, and it has no AlphaX private counter seam.

This is a correctness/reference baseline only. The harness’s package:http body
clock starts after the response is opened, while AlphaX’s corrected completion
metric is provider task time; these values are not a fair ranking. The result
shows that the fixture itself was healthy and that the fixed AlphaX path now
completes under the same nominal payload/window scenario.

## 20. Conformance and validation status

Passed:

- `bash packages/alphax_native/tool/run_apple_urlsession_correctness_tests.sh`
- `dart test` in `packages/alphax`
- `flutter test` in `packages/alphax_native`
- `flutter analyze` in `packages/alphax_native`
- `flutter analyze` in `benchmarks/mobile_gate`
- Dart formatting check for the modified harness
- `flutter build macos --profile --no-pub -t lib/integration_cost_apple.dart`
- `flutter build ios --profile --no-codesign --no-pub -t lib/integration_cost_apple.dart`
- focused macOS runtime scenarios listed above
- `git diff --check`

The native package dry-run completed package validation with one existing dirty
worktree warning because other task-37 Android files and the Apple plugin are
modified. It did not indicate a package-content or API validation error.

The iPhone runtime subset was attempted and blocked before deployment by the
missing provisioning profile. No iPhone result is inferred from macOS.

No public API, public metric name, transport architecture, global default, or
production progress behavior was changed.

## 21. Required answers

### 1. Is the Apple bridge overhead materially worse than package:http native clients?

Not established. AlphaX now completes the fixed 5 MiB case with bounded pending
state, and the Cupertino reference completes as well, but this task did not
run a matched CPU/RSS/client-overhead comparison. No performance ranking should
be published.

### 2. Does AlphaX cause more Flutter frame pressure?

No material excess was demonstrated on the tested macOS host. That is not proof
of parity on iPhone: the decode path lacked FrameTiming samples, and no
physical-device run was possible.

### 3. Under which workloads?

The only direct pressure signals were the synchronous 5 MiB decode timer-gap
observation and the intentionally slow stream’s 37 ms event-loop-gap proxy.
Neither was compared against an equivalent Apple client in this task. Native
file transfer showed no Dart body participation and no observed macOS frame
misses.

### 4. Does progress reporting materially contribute?

It definitely contributes native event traffic when unused, as shown by the
off-observer counts. A user-visible CPU/frame effect was not established here.
Measure and then consider suppression/coalescing separately.

### 5. Does one-credit-per-chunk materially contribute?

No causal effect was established. It creates roughly one credit message per
body chunk in the normal path, but the corrected state machine remains bounded
and completes. Credit batching requires a separate controlled run.

### 6. Should the 64 KiB/four-credit default change?

No. It now completes the deterministic 5 MiB case and slow-consumer case with
bounded pending bytes. Keep 64 KiB × 4.

### 7. Do native file paths produce meaningful heap/RSS benefits?

They produce a clear architectural benefit: the 32 MiB payload produced zero
Dart response chunks and zero Dart response reads. This task did not isolate
Dart heap or native RSS sufficiently to publish a quantified benefit.

### 8. Is Android’s native `ByteBuffer` → `ByteArray` copy worth optimizing?

Not in this task and not on the current evidence. The prior measurement showed
the source-level copy, not a user-visible bottleneck. Keep it unchanged.

### 9. Is Apple’s `Data` splitting worth optimizing?

Not yet. Copies are verified, but correctness is now independent of eager queue
growth and no user-visible benefit from changing `Data.subdata` was measured.

### 10. Does AlphaX need isolate parsing helpers?

Not as part of this Apple fix. Prior task-37 evidence supports an optional
future extension only if a physical Flutter UI run demonstrates frame loss and
`Isolate.run` materially reduces main-isolate blocking. Do not add it to core
now.

### 11. Does AlphaX need a persistent worker pool?

No. Prior repeated parsing evidence did not justify its lifecycle, memory, and
cancellation complexity over caller-owned one-shot isolation.

### 12. Is FFI/shared-buffer work justified?

No. The remaining Apple copy boundary has not been shown to cause a
user-visible frame, CPU, or memory problem after the state-machine correction.
Simpler event and file-path work must be exhausted first.

## 22. Implementation recommendations

| Candidate | Classification | Rationale |
| --- | --- | --- |
| Correct Apple timing conversion | `IMPLEMENT_NOW` — completed here | Correctness; old values were ×1000. |
| Incremental Apple backpressure state machine | `IMPLEMENT_NOW` — completed here | Production 5 MiB timeout is fixed with the same window. |
| Safe/best-effort Apple file finalization and documentation | `IMPLEMENT_NOW` — completed here | Existing-target failure behavior is now tested; no false atomicity claim. |
| Keep 64 KiB × 4 | `IMPLEMENT_NOW` — decision retained | Correctness and bounded-window evidence are green. |
| Suppress progress events when no observer exists | `IMPLEMENT_POST_1_0` | Native off-observer traffic is verified; measure impact separately. |
| Document/coalesce requested progress cadence | `MEASURE_MORE` then `IMPLEMENT_POST_1_0` | Potential high-frequency event reduction, but cadence is API behavior. |
| Credit batching | `MEASURE_MORE` | Must preserve pause, fairness, cancellation, and bounded bursts. |
| Public `nativeFilePathUsed` fact | `OPTIONAL_EXTENSION` | Useful diagnostics, but requires additive contract review; private evidence is sufficient now. |
| Optional isolate-transform helper | `MEASURE_MORE` | Only after physical UI evidence; keep outside `alphax` core. |
| Persistent worker pool | `DO_NOT_IMPLEMENT` | No demonstrated repeated-workload benefit. |
| Android direct-file copy rewrite | `DO_NOT_IMPLEMENT` | No user-visible benefit established. |
| Apple `Data.subdata` rewrite | `DO_NOT_IMPLEMENT` | Known copy without measured user-visible payoff. |
| FFI/shared/native-memory transport | `DO_NOT_IMPLEMENT` | Complexity and lifecycle risk exceed current evidence. |
| Advanced H3/DoH/0-RTT/migration knobs | `DO_NOT_IMPLEMENT` | Provider/network policy should remain managed; no concrete need was shown. |
| New benchmark leaderboard or performance claim | `DO_NOT_IMPLEMENT` for this release step | Current Apple data is correctness evidence, not a cross-device ranking. |

## 23. Top three post-1.0 investments

1. Measure and, if confirmed, suppress unused native/Dart progress traffic and
   define a documented requested-progress cadence.
2. Run a properly matched physical Flutter UI study on Android and iPhone,
   separating transport, bridge integration, parsing, and frame effects. Use
   that evidence to decide whether an opt-in transform helper is warranted.
3. Extend honest observability around completion metrics, native-file mode, and
   cancellation/backpressure state, then publish only separated transport,
   integration, and UI reports after device coverage is adequate.

## 24. Explicit DO_NOT_IMPLEMENT list

- Do not replace URLSession or Cronet.
- Do not add C++, Rust, libcurl, or a second native engine.
- Do not add FFI/shared-memory/native external buffers to chase literal
  “zero-copy”.
- Do not change 64 KiB × 4 based on this result.
- Do not add a persistent worker isolate pool.
- Do not add `alphax_transform`/`alphax_compute` yet.
- Do not rewrite Android `ByteBuffer` → `ByteArray` or Apple `Data.subdata`.
- Do not add advanced H3, DoH, 0-RTT, migration, or prewarming knobs without a
  concrete user case and provider-specific evidence.
- Do not suppress/coalesce progress in this task; that is the next separate P1
  task.
- Do not publish a “fastest client” or AlphaX performance claim from these
  runs.

## 25. Recommended next engineering task

`Progress traffic suppression/coalescing measurement and implementation`

This should be a separate P1 task. It must first compare progress requested vs
not requested on matched physical-device runs, retain progress semantics, and
measure native events, Dart callbacks, CPU, RSS, cancellation, and Flutter frame
impact before changing behavior.

The current task is complete for the Apple timing/backpressure/file correctness
scope. No further optimization work is started here.

APPLE URLSESSION CORRECTNESS HARDENED
