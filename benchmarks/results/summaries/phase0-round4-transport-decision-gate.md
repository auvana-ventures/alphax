# AlphaX Phase 0 Round 4 transport decision gate

**Decision: INSUFFICIENT EVIDENCE**

This report is the final planned Phase 0 architecture-validation round. It does
not select a production transport, modify the public AlphaX architecture, accept
ADR 0004, or begin Phase 1. No C++ engine was introduced. The candidates remain
`dart:io`/`HttpClient`, libcurl through the minimal C ABI and Dart FFI, and Rust
reqwest/hyper through the C ABI and Dart FFI.

## Executive result

Round 4 fixed the most important local fairness defect: libcurl now owns one
persistent multi handle and reuses connections for sequential requests. The
previous approximately one-second upload anomaly was also explained as an
`Expect: 100-continue` interaction with the deterministic Dart server, rather
than a libcurl event-loop delay. The corrected local measurements are useful.

The evidence is not yet sufficient for a final transport recommendation because:

- no reproducible impaired-network measurements were run on this macOS host;
- Dart did not negotiate HTTP/2 in the current client, so the HTTP/2 dataset is
  a native-candidate comparison rather than a three-way comparison;
- macOS artifact measurements are transparent but are not equivalent deployable
  builds for Linux, Android, or iOS;
- per-phase TLS timings are not exposed equivalently by all three candidates;
- direct native-file paths intentionally compare different architectures from
  Dart-stream-to-file paths and therefore cannot alone establish a transport
  winner.

The smallest remaining decision experiment is one controlled Linux VM, runner,
or self-hosted environment with the same trusted HTTP/2 fixture and `tc`/`netem`
profiles. It should run the three candidates under local, good, typical-mobile,
and poor profiles with explicit ALPN and connection observations. Cross-platform
release artifact accounting remains a separate packaging gate, not a reason to
start a broad new benchmark round.

## 1. Scope, provenance, and methodology

The primary macOS local dataset is:

- [raw local samples](../raw/macos-local-3a141600757f7cc89c5b4fe40a010119de2f9cee-dirty-chunk65536-window4-network-local-only-12-connection_reuse_sequential-cancellation_upload.json)
- [local machine-readable summary](macos-local-3a141600757f7cc89c5b4fe40a010119de2f9cee-dirty-chunk65536-window4-network-local-only-12-connection_reuse_sequential-cancellation_upload.json)
- [local generated summary](macos-local-3a141600757f7cc89c5b4fe40a010119de2f9cee-dirty-chunk65536-window4-network-local-only-12-connection_reuse_sequential-cancellation_upload.md)

It was collected on macOS 26.5.2, Apple M4 arm64, Dart 3.12.2, Flutter 3.44.6,
libcurl 8.7.1 with SecureTransport/nghttp2, and Rust 1.97.1. The raw metadata
records commit `3a141600757f7cc89c5b4fe40a010119de2f9cee` and a dirty worktree;
the dirty state is intentional because it identifies the Round 4 code under
test. Historical Round 1, Round 2, and Round 3 data remain separate and were not
rewritten.

The clean local decision-sensitive run used three warmups and 30 measured samples
per candidate/scenario. TLS HTTP/1.1 used 10 measured samples. The native HTTP/2
core scenarios used 30 samples where practical and the extended 10 MB/100 MB
transfer scenarios used 10 samples. Raw samples are retained. Summaries report
minimum, mean, p50, p90, p95, maximum, and standard deviation; p99 is only used
when the sample count supports it.

The existing classification rule is retained:

- approximately equivalent: p50 difference no greater than 5%;
- clear difference: at least 20% separation, non-overlapping p25-p75 ranges,
  and coefficient of variation no greater than 10%;
- likely difference: at least 10% separation with coefficient of variation no
  greater than 20%;
- otherwise inconclusive.

The benchmark boundary includes connection establishment. Upload timing starts
before file stat/preparation and ends after response-body completion and native
cleanup notification. Download timing ends after the file sink closes. JSON
decoding and parsing are not included in transport timings.

## 2. libcurl persistent-engine architecture

The prototype now has a client-owned lifecycle:

```text
AlphaX libcurl client
        |
  one persistent worker
        |
  one CURLM multi handle
        |
  many concurrent CURL easy handles
        |
  shared curl connection/cache state
```

