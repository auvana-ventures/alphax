# AlphaX Phase 0 macOS Round 3 Transport Evaluation

Status: preliminary transport research. No production transport is selected,
no C++ engine is introduced, and Phase 1 has not started.

## 1. Scope and provenance

Round 3 compares the benchmark candidates only:

- `dart:io` / `HttpClient` (`dart_io`)
- libcurl through the minimal C ABI and Dart FFI (`libcurl_ffi`)
- Rust reqwest/hyper through the C ABI and Dart FFI (`rust_reqwest_ffi`)

The base source commit is `be95b6b52175deb9c38da5f0741c9d9ae0f67378`
(`be95b6b`, the pushed Round 2 investigation). The Round 3 result files are
marked dirty because the benchmark and prototype changes were intentionally
measured before a Round 3 commit. Round 1 and Round 2 files remain separate and
were not rewritten.

Environment:

| Field | Value |
| --- | --- |
| OS | macOS Version 26.5.2 (Build 25F84) |
| CPU / architecture | Apple M4 / arm64 |
| Dart | 3.12.2 |
| Flutter | 3.44.6 stable |
| libcurl | 8.7.1, SecureTransport, nghttp2 1.68.1 |
| Rust | 1.97.1 |
| reqwest / hyper | reqwest 0.12.28 / hyper 1.11.0 |
| Dio reference | 5.11.0 |
| Profile | localhost; no impairment |
| Warmup / measured | 3 / 30 for decision-sensitive runs |
| Protocol | HTTP/1.1-compatible local server; negotiated protocol recorded |

Primary raw and generated summaries:

- [Round 3 key raw samples](../raw/macos-round3-key-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.json)
- [Round 3 key summary JSON](macos-round3-key-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.json)
- [Round 3 key generated summary](macos-round3-key-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.md)
- [Cancellation raw samples](../raw/macos-round3-cancellation-final-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.json)
- [Dedicated connection raw samples](../raw/macos-round3-connections-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.json)
- [Dio reference raw samples](../raw/macos-round3-dio-reference-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.json)
- [Round 3 binary-size measurement](../raw/binary-size-macos-round3-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty.json)

The five corrected batching runs are retained as
`macos-round3-batching-corrected-*` in the same raw and summaries directories.
The earlier pre-correction Rust batching runs are retained as
`macos-round3-batching-*`; they are historical evidence of the discovered
fairness defect, not current comparative results.

The key transfer/concurrency file was collected before the Rust batching fix;
its default 64 KiB setting is retained for provenance, while the corrected
stream-only run and the corrected batching matrix are authoritative for
batching and slow-consumer comparisons. No historical result was rewritten.

## 2. Decision gate

| Round 3 requirement | State | Evidence / limitation |
| --- | --- | --- |
| Bounded native streaming | Complete for the prototype | Credit/ack window passes correctness and bounded slow-consumer runs. |
| Connection behavior | Understood for current prototypes | Dart and Rust reuse; libcurl currently opens one connection per independent multi handle. Server close events are unavailable through Dart's HTTP server API. |
| HTTP/2 | Not comparable in this round | No shared TLS/ALPN HTTP/2 server and protocol configuration was available for all candidates. No run is mislabeled HTTP/2. |
| Realistic network profiles | Not measured | `dnctl`/`pfctl` are present, but non-interactive administrator access and `/dev/pf` were unavailable. |
| CPU and RSS | Process-level measurements available | Current RSS and CPU deltas are recorded. Per-scenario peak RSS is not treated as reliable because the macOS high-water value is cumulative and can be inherited by isolated children. |
| Direct native file paths | Complete for local profile | Counts and FNV-1a64 hashes validate 10 MB and 100 MB transfers. |
| External reference | Dio partial; Nitro unavailable | Dio ran a scoped fair reference. The available Dart Nitro package is a native binding runtime, not a comparable HTTP client. |
| 30-sample key scenarios | Complete | Raw samples retain all 30 measured iterations after warmup. |

