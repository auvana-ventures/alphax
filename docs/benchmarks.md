# Historical Phase 0 Benchmark Plan

Phase 0 research and transport validation is complete. The reports below are
historical evidence; the accepted 1.0 platform strategy is recorded in
[ADR-0004](decisions/0004-platform-native-mobile-transports.md). No result in
this document is a claim that the Phase 1A API or platform transports are already
implemented.

Phase 0 benchmarks answer whether a native transport provides a worthwhile overall
tradeoff for Dart and Flutter. They are not marketing material.

## Candidates

1. `dart:io` baseline.
2. libcurl multi through Dart FFI.
3. Rust reqwest/hyper prototype.

Compare against Dio and `package:http` only where an equivalent historical
benchmark exists. The Phase 0 benchmark suite is historical evidence for
HTTP/1.1 transport selection; production Android Cronet and Apple URLSession
validation is recorded in the Phase 1 reports and is not a new benchmark track.

## Server

Run the deterministic Dart server:

```text
dart run benchmarks/server/server.dart --port 8080
```

Endpoints include `/health`, `/bytes/{size}`, `/json/{size}`,
`/stream/{chunks}/{chunkSize}`, `/echo`, `/upload?expected={bytes}`,
`/delay/{milliseconds}`, `/status/{code}`, `/headers`, and `/redirect/{count}`.
The release-hardening redirect fixture additionally uses
`/redirect-cross-origin?to={absolute-uri}` and
`/redirect-target-headers` to inspect sensitive-header handling across two
origins.
The upload endpoint returns the received count, a deterministic FNV-1a 64 content
hash, an `ok` flag, and `x-alphax-uploaded-bytes` plus hash headers; a mismatched
`expected` count or `expected_hash` returns 400. The response is emitted only
after the complete request body has been consumed. It also exposes local
connection identifiers and request counts for reuse observations.

## Initial client smoke runs

```text
dart run prototypes/dart_io/bin/benchmark.dart --url http://127.0.0.1:8080/bytes/1024
cargo run --manifest-path prototypes/rust_http/Cargo.toml -- --url http://127.0.0.1:8080/bytes/1024
ALPHAX_CURL_LIBRARY=prototypes/libcurl_ffi/libalphax_curl.dylib \
  dart run prototypes/libcurl_ffi/bin/benchmark.dart \
  --url http://127.0.0.1:8080/bytes/1024
```

The libcurl library extension is `.so` on Linux.

## Reproducible local profile

Build both native release libraries, then run the benchmark package from the
repository root:

```text
make -C prototypes/libcurl_ffi
cargo build --release --manifest-path prototypes/rust_http/Cargo.toml
ALPHAX_CURL_LIBRARY="$PWD/prototypes/libcurl_ffi/libalphax_curl.dylib" \
ALPHAX_RUST_LIBRARY="$PWD/prototypes/rust_http/target/release/libalphax_rust_http.dylib" \
  dart run benchmarks/runner/bin/run_benchmarks.dart \
  --warmup 3 --iterations 30 --output benchmarks/results
```

Use `.so` paths on Linux. The runner starts an ephemeral deterministic server when
`--base-url` is omitted. It performs correctness checks first and does not collect
comparative performance samples for a candidate that fails. Raw output is stored in
`benchmarks/results/raw/`; machine-readable and Markdown summaries are stored in
`benchmarks/results/summaries/`.

The local profile includes 1 KB/10 KB/100 KB cold and warm-labelled request samples,
10/50/100/250-request concurrency, 10 MB/100 MB upload and download, streaming,
slow-consumer streaming, sequential connection reuse, separate JSON decode/parse
timings, and cancellation while waiting, streaming, downloading, and uploading.
Native candidates keep shared connection state where their prototype supports it:
libcurl Round 4 uses one persistent client-owned `CURLM` multi handle plus shared
DNS state, and Rust uses a shared reqwest client backed by a long-lived Tokio
runtime. Numeric connection reuse is reported from server observations rather than
inferred from warm latency. The historical Round 3 results retain the earlier
per-request libcurl multi limitation; Round 4 results must be identified by their
Round 4 report and commit hash.