The worker owns the multi handle and request list. It drives progress with
`curl_multi_perform`, obtains the next timeout with `curl_multi_timeout`, waits
with `curl_multi_poll`, and is woken by `curl_multi_wakeup` when Dart submits or
cancels work. There is no fixed long sleep and no per-request worker thread or
per-request multi handle. Shutdown marks the client closed, wakes the worker,
cancels remaining requests, drains completion messages, and joins the worker.

Streaming uses a credit-bounded callback path. The normal benchmark setting is
64 KiB chunks and four credits. A callback accepts a complete chunk only when
the bounded queue can hold it; otherwise it pauses the easy handle. Dart
acknowledgement restores credits and wakes the multi worker. Cancellation wakes
the worker and releases the easy handle and request state.

The implementation is still a benchmark prototype, not a production engine.
In particular, the worker serializes multi-handle progress and the FFI contract
is intentionally smaller than the future AlphaX API. The current production
architecture and ownership rules are documented in the
[`architecture overview`](../../../docs/architecture/overview.md) and
[`transport contract`](../../../docs/architecture/transport_contract.md).

### Upload anomaly investigation

The old approximately one-second libcurl upload result was caused by the
optional `Expect: 100-continue` handshake. The local Dart server consumes the
request body but does not emit the interim `100 Continue` response, so libcurl
waited for its expectation timeout before sending the body. The correction
removes that optional expectation for the benchmark file-upload path; it does
not disable TLS verification or add an arbitrary timing adjustment.

The corrected 100 MB libcurl lifecycle median, in microseconds from request
creation, was approximately:

| Event | Median |
| --- | ---: |
| request preparation complete | 63 |
| first upload callback | 120.5 |
| first byte submitted | 165 |
| last upload byte submitted | 242,197 |
| response headers received | 271,765.5 |
| response body complete | 272,052.5 |
| `CURLMSG_DONE` | 272,042 |
| native completion notification | 272,071.5 |
| Dart completion notification | 272,364.5 |
| Dart future completed | 272,387 |
| maximum observed poll wait | 27,340 |

The aggregate poll wait was about 240,490.5 microseconds across approximately
1,617 polls; it was transfer progress, not a one-second fixed sleep. Exact
per-sample lifecycle records remain in the raw local dataset. Both 10 MB and
100 MB uploads validated the exact byte count and deterministic FNV-1a 64 hash.

## 3. Connection reuse

The persistent-engine acceptance criterion was met for sequential HTTP/1.1
requests:

| Workload | Dart IO | libcurl | Rust |
| --- | ---: | ---: | ---: |
| 100 sequential requests, distinct server connections | 1 | 1 | 1 |
| Requests per connection | 100 | 100 | 100 |
| 100 concurrent requests, approximate distinct connections | ~100 | ~100 | ~100 |
| 250 concurrent requests, approximate distinct connections | 250 | median ~223 | 250 |

The high connection counts for HTTP/1.1 concurrency are a property of the
current clients/server workload and are reported rather than inferred away.
They are not evidence that libcurl is still creating one multi handle per
request. Sequential reuse is now directly observed from server connection
identifiers.

The HTTP/2 fixture produced a different and useful observation:

| Workload | libcurl | Rust |
| --- | --- | --- |
| 100 concurrent | 1 connection, multiplexed | 1 connection, multiplexed |
| 250 concurrent | 3 connections, multiplexed | 1 connection, multiplexed |
| 100 sequential | 1 connection, 100 requests | 1 connection, 100 requests |

The Dart server cannot expose connection close events through the current Dart
`HttpServer` API, so close-event counts remain unavailable. Connection release is
validated through client shutdown/resource-release tests.

## 4. Bounded streaming and backpressure

The baseline is 64 KiB chunks × four credits = 256 KiB of native credit-window
capacity. Both native candidates stop network consumption when credits are
exhausted and resume after Dart acknowledgement. The benchmark does not use an
unbounded native callback queue.

| Measurement, paused consumer | libcurl | Rust |
| --- | ---: | ---: |
| configured logical capacity | 262,144 B | 262,144 B |
| maximum native in-flight chunks | 4 | 4 |
| maximum observed buffered bytes | 262,144 B | 327,680 B* |
| FFI notifications for 2 MiB stream | 32 | 32 |
| pause latency p50 | ~22.5 ms | ~22.4 ms |
| resume latency p50 | <20 µs | <20 µs |