The evidence is therefore not sufficient to choose A, B, C, or D. A transport
decision remains deferred.

## 3. Bounded FFI backpressure architecture

Both native candidates now use the benchmark-only flow boundary:

```text
network -> native bounded credit window -> FFI notification -> Dart copy
        -> Dart Stream consumer -> acknowledgement -> native resume
```

The default experiment is four 64 KiB credits, or a 262,144-byte native flow
window. Native code waits when credits are exhausted; cancellation wakes that
wait and the underlying event loop. Dart copies each native-owned callback
buffer before releasing it and acknowledges it after the stream consumer
resumes. The flow settings are not a public AlphaX API or a production default.

At the default setting, the corrected 2 MiB slow-consumer run measured:

| Candidate | p50 total | p95 total | FFI notifications | Max native flow bytes | Max Dart pending bytes | Pauses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `dart_io` | 268.4 ms | 333.9 ms | n/a | n/a | n/a | subscription pause controls reads |
| `libcurl_ffi` | 207.9 ms | 257.2 ms | 32 | 262,144 | 196,608 | 28 |
| `rust_reqwest_ffi` | 203.5 ms | 241.9 ms | 32 | 262,144 | 196,608 | 28 |

All three candidates completed the full transfer in the corrected stream run.
The native terminal result can show four outstanding credits because completion
can race with Dart draining already delivered events; this is recorded and the
native handle is still cleaned up safely.

The dedicated paused-cancellation run added 30 samples per candidate. Every
candidate received the first chunk, cancelled while the consumer was paused,
reported `cancelled` in all 30 samples, and passed the post-cancellation
resource probe in all 30 samples. Cancellation-latency p50/p95 were:

| Candidate | p50 | p95 |
| --- | ---: | ---: |
| `dart_io` | 0.36 ms | 1.38 ms |
| `libcurl_ffi` | 1.60 ms | 32.65 ms |
| `rust_reqwest_ffi` | 2.59 ms | 32.01 ms |

The native pause/resume values are diagnostic, not a claim of equivalent
application scheduling. The important correctness property is bounded memory
and cancellation while the producer is blocked.

## 4. FFI batching results

The initial sweep found that Rust was splitting each reqwest source chunk rather
than aggregating across source chunks. That made 128 KiB and 256 KiB settings
semantically different from libcurl. Rust was corrected to accumulate across
upstream chunks, then the matrix was rerun. The corrected 2 MiB slow-consumer
matrix is:

| Target | Candidate | p50 | Mean | Notifications | Max native flow | Max Dart pending |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 16 KiB | libcurl | 642.4 ms | 649.0 ms | 128 | 65,536 | 49,152 |
| 16 KiB | Rust | 644.6 ms | 666.1 ms | 128 | 65,536 | 49,152 |
| 32 KiB | libcurl | 324.4 ms | 323.9 ms | 64 | 131,072 | 98,304 |
| 32 KiB | Rust | 322.0 ms | 335.2 ms | 64 | 131,072 | 98,304 |
| 64 KiB | libcurl | 194.1 ms | 205.8 ms | 32 | 262,144 | 196,608 |
| 64 KiB | Rust | 192.2 ms | 194.3 ms | 32 | 262,144 | 196,608 |
| 128 KiB | libcurl | 137.0 ms | 137.8 ms | 16 | 524,288 | 393,216 |
| 128 KiB | Rust | 165.9 ms | 172.5 ms | 16 | 524,288 | 393,216 |
| 256 KiB | libcurl | 131.2 ms | 137.7 ms | 8 | 1,048,576 | 786,432 |
| 256 KiB | Rust | 141.1 ms | 145.6 ms | 8 | 1,048,576 | 786,432 |

Larger batches reduce FFI notifications and usually improve this local
slow-consumer workload, but they enlarge the bounded memory window and increase
pause responsiveness costs. No production batch size is selected.