By default, the runner starts a fresh deterministic server and a fresh child
process for each candidate, then merges only complete candidate documents. This
prevents one candidate's heap, socket, or native runtime state from contaminating
another candidate's measurements. Supplying `--base-url` opts into an externally
managed server for controlled experiments.

The default run uses three warmup iterations and ten measured iterations for every
scenario; decision-sensitive Round 3 runs use at least 30. Raw records retain
every sample. Summaries include mean, p50, p95, and
standard deviation; p99 is reported only when a scenario has at least twenty
measured samples, otherwise it is explicitly unavailable.

Round 2 supports `--only` with comma-separated scenario names so decision-sensitive
scenarios can be repeated without changing the full profile. Its summary also
reports min, mean, p50, p90, p95, max, and standard deviation. Scenario labels use
the following descriptive rule: approximately equivalent at <=5% p50 difference;
clear difference at >=20% separation with non-overlapping p25-p75 intervals and
<=10% coefficient of variation for both; likely difference at >=10% separation and
<=20% coefficient of variation; otherwise inconclusive. These labels are not a
synthetic overall score.

Upload timing starts before file length/stat preparation for every candidate and
ends after response-body completion plus the candidate completion notification.
Connection establishment is included. Raw upload records distinguish file
preparation, first/last submitted byte, server body-read duration, response
headers, response completion, native completion notification, and the Dart Future
boundary where the candidate exposes those timestamps.

For libcurl, `upload_bytes_read` is the number of bytes returned by the file-read
callback, while `upload_bytes_submitted` and the first/last submitted-byte
timestamps come from libcurl's transfer-progress counters. This keeps file
preparation and callback activity separate from bytes reported as sent by the
transport. FFI stream diagnostics retain the configured chunk target, credit-window
capacity, maximum native in-flight bytes, Dart pending bytes, notification count,
credit exhaustion, pause/resume latency, and cancellation/resource observations.
The native candidates use an experimental bounded credit/ack flow model; settings
are benchmark configuration, not a production AlphaX API or default.

The initial libcurl upload anomaly was traced to `Expect: 100-continue`: the local
Dart server does not send an interim 100 response, so libcurl waited its default
one-second expectation timeout before sending the body. The prototype now disables
that optional handshake for file uploads, which preserves the complete-body
contract and removes the fixed delay. This is a prototype measurement correction,
not evidence that libcurl is the production transport.

The five native batching targets can be compared reproducibly with:

```text
for size in 16384 32768 65536 131072 262144; do
  ALPHAX_CURL_LIBRARY="$PWD/prototypes/libcurl_ffi/libalphax_curl.dylib" \
  ALPHAX_RUST_LIBRARY="$PWD/prototypes/rust_http/target/release/libalphax_rust_http.dylib" \
    dart run benchmarks/runner/bin/run_benchmarks.dart \
    --stream-chunk-size "$size" --stream-window-chunks 4 \
    --warmup 3 --iterations 30 \
    --only stream_2097152_bytes,stream_2097152_bytes_slow_consumer \
    --output benchmarks/results
done
```

Direct native file-transfer samples are labelled
`network_to_native_to_file` and `file_to_native_to_network` for libcurl/Rust.
The explicit `download_stream_to_dart_file_*` scenarios label the
network-to-Dart-stream-to-file path. The runner validates deterministic download
hashes as well as upload counts and hashes.

The optional `--include-references` flag adds Dio 5.11.0 using its normal default
adapter. Dio is an ecosystem reference, not an AlphaX candidate. The available
Dart `nitro` package is a native binding runtime rather than an HTTP client, so a
maintained, comparable Nitro HTTP implementation was not available for this
Phase 0 harness and is reported as unavailable rather than benchmarked unfairly.

HTTP/2 is not silently labelled in any profile. The deterministic Dart TLS server
advertises only HTTP/1.1 through ALPN. Round 4 also provides an explicitly
separate Hypercorn/h2 Docker fixture under `benchmarks/server/http2/`; it pins
the server configuration, advertises only `h2`, and is used only after the
certificate and ALPN checks in that fixture's README pass. Each candidate's
response records the server-observed protocol, and a fallback to HTTP/1.1 is
unsupported/not-tested rather than an HTTP/2 measurement.