\* Rust retains one additional bounded upstream response chunk while the credit
window is paused. That is a bounded implementation detail, not uncontrolled
growth; it is documented in the memory model.

For the 2 MiB local stream, p50 total duration was approximately 59.8 ms for
libcurl and 59.2 ms for Rust in the 30-sample clean run. With a slow consumer,
libcurl and Rust were approximately 141 ms and Dart IO approximately 156 ms. A
temporarily paused consumer was approximately 722–736 ms for all three. These
figures are meaningful only with the queue, pause, and resource observations
above; a faster result obtained by buffering indefinitely would not be a valid
transport win.

Cancellation while paused, consumer cancellation, and native resource release
passed the candidate correctness probes. The tested batching targets remain
16, 32, 64, 128, and 256 KiB; 64 KiB is retained as a benchmark baseline, not a
production default.

## 5. TLS and HTTP/1.1

`benchmarks/scripts/create-local-tls.sh` creates an ephemeral benchmark CA and a
localhost certificate with SANs for `localhost` and `127.0.0.1`. The Dart,
libcurl, and Rust clients trust that CA through an explicit environment setting;
certificate verification remains enabled. The deterministic Dart server
advertises only HTTP/1.1 through ALPN and records the server-observed protocol in
the response metadata.

The latest 10-sample 100 MB TLS results were:

| Scenario | Candidate | p50 ms | Mean ms | p95 ms | SD ms | Protocol | Connections |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: |
| 100 sequential | Dart IO | 60.276 | 61.889 | 71.934 | 6.810 | 1.1 | 1 |
| 100 sequential | libcurl | 42.267 | 42.486 | 47.349 | 3.928 | 1.1 | 1 |
| 100 sequential | Rust | 46.039 | 46.613 | 53.510 | 4.651 | 1.1 | 1 |
| 100 MB download | Dart IO | 1,450.148 | 1,455.602 | 1,520.847 | 51.443 | 1.1 | 1 |
| 100 MB download | libcurl | 1,450.886 | 1,466.632 | 1,587.260 | 69.173 | 1.1 | 1 |
| 100 MB download | Rust | 1,466.716 | 1,470.843 | 1,535.814 | 53.689 | 1.1 | 1 |
| 100 MB upload | Dart IO | 718.644 | 740.449 | 831.360 | 54.224 | 1.1 | 1 |
| 100 MB upload | libcurl | 904.810 | 914.012 | 967.176 | 33.393 | 1.1 | 1 |
| 100 MB upload | Rust | 842.851 | 867.586 | 979.644 | 59.585 | 1.1 | 1 |

Libcurl exposes connect, TLS, and TTFB phase metrics in this prototype. Dart
and Rust expose fewer phase boundaries, so the per-phase TLS comparison is not
yet symmetric. The table is therefore descriptive evidence, not a final TLS
ranking.

## 6. HTTP/2

The separate Docker fixture under
[`benchmarks/server/http2`](../../server/http2) pins Hypercorn and h2, advertises
only `h2`, and uses a configuration with enough request capacity for the Round 4
workload. `openssl s_client` verified the test CA and `ALPN protocol: h2`; curl
also completed an `HTTP/2 200` request.

The native candidates explicitly observed protocol `2`. Dart IO observed `1.1`
because the current client does not offer HTTP/2 in this prototype. Dart HTTP/2
is therefore marked unsupported/not-tested, not silently included as an HTTP/2
competitor.

Representative native HTTP/2 p50 results were:

| Scenario | libcurl | Rust | Protocol / connection observation |
| --- | ---: | ---: | --- |
| 1 KB warm | 1.150 ms | 1.287 ms | h2, 1 connection each |
| 100 sequential | 80.512 ms | 81.812 ms | h2, 1 connection each |
| 100 concurrent | 51.359 ms | 52.023 ms | h2, 1 connection each |
| 250 concurrent | 132.215 ms | 151.957 ms | h2, 3 vs 1 connections |
| 2 MiB stream | 151.563 ms | 150.527 ms | h2, 1 connection each |
| 10 MB download | 776.604 ms | 771.071 ms | h2, 1 connection each |
| 100 MB download | 7,746.232 ms | 7,708.014 ms | h2, 10 samples |
| 10 MB upload | 1,301.778 ms | 1,350.942 ms | h2, 10 samples |
| 100 MB upload | 12,871.127 ms | 13,818.535 ms | h2, 10 samples |