## 5. Upload anomaly and timing boundaries

The Round 2 libcurl upload result was not an inherent fixed transfer cost. The
local Dart server did not send an interim `100 Continue`; libcurl therefore
waited for its `Expect: 100-continue` behavior before sending the body. The
prototype now sends an explicit empty `Expect:` header for file uploads. This is
a correctness-preserving measurement correction, not arbitrary timeout tuning.

The Round 2 p50 values were approximately 1,011 ms for 10 MB and 1,073 ms for
100 MB. After the correction, the Round 3 libcurl p50 values are 57.4 ms and
520.6 ms. The size-dependent result and lifecycle timestamps reject the fixed
one-second hypothesis.

The corrected libcurl p50 lifecycle values are:

| Timestamp | 10 MB | 100 MB |
| --- | ---: | ---: |
| body preparation complete | 0.18 ms | 0.16 ms |
| first upload callback | 0.54 ms | 0.45 ms |
| first upload byte submitted | 0.60 ms | 0.50 ms |
| last upload byte submitted | 42.6 ms | 473.0 ms |
| server body read complete | 50.8 ms | 515.8 ms |
| response headers | 56.3 ms | 517.5 ms |
| response body / CURLMSG_DONE | 56.4 ms | 517.6 ms |
| native cleanup | 56.5 ms | 517.7 ms |
| Dart completion notification | 57.4 ms | 520.6 ms |

The measured upload boundary starts before file stat/preparation and ends after
response-body completion, native completion notification, and handle cleanup
notification. Connection establishment is included for every candidate. The
server validates byte count and deterministic FNV-1a64 hash only after consuming
the complete body.

For the 100 MB upload, the libcurl event loop p50 was 1,631 polls, 441.8 ms of
aggregate readiness wait, and 46.5 ms maximum single poll wait. No fixed one
second sleep or completion-polling delay was observed. The loop uses
`curl_multi_timeout` plus `curl_multi_poll`, and cancellation uses
`curl_multi_wakeup`.

## 6. Connection reuse and concurrency

The dedicated fresh-process sequential reuse run issued 100 sequential 1 KiB
requests per measured sample:

| Candidate | Mean distinct connections observed | Mean requests/connection | Observation |
| --- | ---: | ---: | --- |
| `dart_io` | 1.33 | 83.3 | one connection in most samples; two in some |
| `libcurl_ffi` | 100 | 1.0 | one independent connection per request |
| `rust_reqwest_ffi` | 1.0 | 100.0 | shared reqwest client reuses one connection |

The Dart server exposes remote-address/port-derived connection identifiers,
request counts, and cumulative connection establishment counts. Its API does
not expose socket-close callbacks, so close events remain explicitly
`unavailable`, not estimated.

The libcurl result is an integration-architecture finding: every request owns a
separate multi/easy pair. `CURLSH` shares DNS state in this prototype, but it does
not provide the shared connection pool needed for these independent multi
handles. Consequently, the libcurl 100/250-concurrency results are not evidence
that libcurl itself cannot reuse connections; they measure the current prototype
architecture. The Rust result uses one long-lived reqwest client and Tokio
runtime. This connection asymmetry is a material unresolved limitation for
transport selection.

The key local p50 latency results were:

| Scenario | `dart_io` | `libcurl_ffi` | `rust_reqwest_ffi` |
| --- | ---: | ---: | ---: |
| 100 concurrent 1 KiB requests | 42.5 ms | 64.2 ms | 58.8 ms |
| 250 concurrent 1 KiB requests | 63.5 ms | 141.1 ms | 103.3 ms |
| sequential reuse, 100 requests | 54.9 ms | 138.1 ms | 123.7 ms |

The runner classifies these three scenario comparisons as inconclusive under
the existing rule because the distributions and variability do not justify a
winner. The connection observation itself is clear; latency attribution is not.

## 7. Streaming and file-transfer results