Network profiles are represented as `local`, `good-network`, `typical-mobile`,
and `poor-mobile` metadata. macOS packet impairment, when available and
explicitly run by a maintainer, is documented by
`benchmarks/scripts/network-profile.sh`; it uses `dnctl`/`pfctl`, scopes rules to
the benchmark TCP port, and requires an explicit `reset`. The benchmark runner
does not modify host networking automatically. A profile without applied
impairment must not be presented as a network simulation result. For a controlled
Linux environment, `benchmarks/scripts/network-profile-linux.sh` uses `tc` with
`tbf` and `netem` on an explicitly selected interface; it requires
`ALPHAX_NETEM_INTERFACE` and an explicit `reset`. The host used for this Round 4
run has no `tc`/`netem` toolchain, so no impaired-network result is claimed.

The deterministic TLS server is started with an ephemeral, benchmark-only CA and
server certificate generated by `benchmarks/scripts/create-local-tls.sh`. Clients
trust that CA through `ALPHAX_BENCHMARK_CA_CERT`; certificate verification remains
enabled and no permissive callback is used. The Dart server advertises only
`http/1.1`; the separate h2 fixture advertises only `h2`.

The first complete macOS local dataset is recorded at:

- [raw samples](../benchmarks/results/raw/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.json)
- [machine-readable summary](../benchmarks/results/summaries/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.json)
- [human-readable summary](../benchmarks/results/summaries/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.md)
- [binary-size measurement](../benchmarks/results/raw/binary-size-local.json)

It contains 630 raw samples: 21 scenarios × 10 measured iterations × 3
candidates. CPU utilization, Dart heap peak, native allocation peak, numeric
connection-reuse counts, and network-condition simulation were unavailable in
this profile and are not inferred from the recorded RSS or timing fields.

Round 2 retains the original dataset and writes a separate dirty-worktree run with
the commit hash and selected-scenario metadata in the result filename. Its
decision-sensitive profile uses at least 30 measured samples after warmup for
100/250 concurrency, 100 MB download, 10/100 MB upload, and slow-consumer
scenarios. Process CPU/RSS, server-observed connection identifiers, upload hashes,
native lifecycle timestamps, and variance classifications are reported separately;
they do not establish a production-transport decision.

The investigation report for the first Round 2 macOS profile is
[macos-local-round2-investigation.md](../benchmarks/results/summaries/macos-local-round2-investigation.md).

The Phase 0 Round 3 evaluation is recorded in
[macos-round3-transport-evaluation.md](../benchmarks/results/summaries/macos-round3-transport-evaluation.md).
It is preliminary research only: no production transport is selected and no
HTTP/2 or impaired-network result is claimed where negotiation or shaping was
unavailable.

Measure release artifact sizes separately:

```text
./benchmarks/scripts/measure-binary-size.sh
```

This reports stripped release application artifacts, AlphaX incremental application
size relative to the Dart baseline, bundled native-library size, and dynamic
dependency lists. System-provided libraries are disclosed but are not added to
bundled native-library bytes. These macOS measurements are not extrapolated to
Android, iOS, Linux, or Windows.

## Scenarios

The full plan covers cold and warm latency, sequential and sustainable concurrent
requests, 1 KB/10 KB/100 KB payloads, JSON parsing separation, 10 MB/100 MB/1 GB
downloads and uploads where practical, streaming, cancellation, H1/H2/H3, and
network profiles from good to intermittent mobile-like conditions.

## Required metadata

Record elapsed time, DNS/connect/TLS/TTFB/transfer timings where available,
throughput, requests/sec, CPU, Dart/native/process memory, connections and reuse,
bytes, cancellation latency, binary-size delta, OS, device, CPU, architecture,
Dart/Flutter/build/library versions, and benchmark commit hash. The runner sanitizes
machine-local Flutter paths before writing metadata.

## Fairness

Use equivalent release/profile settings, warm/cold parity, identical parsing scope,
documented pooling/timeouts, and complete raw results. Do not cherry-pick favorable
scenarios. Performance claims in README/docs must link to scenarios, source, raw
results, and environment metadata.