These results suggest broadly similar native HTTP/2 transfer behavior on this
local host, with workload-specific differences. They do not establish a final
choice because Dart is not an h2 participant and realistic network profiles were
not available.

## 7. Network profiles

The repository now contains two explicit shaping paths:

- `benchmarks/scripts/network-profile.sh` documents the macOS `dnctl`/`pfctl`
  path with explicit reset;
- `benchmarks/scripts/network-profile-linux.sh` applies and resets `tc`/`netem`
  rules on an explicitly selected interface through `ALPHAX_NETEM_INTERFACE`.

The host used for this dataset has no `tc`/`netem` toolchain. macOS packet
filtering was not applied because the run did not have a safe, repeatable
privileged automation path. Consequently, no good-network, typical-mobile, or
poor-mobile result is claimed. The local results measure client/runtime overhead
only and must not be presented as mobile-network performance.

The missing experiment is specifically cold, warm, 100 sequential, and 100
concurrent requests under local, approximately 30 ms RTT, approximately 100 ms
RTT/0.5% loss, and approximately 300 ms RTT/2% loss profiles. The exact topology,
bandwidth, loss, and cleanup commands must be retained with the raw metadata.

## 8. CPU and process RSS

Round 4 uses isolated candidate processes and samples process RSS during each
major scenario. CPU is process CPU time and sampled utilization. RSS is process
level; Dart/native allocation attribution is not claimed. The cumulative
`ProcessInfo.maxRss` high-water field is not used as a per-scenario peak.

Representative clean-local medians/maximum sampled deltas are below. Values are
CPU seconds, CPU utilization, and maximum sampled RSS delta in MiB; host process
sampling is inherently macOS- and workload-sensitive.

| Scenario | Dart IO | libcurl | Rust |
| --- | --- | --- | --- |
| 100 concurrent | 0.03 s / 159.5% / +9.05 | 0.05 s / 218.8% / +13.91 | 0.05 s / 237.6% / +14.80 |
| 250 concurrent | 0.04 s / 142.1% / +4.00 | 0.09 s / 230.9% / +7.00 | 0.10 s / 251.3% / +5.83 |
| 100 MB direct download | 1.225 s / 135.4% / +67.16 | 1.660 s / 172.1% / +4.64 | 1.695 s / 183.4% / +6.22 |
| 100 MB Dart-stream-to-file | 2.52 s / 116.6% / +271.03 | 4.145 s / 154.2% / +41.23 | 4.21 s / 160.1% / +35.11 |
| 100 MB upload | 0.35 s / 119.4% / +8.03 | 0.38 s / 138.2% / +61.58 | 1.205 s / 262.9% / +2.23 |
| slow stream | 0.10 s / 63.8% / +7.73 | 0.12 s / 85.3% / +7.22 | 0.13 s / 90.1% / +6.51 |
| paused stream | 0.10 s / 13.7% / +6.45 | 0.15 s / 20.7% / +9.80 | 0.15 s / 20.8% / +7.51 |

The large Dart RSS delta for the Dart-stream-to-file path is consistent with
that architecture's Dart-managed buffering and should not be compared with a
native direct-file path as though both had the same copy boundary. The direct
download result is useful as a systems-path observation, but it is not a pure
transport comparison.

## 9. Direct-file and upload paths

The benchmark reports two distinct architectures:

```text
Dart-managed:  network -> transport -> FFI/Dart stream -> file
Native direct: network -> native transport -> file
```

For uploads the corresponding paths are Dart file stream to network versus file
to native transport to network. No path is described as zero-copy; the native
path is called direct native-to-file or minimal-copy.

Clean-local 100 MB p50 wall times were:

| Path / scenario | Dart IO | libcurl | Rust |
| --- | ---: | ---: | ---: |
| direct download scenario | 896.946 ms* | 964.254 ms | 921.626 ms |
| all-candidates Dart-stream-to-file | 2,163.181 ms | 2,689.117 ms | 2,632.687 ms |
| upload | 289.435 ms | 272.314 ms | 456.761 ms |

\* Dart's “direct download” is still `network_to_dart_stream_to_file`; only
libcurl and Rust use `network_to_native_to_file` in that scenario. The
all-candidates stream-to-file scenario is the fairer copy-path comparison. The
native direct-path result is a separate potential AlphaX capability, not proof
that the native transport is faster for every API operation.