All 10 MB and 100 MB download/upload samples validated exact byte counts and the
same deterministic FNV-1a64 hash. The two download paths are deliberately
separate:

- Dart: network -> Dart response stream -> Dart file sink.
- Native candidates: network -> native transport -> native file handle.

The key p50 totals were:

| Scenario | `dart_io` | `libcurl_ffi` | `rust_reqwest_ffi` |
| --- | ---: | ---: | ---: |
| 10 MB download scenario | 237.1 ms | 251.1 ms | 238.2 ms |
| 100 MB download scenario | 1,954.0 ms | 2,474.2 ms | 2,300.9 ms |
| 10 MB network -> Dart file | 420.8 ms | 705.7 ms | 704.3 ms |
| 100 MB network -> Dart file | 4,276.3 ms | 7,290.7 ms | 7,437.9 ms |
| 10 MB upload | 72.9 ms | 57.4 ms | 180.0 ms |
| 100 MB upload | 723.7 ms | 520.6 ms | 2,123.2 ms |

These are local-profile observations, not mobile-network predictions. The
stream-to-Dart-file comparison intentionally exposes the FFI copy and callback
cost; native direct-to-file is a different architecture and is not called
zero-copy.

Corrected default streaming p50/p95 values were:

| Scenario | Candidate | p50 | p95 | Classification |
| --- | --- | ---: | ---: | --- |
| 2 MiB fast stream | Dart | 119.5 ms | 198.5 ms | inconclusive overall |
| 2 MiB fast stream | libcurl | 143.1 ms | 217.9 ms | inconclusive overall |
| 2 MiB fast stream | Rust | 129.0 ms | 174.2 ms | inconclusive overall |
| 2 MiB slow consumer | Dart | 268.4 ms | 333.9 ms | inconclusive overall |
| 2 MiB slow consumer | libcurl | 207.9 ms | 257.2 ms | inconclusive overall |
| 2 MiB slow consumer | Rust | 203.5 ms | 241.9 ms | inconclusive overall |

The classification is intentionally not based on p50 ordering alone.

## 8. CPU, RSS, and memory interpretation

The runner records process CPU time, point-in-time CPU utilization, current RSS,
and the platform high-water value. Isolated candidate processes also record idle
baselines. Representative p50 CPU/RSS observations from the key run were:

| Scenario | Candidate | CPU time delta | CPU utilization | Current RSS after |
| --- | --- | ---: | ---: | ---: |
| 100 concurrent | Dart | 0.05 s | 103.8% | 300.8 MiB |
| 100 concurrent | libcurl | 0.09 s | 124.9% | 133.3 MiB |
| 100 concurrent | Rust | 0.07 s | 116.1% | 105.9 MiB |
| 100 MB direct download | Dart | 1.88 s | 96.4% | 306.2 MiB |
| 100 MB direct download | libcurl | 3.03 s | 121.4% | 133.9 MiB |
| 100 MB direct download | Rust | 2.68 s | 115.8% | 113.1 MiB |
| 100 MB Dart-file path | Dart | 3.67 s | 85.9% | 206.3 MiB |
| 100 MB Dart-file path | libcurl | 6.39 s | 87.1% | 137.7 MiB |
| 100 MB Dart-file path | Rust | 6.52 s | 86.8% | 123.4 MiB |
| 100 MB upload | Dart | 0.45 s | 61.3% | 170.3 MiB |
| 100 MB upload | libcurl | 0.52 s | 100.1% | 112.7 MiB |
| 100 MB upload | Rust | 1.64 s | 76.8% | 109.7 MiB |

Current RSS is the more defensible comparative signal in this harness. The
macOS high-water value is cumulative, and the Dart child-process launch model
can make it non-attributable to one scenario; it is retained in raw results but
not presented as a scenario peak. Component-level Dart heap versus native
allocation was not measured reliably. The flow-window and Dart-pending-byte
measurements are reliable architecture-specific bounds for the streaming
experiments.

## 9. Binary-size accounting

