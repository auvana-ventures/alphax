# AlphaX Phase 0 macOS local Round 2 investigation

Status: Phase 0 investigation complete for the current macOS local profile. This
report does not select a production transport, accept ADR-0004, or begin Phase 1.

## Dataset and reproducibility

The retained Round 2 dataset contains 630 samples: seven selected scenarios, 30
measured iterations per candidate and scenario, and three candidates. Each
candidate ran in an isolated Dart process after three warmups. Correctness ran
before performance collection.

- [Round 2 raw samples](../raw/macos-local-0674bcb641ef4e40ce576bee2903ee7771193d5e-dirty.json)
- [Round 2 machine-readable summary](macos-local-0674bcb641ef4e40ce576bee2903ee7771193d5e-dirty.json)
- [Round 2 generated summary](macos-local-0674bcb641ef4e40ce576bee2903ee7771193d5e-dirty.md)
- [Original macOS raw dataset](../raw/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.json)
- [Original macOS summary](macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.md)
- [Round 2 binary-size measurement](../raw/binary-size-macos-round2-0674bcb-dirty.json)

Environment: macOS 26.5.2 (Build 25F84), arm64 Apple M4, Dart 3.12.2,
Flutter 3.44.6 metadata only, libcurl 8.7.1, Rust 1.97.1, reqwest 0.12.28,
hyper 1.11.0. The profile is localhost with no latency, bandwidth, or packet-loss
simulation. The server is an HTTP/1.1-compatible local server; no HTTP/2 or HTTP/3
benchmark was added.

The files are reproducible against commit
`0674bcb641ef4e40ce576bee2903ee7771193d5e` plus the dirty worktree changes used
for this investigation. No commit was created during this investigation, so a
clean commit-only reproduction awaits maintainer review and commit creation.

The command used for the selected profile was:

```text
ALPHAX_CURL_LIBRARY="$PWD/prototypes/libcurl_ffi/libalphax_curl.dylib" \
ALPHAX_RUST_LIBRARY="$PWD/prototypes/rust_http/target/release/libalphax_rust_http.dylib" \
dart run benchmarks/runner/bin/run_benchmarks.dart \
  --warmup 3 --iterations 30 \
  --only small_1024_warm,concurrency_100,concurrency_250,download_104857600_bytes,upload_10485760_bytes,upload_104857600_bytes,stream_2097152_bytes_slow_consumer \
  --output benchmarks/results
```

## Executive findings

| Investigation area | Finding | Decision status |
| --- | --- | --- |
| libcurl upload anomaly | The fixed approximately one-second cost was `Expect: 100-continue` waiting for an interim response the local server does not send. | Explained and corrected in the prototype. |
| libcurl event loop | The corrected loop uses `curl_multi_timeout`, `curl_multi_poll`, and `curl_multi_wakeup`; it does not use an unconditional one-second sleep. | Prototype behavior understood; production event-loop design remains open. |
| Upload correctness | All candidates sent the exact deterministic byte count and matching FNV-1a 64 hash for 10 MB and 100 MB. | Passed. |
| Timing parity | Round-trip boundaries are equivalent; native lifecycle fields additionally expose body-send and cleanup stages where available. | Confirmed with stated limits. |
| 250 concurrency | libcurl opens one observed server connection per request in this prototype and has materially more native polling work. | Performance result is descriptive, not an inherent transport verdict. |
| Slow consumer | Dart pauses upstream delivery; both FFI prototypes continue callbacks into an unbounded Dart queue. | Semantics are not comparable yet. |
| CPU and memory | Process-level CPU, RSS, and high-water RSS are captured. Component-level allocation is unavailable. | Available with cumulative-process caveats. |
| Binary size | Stripped native payloads and dynamic dependencies are separated. Candidate app deltas are harness-entry-point deltas, not deployable-app deltas. | Methodology corrected; production packaging remains missing. |
| Statistics | Thirty measured samples are retained for key scenarios. Current distributions are noisy and classifications do not identify a winner. | No transport selection. |

## 1. libcurl upload root cause

The original raw dataset reported libcurl upload p50 values of approximately
1,011.413 ms for 10 MB and 1,073.081 ms for 100 MB. A libcurl trace showed:

```text
Expect: 100-continue
...
Done waiting for 100-continue
```

The deterministic Dart server consumes the request body but does not emit an
interim `100 Continue` response. libcurl therefore waited for its normal
`100-continue` decision timeout before sending the file body. The delay was not
caused by file preparation, the upload callback, completion polling, or native
cleanup.