All 100 MB download hashes and upload byte-count/FNV-1a 64 checks passed. The
deterministic payload hash is `5db029fd007b7ea5` for the 100 MB fixture.

## 10. Binary-size accounting

The macOS measurement uses stripped release Dart AOT benchmark executables and
stripped native shared libraries. Dynamic dependencies are listed separately;
system libraries are not counted as bundled bytes. The application-artifact
delta is explicitly a benchmark-harness delta, not a production application
delta.

| Candidate | Stripped application artifact | Harness delta vs Dart baseline | Stripped native library | Important dependencies |
| --- | ---: | ---: | ---: | --- |
| Dart baseline | 6,441,368 B | baseline | none | macOS system frameworks |
| libcurl | 5,929,496 B | -511,872 B | 54,360 B | system `libcurl.4.dylib`, libSystem |
| Rust | 5,912,976 B | -528,392 B | 3,739,536 B | libiconv, libSystem; Rust TLS/HTTP stack in dylib |

The native bridge alone is not the libcurl deployable cost: this run uses the
system-provided macOS libcurl. A future bundled libcurl build would need a
complete accounting for libcurl, TLS backend, HTTP/2/nghttp2, compression, and
their ABI/runtime dependencies. Rust currently carries a multi-megabyte native
library in this configuration. Neither result is extrapolated to Android arm64,
iOS arm64, Linux, or Windows. Those release artifacts were not built in this
round because the required native target toolchains were not installed.

The artifact raw record is
[`binary-size-macos-round4-...json`](../raw/binary-size-macos-round4-3a141600757f7cc89c5b4fe40a010119de2f9cee-dirty.json).

## 11. Engineering and maintenance comparison

The prototype evidence, rather than language preference, informs this table.
LOC is included only as a rough scope indicator, not a quality score: the
libcurl native file is about 1,515 lines, the Rust native library about 853
lines, and the Dart FFI bindings are about 1,026 and 925 lines respectively.

| Dimension | Dart IO | libcurl FFI | Rust FFI |
| --- | --- | --- | --- |
| Native code | none | C worker, callbacks, queue, multi lifecycle | Rust async runtime, FFI ABI, stream/file paths |
| FFI complexity | none | high; pointer ownership and callback lifetime | high; ABI ownership plus async runtime boundary |
| Memory-safety burden | Dart/runtime managed | highest manual C ownership burden | lower native memory-safety risk, but unsafe ABI boundary remains |
| Build complexity | Dart SDK/platform runtime | system or bundled libcurl/TLS/HTTP2 variants | Rust toolchain, target builds, TLS/runtime packaging |
| CI complexity | lowest | native headers/libs and ABI matrix | Rust target/toolchain and linker matrix |
| Binary dependencies | runtime-provided | system libcurl in this macOS run; bundled path unresolved | multi-megabyte Rust/TLS native payload in this run |
| HTTP/2 | not negotiated by prototype | verified with nghttp2-backed libcurl | verified with reqwest/rustls/h2 path |
| HTTP/3 path | runtime-dependent, not tested | libcurl build/backend dependent | not enabled in this prototype |
| TLS control | runtime API | extensive libcurl/backend controls | rustls configuration control |
| Streaming control | straightforward Dart stream | strongest explicit pause/credit control, highest C complexity | bounded async stream with one extra bounded upstream chunk |
| Direct file I/O | Dart stream/file path | native direct path exists | native direct path exists |
| Debugging | ordinary Dart tooling | native callback/FFI/lifetime debugging | async runtime plus FFI debugging |
| Security updates | SDK/runtime cadence | libcurl and TLS backend cadence | Rust crates, rustls, and toolchain cadence |
| Contributor accessibility | broadest | C/FFI specialists needed | Rust/FFI specialists needed |

Candidate-specific assessment:

### Dart IO

Strengths are the smallest architecture, lowest build/CI cost, no FFI ownership
boundary, and strong local performance. The clean local run was fastest for
250-concurrency and the common Dart-stream-to-file path, while 100 MB direct
download and most slow/paused stream results were close enough that transport
differences were not universally decisive. Its weakness in this prototype is
that it did not negotiate HTTP/2 and it does not provide the same native direct
file path. Its platform behavior depends on the Dart/Flutter runtime rather than
AlphaX owning every protocol feature.