The deployable-artifact script builds release Dart executables and strips native
shared libraries. It reports application artifacts, native payloads, and dynamic
dependencies separately. The macOS arm64 observations are:

| Artifact | Stripped bytes | Accounting |
| --- | ---: | --- |
| Dart baseline application | 6,441,368 | release Dart executable |
| libcurl application harness | 5,929,496 | not a production-app delta |
| libcurl native payload | 54,168 | dynamically linked to macOS `/usr/lib/libcurl.4.dylib` |
| Rust application harness | 5,912,976 | not a production-app delta |
| Rust native payload | 3,722,976 | includes Rust/reqwest/rustls payload in the dylib |

The negative application deltas are a harness-entrypoint artifact and must not
be used as a production size claim. The meaningful Round 3 observation is that
the native libcurl wrapper is small but depends on a system libcurl, while the
Rust candidate has a multi-megabyte native payload and a system `libiconv`
dependency on this macOS build. The script does not count system libraries as
bundled bytes.

No Android, iOS, Windows, Linux, or alternate-ABI artifact was built in Round 3.
System-provided dependency availability, stripping, licensing, and security
update obligations must be evaluated per target before any transport decision.

## 10. HTTP/2 status

No HTTP/2 performance result is included. This is deliberate:

- the deterministic Dart benchmark server currently provides an
  HTTP/1.1-compatible profile;
- no shared local TLS/ALPN HTTP/2 server was available in the repository harness;
- libcurl and Rust were not switched to an explicitly negotiated HTTP/2 profile;
- Dart IO was not given a verified equivalent HTTP/2 configuration;
- a fallback to HTTP/1.1 would make an HTTP/2-labelled comparison invalid.

The current local result metadata records HTTP/1.1: the raw libcurl enum `2`
maps to `CURL_HTTP_VERSION_1_1`, and Rust reports protocol code `11` for
HTTP/1.1. The prototypes now expose human-readable protocol names alongside
raw codes so a future HTTPS/ALPN run can reject silent fallback. HTTP/2 remains
Round 4 evidence, not an implied result of the enabled Rust `http2` feature or
the installed libcurl nghttp2 support.

## 11. Network profiles

`benchmarks/scripts/network-profile.sh` documents these explicit macOS profiles:

| Profile | Delay model | Bandwidth | Loss |
| --- | --- | ---: | ---: |
| local | none | unrestricted | 0% |
| good-network | 30 ms one-way, approximately 60 ms RTT | 100 Mbps | 0% |
| typical-mobile | 50 ms one-way, approximately 100 ms RTT | 10 Mbps | 0.5% |
| poor-mobile | 150 ms one-way, approximately 300 ms RTT | 1 Mbps | 2% |

The helper requires explicit `apply` and `reset`, scopes rules to the benchmark
TCP port, and never changes networking automatically. In this environment,
`dnctl` and `pfctl` were present, but non-interactive `sudo` was unavailable and
`/dev/pf` was inaccessible. No impairment was applied and no network-dominated
conclusion is made. Round 4 should run each profile on a controlled host and
retain the exact apply/reset transcript.

## 12. External references

### Dio

Dio 5.11.0 using its normal/default adapter passed all 10 correctness checks.
The scoped 30-sample p50 results were 53.2 ms for 100 concurrency, 56.4 ms for
100 sequential 1 KiB requests, 190.1 ms for a 10 MB download, 55.3 ms for a
10 MB upload, 109.0 ms for the 2 MiB fast stream, and 237.5 ms for the slow
consumer. The [Dio raw result](../raw/macos-round3-dio-reference-be95b6b52175deb9c38da5f0741c9d9ae0f67378-dirty-chunk65536-window4-network-local.json)
is a reference only; it does not expand AlphaX's candidate set.

### Nitro HTTP