The correctness-preserving fix is limited to file uploads: the prototype sends
an empty `Expect:` request header, avoiding an optional handshake that this local
server cannot complete. No arbitrary sleep or benchmark-only subtraction was
added. The current Round 2 p50 values are 55.498 ms for 10 MB and 594.811 ms for
100 MB. These are not paired runs with the original dataset, so the absolute
before/after values should be read as evidence of removal of the fixed delay,
not as a controlled performance improvement estimate.

### libcurl upload lifecycle, p50

All values below are milliseconds from libcurl request creation unless the row is
explicitly described as a duration. Dart values use the same operation stopwatch
and include Dart-side completion and cleanup boundaries.

| Lifecycle point | 10 MB | 100 MB |
| --- | ---: | ---: |
| Body preparation completed | 0.155 | 0.203 |
| First readable upload callback | 0.480 | 0.786 |
| First upload byte submitted | 0.563 | 0.830 |
| Last upload byte submitted | 40.801 | 532.761 |
| Server body-read duration | 51.029 | 586.609 |
| Response headers received | 52.640 | 592.148 |
| Response body complete | 52.786 | 592.952 |
| `CURLMSG_DONE` observed | 52.786 | 592.952 |
| Native completion notification | 52.824 | 593.036 |
| Native handle cleanup returned | 52.824 | 593.036 |
| Dart completion notification | 55.471 | 594.770 |
| Dart handle cleanup returned | 55.489 | 594.797 |
| Future completed / benchmark end | 55.498 | 594.811 |
| `curl_multi_poll` calls | 167 | 1,629 |
| Aggregate poll wait | 46.565 | 502.090 |
| Longest observed poll wait | 17.784 | 57.779 |
| Upload read callbacks | 161 | 1,601 |

The server body-read value is a server-side duration, not a timestamp on the
client timeline. The last-submitted-byte timestamp and the benchmark end are
therefore intentionally separate measurements.

The 10 MB and 100 MB uploads both reported exact callback/submission counts:
10,485,760 and 104,857,600 bytes respectively. No truncation, compression,
short-circuit response, or hash mismatch was observed.

## 2. libcurl event-loop review

The async prototype now performs the following loop:

1. Call `curl_multi_perform`.
2. Ask libcurl for its next deadline with `curl_multi_timeout`.
3. Wait for socket readiness with `curl_multi_poll`.
4. Repeat until no transfers remain and inspect `CURLMSG_DONE`.