### libcurl FFI

Strengths are mature protocol/TLS integration, explicit multi-handle control,
verified sequential reuse after the refactor, native direct-file support, and
the smallest measured native bridge. It performed competitively on local upload
and native HTTP/2 workloads. Weaknesses are the highest manual C ownership and
callback complexity, dependence on the actual libcurl/TLS/HTTP2 packaging, and
the need to resolve the bundled dependency cost on every target. The former
upload anomaly was an integration/server-handshake issue and is fixed for the
benchmark, not an inherent libcurl penalty.

### Rust reqwest/hyper FFI

Strengths are memory-safe native implementation structure, verified HTTP/2 and
connection multiplexing, a strong async ecosystem, and native direct-file
support. It was close to libcurl for local and HTTP/2 downloads/streams and kept
one HTTP/2 connection in the 250-concurrency case. Weaknesses are the largest
measured native artifact, Rust runtime/toolchain/CI packaging, async/FFI
ownership complexity, and higher CPU in several local resource measurements.
Feature stripping, LTO, panic configuration, and TLS choices may change the
size, but those configurations were not yet measured as deployable cross-platform
artifacts.

## 12. Decision matrix

| Criterion | Dart IO | libcurl FFI | Rust FFI |
| --- | --- | --- | --- |
| Correctness in tested contract | pass | pass | pass |
| Sequential connection reuse | verified, 1/100 | verified, 1/100 after refactor | verified, 1/100 |
| Bounded FFI streaming | not applicable; Dart stream | pass, 256 KiB observed bound | pass, 320 KiB observed bound |
| Local latency | strongest overall local baseline | often close; wins some uploads | often close; wins some h2/downloads |
| Local CPU/RSS | generally lowest CPU; path-sensitive RSS | higher CPU; native direct path low RSS | highest CPU in several probes; low direct-path RSS |
| HTTP/1.1 TLS | verified | verified | verified |
| HTTP/2 | unsupported/not-tested in prototype | verified | verified |
| Direct native file path | unavailable | available | available |
| macOS native incremental cost | none beyond runtime | 54 KiB bridge plus system libcurl | 3.74 MiB native dylib |
| Cross-platform packaging evidence | runtime-dependent | incomplete bundled-stack evidence | incomplete target artifacts |
| Maintenance/build burden | lowest | highest C/ABI burden | high Rust/ABI burden |
| Evidence sufficient for final choice | no | no | no |

No hybrid is justified by this dataset. Different candidates win individual
microbenchmarks, but the practical benefit of shipping multiple transports has
not been shown to outweigh binary size, platform divergence, testing, debugging,
and security-update costs.

## Remaining limitations and gate status

| Gate | Status | Consequence |
| --- | --- | --- |
| libcurl upload anomaly explained | complete | `Expect: 100-continue` interaction identified and corrected |
| timing boundaries confirmed | complete for benchmark contract | per-phase TLS boundaries remain asymmetric |
| persistent libcurl reuse | complete for sequential HTTP/1.1 | concurrency connection limits still require target-specific policy |
| bounded backpressure | complete for prototype baseline | Rust has one extra bounded upstream chunk |
| HTTP/2 verification | partial | native candidates verified; Dart does not negotiate h2 |
| CPU metrics | available at process level | component attribution unavailable |
| RSS metrics | available at sampled process level | host/process sampling limits precision |
| network impairment | unavailable | no mobile-network conclusion |
| deployable binary sizes | partial macOS only | Linux/Android/iOS packaging gate remains |
| Nitro reference | not integrated | no fair maintained comparable client was available |
| Dio reference | not rerun in Round 4 | remains an ecosystem reference only |

## Phase 0 exit decision

**INSUFFICIENT EVIDENCE** is the Round 4 result. This is a completed decision
gate, not permission for an indefinite broad benchmark program. The next action
should be limited to the smallest experiment described in the executive result:
one controlled Linux environment that provides the same trusted h2 fixture and
reproducible `tc`/`netem` profiles, followed by the explicitly accounted release
artifacts for the priority targets if the network result remains close.

After review of this report, maintainer approval is required before creating
`docs/decisions/0004-primary-native-transport.md`. Until then, AlphaX remains
transport-independent, no production transport is selected, and Phase 1 does
not begin.