An exact Dart/Flutter Nitro HTTP client could not be identified for a fair
comparison. The available Dart `nitro` package is a native binding/runtime
tooling package, not a transport implementation that can be placed behind this
benchmark contract. No Nitro result is fabricated, and no AlphaX code was
tailored to another project's implementation.

## 13. Candidate assessment

### Dart IO / HttpClient

Strengths:

- simplest and most mature baseline for this repository;
- clear server-observed reuse in the dedicated sequential run;
- fastest local `download_*` scenario and Dart-stream-to-file path in this dataset;
- no native ABI, native allocator, or per-platform native library packaging.

Weaknesses and implications:

- cannot exercise the native direct-to-file path;
- Dart-managed file and response-stream paths have different memory/copy costs;
- current process RSS is higher than the native candidates in this harness, but
  the measurement is process-level and VM-dependent;
- HTTP/2 was not verified in the shared candidate contract.

### libcurl / C ABI / Dart FFI

Strengths:

- corrected upload path is the fastest local 10 MB and 100 MB upload candidate;
- direct native-to-file download path is available and hash-validated;
- bounded callback batching reduces FFI notifications predictably;
- event-loop instrumentation shows readiness polling rather than a fixed
  one-second completion delay;
- current native process RSS is comparatively low in direct-file scenarios.

Weaknesses and implications:

- current per-request multi/easy design does not reuse connections across the
  100 sequential requests and inflates concurrency latency;
- a production-quality shared multi/socket loop is still unimplemented;
- macOS relies on a system libcurl, while other targets may require bundling or
  another system integration;
- C ownership, callback lifetime, locking, and cancellation paths remain
  substantial maintenance-sensitive code;
- HTTP/2 cannot be assessed until the shared connection architecture and fair
  negotiated server profile exist.

### Rust reqwest/hyper / C ABI / Dart FFI

Strengths:

- shared reqwest client reuses one observed connection in the dedicated run;
- Tokio runtime and reqwest provide a coherent async foundation;
- bounded flow and corrected cross-source batching now match libcurl's target
  semantics;
- direct native-to-file paths are available and hash-validated;
- the dependency graph includes HTTP/2 capability for a future negotiated test.

Weaknesses and implications:

- 100 MB upload p50 and variance were materially worse than Dart/libcurl in the
  current local workload;
- the native release payload is approximately 3.7 MiB on macOS arm64 before
  per-platform packaging analysis;
- Rust runtime, unsafe C ABI ownership, Cargo, cross-compilation, and CI add
  build/debugging complexity;
- paused cancellation p95 was tens of milliseconds in some samples and needs
  broader investigation before treating it as production-quality behavior;
- enabled protocol features are not evidence until negotiation is observed.

### Why this does not justify a hybrid

Different candidates lead different local scenarios, but the practical
connection-pool asymmetry, missing HTTP/2/network evidence, process-level memory
limits, and cross-platform packaging gaps outweigh any argument for a hybrid
strategy at this stage. A hybrid is not recommended merely because candidates
win different microbenchmarks.

## 14. Remaining uncertainties and Round 4 needs

Round 4 would need to answer, at minimum:

1. implement a fair client-owned libcurl multi/socket loop and repeat connection
   reuse plus 100/250 concurrency;
2. provide a local TLS/ALPN HTTP/2 server with explicit negotiation checks for
   every candidate that participates;
3. run and retain good-network, typical-mobile, and poor-mobile profiles on a
   host where shaping can be applied and reset safely;
4. add reliable per-scenario process peak sampling or mark peak memory
   unavailable, rather than relying on cumulative macOS high-water values;
5. repeat 100 MB upload/download and paused-cancellation runs after any event
   loop or pooling redesign;
6. measure Android arm64, iOS arm64, Linux, and Windows release packaging and
   dependency obligations;
7. assess maintainability, security-update burden, and CI complexity with the
   native implementations stabilized.

Until that evidence exists, the correct outcome is **insufficient evidence for
transport selection**. Stop here for maintainer review. Do not accept the
primary transport ADR and do not begin Phase 1.