The wait is bounded by libcurl's reported timeout. When libcurl reports no
deadline, the prototype uses a documented 1,000 ms fallback bound; it is not a
fixed sleep between every progress check. Cancellation calls `curl_multi_wakeup`
so a waiting poll can return promptly. This follows libcurl's multi-interface
guidance for [`curl_multi_timeout`](https://curl.se/libcurl/c/curl_multi_timeout.html)
and [`curl_multi_poll`](https://curl.se/libcurl/c/curl_multi_poll.html).

Upload and download use the same event-loop shape. Uploads additionally use a
file read callback; downloads use a response callback and the native file path.
The lifecycle data shows the corrected upload begins its first callback within
approximately one millisecond, so the original one-second anomaly was not a
coarse completion poll.

The prototype still creates an independent easy/multi pair and worker thread per
request. It shares DNS state but intentionally does not share libcurl's
connection pool across those multi handles: enabling shared connection state in
this design caused a reproducible crash inside libcurl connection-cache cleanup
under 250-way concurrency. A production-like client-owned multi/socket event loop
and shared connection pool have not been implemented and must not be inferred
from this prototype.

## 3. Timing boundaries and transfer semantics

The benchmark boundaries are:

- upload starts before file length/stat preparation for every candidate;
- connection establishment is included;
- upload ends after response-body completion, native completion notification,
  native handle cleanup, and the Dart Future boundary;
- download starts before request creation and ends after the response has been
  written and the file sink closed;
- concurrency starts before the request futures are created and ends after all
  futures complete.

The elapsed upload number is therefore request round-trip time, not merely the
time until the last request byte leaves the process. The libcurl lifecycle also
records the last submitted byte, server body-read completion, response headers,
and cleanup. Equivalent last-byte timestamps are not currently exposed by Dart IO
or Rust at the same boundary, so those sub-intervals are diagnostic rather than
a cross-candidate ranking metric.

JSON decoding and parsing are separate runner measurements and are not included
in the raw-byte transport scenarios.

## 4. Correctness and upload hash validation

Each candidate passed all 10 correctness checks: status codes, headers, byte
bodies, POST echo, streaming completeness, upload completeness, download
completeness, timeout, waiting cancellation, and redirects.

| Candidate | Correctness | Checks | 10 MB count/hash | 100 MB count/hash |
| --- | --- | ---: | --- | --- |
| Dart IO | passed | 10/10 | 10,485,760 / `0d1fe070e4ab59c5` | 104,857,600 / `5db029fd007b7ea5` |
| libcurl/FFI | passed | 10/10 | 10,485,760 / `0d1fe070e4ab59c5` | 104,857,600 / `5db029fd007b7ea5` |
| Rust reqwest/hyper/FFI | passed | 10/10 | 10,485,760 / `0d1fe070e4ab59c5` | 104,857,600 / `5db029fd007b7ea5` |

The server emits the upload response only after consuming the complete request
body. The upload hash and byte-count fields are retained in every raw transfer
sample.

## 5. 250-concurrency libcurl investigation

The original 250-concurrency libcurl result was not treated as final evidence
because sharing `CURL_LOCK_DATA_CONNECT` between independent request multi
handles caused a macOS crash in libcurl connection-cache cleanup. The prototype
now shares only DNS state and completes 30 measured 250-request batches without
that crash.

Current p50 round-trip latency is:

| Scenario | Dart IO | libcurl/FFI | Rust/FFI |
| --- | ---: | ---: | ---: |
| 100 concurrent 1 KB GETs | 20.438 ms | 56.782 ms | 37.114 ms |
| 250 concurrent 1 KB GETs | 35.163 ms | 125.501 ms | 57.688 ms |

The current run is materially different from the original exploratory run
(24.080 ms, 51.644 ms, and 24.245 ms at 250 concurrency respectively), which is
why the generated classification is inconclusive. No single run is being
declared representative of host scheduling or native connection behavior.

For the current libcurl 250-request batches, the p50 diagnostics show 515
aggregate poll calls, 11.539 seconds of aggregate poll wait across the 250
handles, a 60.310 ms longest individual poll wait, and 250 response callbacks.
The server observed 250 distinct client connections per batch and one request per
connection. This is consistent with the prototype's per-request multi-handle
architecture, not evidence that libcurl itself cannot reuse connections.

The server identifies local connections by remote address and port. It is useful
local evidence but is not a transport-level connection-cache counter. Dart IO
observed approximately 29.70 requests per observed connection at 100 concurrency
and 30 at 250 across the measured batches. Rust observed 2,999/3,000 IDs at 100
and 7,484/7,500 at 250 in this long sequential run; 28 of 30 Rust 250 batches
had all 250 IDs, while two batches had partial observation. A fresh isolated
250-request Rust check immediately after the run observed 250/250 IDs. The
remaining discrepancy is retained as a callback/observation instrumentation
uncertainty, not converted into a reuse or latency claim.

## 6. Slow-consumer backpressure

The slow-consumer scenario transfers 2 MiB while delaying consumption of each
chunk. The p50 observations are:

| Candidate | p50 total | Producer chunks | Consumer chunks | Max observed buffered bytes | Buffered at native completion | Pause support |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Dart IO | 167.353 ms | 32 | 32 | unavailable | unavailable | yes; upstream response subscription pauses |
| libcurl/FFI | 829.731 ms | 134 | 134 | 2,064,704 | 2,064,704 | no; callback delivery continues |
| Rust/FFI | 266.060 ms | 32 | 32 | 2,031,616 | 2,031,616 | no; callback delivery continues |

The FFI queue capacity is null and the current policy is an unbounded Dart
`StreamController` buffer. At native completion, the consumer had observed only
one chunk in the FFI cases while almost the entire 2 MiB response was buffered.
Dart's response subscription can pause upstream reads while the consumer awaits
the next chunk. Pause and resume latency are unavailable because the FFI
prototypes do not implement native pause/resume controls.

The durations are consequently not an apples-to-apples transport comparison.
The FFI prototypes need a bounded queue and explicit pause/resume semantics
before slow-consumer performance can support a production decision.

## 7. Binary-size methodology correction

The corrected script measures stripped arm64 macOS release artifacts and reports
application artifacts, native library payloads, and dynamic dependencies
separately:

| Artifact | Stripped bytes | Interpretation |
| --- | ---: | --- |
| Dart baseline benchmark application | 6,441,368 | Release Dart AOT benchmark entry point |
| libcurl benchmark application | 5,912,984 | Different FFI benchmark entry point; not a production-app delta |
| Rust benchmark application | 5,912,976 | Different FFI benchmark entry point; not a production-app delta |
| libcurl native wrapper | 37,144 | Separate stripped distributable dylib |
| Rust native library | 3,706,288 | Separate stripped distributable dylib containing the Rust dependency graph |

The reported application deltas of approximately -528 KB are not meaningful
incremental AlphaX sizes because the three benchmark entry points have different
dependency trees and are not equivalent release applications. They are retained
only as artifact observations.

Native dependency accounting:

- libcurl wrapper: dynamically depends on system `libcurl.4.dylib` and
  `libSystem.B.dylib`; the system libcurl is not counted in the 37,144 bundled
  bytes;
- Rust library: dynamically depends on system `libiconv.2.dylib` and
  `libSystem.B.dylib`; reqwest, hyper, Tokio, rustls, and their Rust dependencies
  are included in the Rust native dylib rather than listed as separate dynamic
  libraries;
- all artifacts are stripped before measurement.

The macOS system-library arrangement cannot be assumed for Android, iOS, Linux,
or Windows. A deployable application-size comparison for each target remains
missing, and these results are not extrapolated to those platforms.

## 8. Process CPU and memory observations

The runner records process-level `ps` CPU time/utilization, current RSS, and
`ProcessInfo.maxRss` before and after each measured scenario. CPU utilization is
derived from cumulative process CPU time divided by scenario wall time, so values
above 100% are expected for multithreaded candidates. The candidate processes are
isolated from each other but scenarios run sequentially inside each candidate
process.

The following p50 values are descriptive observations from the current run. RSS
after is resident memory at the scenario boundary, not an allocation attribution;
the max-RSS column is a cumulative process high-water value and can include an
earlier scenario in the same child process.

| Candidate / scenario | CPU p50 | RSS after p50 | Cumulative max RSS p50 |
| --- | ---: | ---: | ---: |
| Dart IO / 100 concurrent | 153.89% | 241.7 MiB | 398.7 MiB |
| Dart IO / 250 concurrent | 141.18% | 248.4 MiB | 398.7 MiB |
| Dart IO / 100 MB download | 122.65% | 1,229.0 MiB | 1,348.1 MiB |
| Dart IO / 100 MB upload | 117.10% | 997.4 MiB | 1,357.4 MiB |
| Dart IO / slow consumer | 62.18% | 448.0 MiB | 1,357.4 MiB |
| libcurl/FFI / 100 concurrent | 155.42% | 242.6 MiB | 398.9 MiB |
| libcurl/FFI / 250 concurrent | 123.21% | 188.2 MiB | 398.9 MiB |
| libcurl/FFI / 100 MB download | 125.80% | 654.1 MiB | 1,124.6 MiB |
| libcurl/FFI / 100 MB upload | 88.22% | 125.8 MiB | 1,124.6 MiB |
| libcurl/FFI / slow consumer | 14.48% | 80.4 MiB | 1,124.6 MiB |
| Rust/FFI / 100 concurrent | 186.40% | 129.1 MiB | 383.4 MiB |
| Rust/FFI / 250 concurrent | 172.80% | 143.8 MiB | 383.4 MiB |
| Rust/FFI / 100 MB download | 157.61% | 121.4 MiB | 850.7 MiB |
| Rust/FFI / 100 MB upload | 204.14% | 168.1 MiB | 1,123.7 MiB |
| Rust/FFI / slow consumer | 49.39% | 136.7 MiB | 1,123.7 MiB |

These measurements establish that process-level metrics are available, but they
do not establish Dart-heap versus native-allocation ownership. The large
high-water values and negative/near-zero between-boundary RSS changes show why
memory comparisons must use per-scenario child processes or a dedicated sampling
protocol before being used for a transport decision.

## 9. Latency statistics and interpretation

The runner retained raw samples and computed minimum, mean, p25, p50, p75, p90,
p95, p99, maximum, and population standard deviation. p99 is included because
each selected group has 30 samples.

| Candidate | Scenario | N | Min ms | Mean ms | p50 ms | p90 ms | p95 ms | p99 ms | Max ms | SD ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Dart IO | small 1 KB warm | 30 | 0.439 | 0.948 | 0.768 | 1.511 | 1.757 | 2.209 | 2.209 | 0.470 |
| Dart IO | 100 concurrent | 30 | 17.163 | 21.990 | 20.438 | 28.431 | 29.130 | 31.126 | 31.126 | 3.850 |
| Dart IO | 250 concurrent | 30 | 28.333 | 36.052 | 35.163 | 41.570 | 43.360 | 43.463 | 43.463 | 3.856 |
| Dart IO | 100 MB download | 30 | 979.422 | 1,195.003 | 1,144.790 | 1,517.812 | 1,630.089 | 1,672.014 | 1,672.014 | 189.954 |
| Dart IO | 10 MB upload | 30 | 33.786 | 37.508 | 35.916 | 41.137 | 42.505 | 53.436 | 53.436 | 3.938 |
| Dart IO | 100 MB upload | 30 | 301.405 | 311.559 | 306.986 | 325.904 | 337.401 | 350.136 | 350.136 | 11.336 |
| Dart IO | slow consumer | 30 | 160.822 | 170.031 | 167.353 | 176.528 | 182.516 | 190.124 | 190.124 | 6.256 |
| libcurl/FFI | small 1 KB warm | 30 | 0.876 | 1.522 | 1.452 | 2.012 | 2.471 | 2.911 | 2.911 | 0.459 |
| libcurl/FFI | 100 concurrent | 30 | 35.927 | 59.590 | 56.782 | 83.404 | 87.835 | 97.002 | 97.002 | 15.626 |
| libcurl/FFI | 250 concurrent | 30 | 77.267 | 140.121 | 125.501 | 190.286 | 221.344 | 237.208 | 237.208 | 38.693 |
| libcurl/FFI | 100 MB download | 30 | 1,434.645 | 2,171.062 | 1,978.979 | 2,928.074 | 3,251.808 | 4,838.520 | 4,838.520 | 714.362 |
| libcurl/FFI | 10 MB upload | 30 | 41.139 | 67.778 | 55.498 | 101.798 | 123.315 | 203.402 | 203.402 | 32.441 |
| libcurl/FFI | 100 MB upload | 30 | 509.814 | 647.872 | 594.811 | 741.149 | 1,170.267 | 1,295.451 | 1,295.451 | 173.057 |
| libcurl/FFI | slow consumer | 30 | 626.055 | 939.400 | 829.731 | 1,297.181 | 1,355.407 | 1,533.615 | 1,533.615 | 240.714 |
| Rust/FFI | small 1 KB warm | 30 | 1.274 | 5.388 | 3.123 | 9.646 | 12.041 | 41.619 | 41.619 | 7.314 |
| Rust/FFI | 100 concurrent | 30 | 26.551 | 39.768 | 37.114 | 52.824 | 61.812 | 62.040 | 62.040 | 9.792 |
| Rust/FFI | 250 concurrent | 30 | 45.514 | 65.031 | 57.688 | 84.330 | 114.760 | 119.333 | 119.333 | 18.917 |
| Rust/FFI | 100 MB download | 30 | 1,265.250 | 1,551.222 | 1,493.052 | 1,894.140 | 1,959.329 | 2,507.090 | 2,507.090 | 257.839 |
| Rust/FFI | 10 MB upload | 30 | 42.081 | 72.060 | 68.848 | 91.737 | 92.993 | 95.294 | 95.294 | 11.366 |
| Rust/FFI | 100 MB upload | 30 | 643.029 | 829.087 | 770.110 | 1,071.175 | 1,222.057 | 1,440.596 | 1,440.596 | 180.304 |
| Rust/FFI | slow consumer | 30 | 159.417 | 234.228 | 266.060 | 291.575 | 304.515 | 332.796 | 332.796 | 57.243 |

The generated classification rule is:

- approximately equivalent: p50 difference at most 5%;
- clear difference: at least 20% separation, non-overlapping p25-p75 intervals,
  and coefficient of variation at most 10% for both candidates;
- likely difference: at least 10% separation and coefficient of variation at
  most 20%;
- otherwise inconclusive.

For this run, small requests, both concurrency scenarios, both uploads, and the
slow-consumer scenario are inconclusive. The 100 MB download is classified as a
likely Dart IO difference, but this remains a scenario-local observation with
host and memory variance, not a winner declaration. No synthetic overall score
was generated.

## 10. Preliminary candidate assessment

This is a preliminary evidence summary only.

### Dart IO

- Performance: lowest p50 in the current concurrency and upload scenarios, and
  the fastest current slow-consumer total; the distributions are still local
  and host-sensitive.
- Memory: process RSS/high-water measurements are available, but the VM, file
  buffers, and earlier scenarios cannot be separated reliably in this run.
- Binary size: baseline for this harness; no incremental native payload.
- Implementation complexity: lowest; no C ABI, native library, or callback
  ownership boundary.
- FFI overhead: none in the transport path.
- Streaming: Dart response subscription pauses upstream delivery; this is the
  only candidate with observed pause support in this prototype set.
- File transfer: Dart-managed file stream and Dart sink, not the same path as
  native direct-to-file candidates.
- Maintainability: simplest current prototype, subject to the capabilities of
  `dart:io` on each target.
- Cross-platform implications: broad Dart platform availability, but target
  performance and platform-specific networking behavior remain untested.

### libcurl/FFI

- Performance: the fixed upload anomaly is removed; current 250-concurrency and
  slow-consumer results include measurable per-request multi/poll and buffering
  costs.
- Memory: direct native file paths avoid returning large file bodies to Dart, but
  stream callbacks still copy into Dart and the queue is unbounded.
- Binary size: the stripped wrapper is small, but the candidate depends on a
  system libcurl on macOS; other targets need explicit dependency accounting.
- Implementation complexity: C ABI, native worker threads, curl multi/easy
  lifecycle, callback ownership, cancellation wakeups, and share-lock rules.
- FFI overhead: response callbacks cross into Dart and copy each chunk; the
  250-concurrency callback/poll volume is material evidence for further design
  work.
- Streaming: no native pause/resume; current unbounded Dart queue is not a
  production backpressure design.
- File transfer: native file read/write paths are exercised and are a promising
  minimal-copy direction, but no zero-copy claim is made.
- Maintainability: dependent on careful libcurl ABI/version and event-loop
  integration; shared connection pooling is unresolved in this prototype.
- Cross-platform implications: system libcurl availability, TLS backend,
  packaging, and build/CI requirements vary by target.

### Rust reqwest/hyper/FFI

- Performance: current p50 is competitive in concurrency and download, but
  uploads and slow-consumer results are affected by FFI queue semantics and
  high variance.
- Memory: native direct-file paths are exercised; process-level numbers cannot
  yet separate Tokio/reqwest/Rust allocations from the Dart process.
- Binary size: the stripped native dylib is approximately 3.7 MB and includes
  the Rust dependency graph in this artifact; target packaging is unmeasured.
- Implementation complexity: long-lived Tokio runtime, reqwest client,
  per-request native worker threads, cancellation, callback allocation, and C
  ABI layout.
- FFI overhead: native chunks are copied into Dart lists and queued without a
  bounded capacity; completion/start callback ordering required explicit
  instrumentation handling.
- Streaming: producer and consumer chunk counts are complete, but native
  delivery continues while Dart is paused; bounded backpressure is unresolved.
- File transfer: native upload and download paths are exercised and avoid
  returning large file contents through Dart.
- Maintainability: dependency graph and toolchain are larger than the Dart
  baseline; the long-lived runtime is a coherent prototype boundary but not a
  production decision.
- Cross-platform implications: Rust toolchain, TLS backend, native artifact
  packaging, and target linker/ABI work remain untested on Android, iOS,
  Windows, Linux, and web.

## Remaining uncertainties and decision gate

The following evidence is still missing or not normalized enough for a primary
transport decision:

- clean commit-only rerun after maintainer review;
- a production-like shared libcurl multi/socket event loop and connection pool;
- a fully reliable Rust connection observation record under the complete long
  sequential profile;
- bounded native FFI queues with real pause/resume and cancellation semantics;
- per-scenario process-memory sampling or fresh child processes for each memory
  scenario, plus reliable Dart/native ownership attribution;
- equivalent release application packaging for incremental binary size;
- reproducible good-network, typical-mobile, and poor-network profiles;
- HTTP/2 and HTTP/3 comparisons after the local harness is stable;
- mobile, Windows, Linux, iOS, Android, and web capability/build evidence.

Decision gate:

- [x] libcurl upload anomaly explained.
- [x] Timing parity confirmed for the benchmark round-trip boundaries.
- [x] Binary-size accounting separated application, bundled native, and system dependencies.
- [x] Process CPU metrics available.
- [x] Process memory/RSS metrics available, with cumulative high-water limitations documented.
- [ ] Connection reuse fully resolved under the complete long sequential profile; isolated Rust verification passes, but two long-run batches had partial ID observation.
- [ ] Backpressure semantics comparable; FFI prototypes still use unbounded queues.
- [x] Key scenarios have at least 30 measured samples after warmup.

Phase 0 stops here for review. No production transport has been selected, no
primary-transport ADR has been accepted, no C++ engine has been introduced, and
Phase 1 has not started.
