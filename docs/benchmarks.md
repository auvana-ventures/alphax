# Benchmark Plan

Phase 0 benchmarks answer whether a native transport provides a worthwhile overall
tradeoff for Dart and Flutter. They are not marketing material.

## Candidates

1. `dart:io` baseline.
2. libcurl multi through Dart FFI.
3. Rust reqwest/hyper prototype.

Compare against Dio and `package:http` when their equivalent benchmark clients are
available. Cronet and URLSession are deferred platform experiments.

## Server

Run the deterministic Dart server:

```text
dart run benchmarks/server/server.dart --port 8080
```

Endpoints include `/health`, `/bytes/{size}`, `/json/{size}`,
`/stream/{chunks}/{chunkSize}`, `/echo`, `/upload?expected={bytes}`,
`/delay/{milliseconds}`, `/status/{code}`, `/headers`, and `/redirect/{count}`.
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
  --warmup 3 --iterations 10 --output benchmarks/results
```

Use `.so` paths on Linux. The runner starts an ephemeral deterministic server when
`--base-url` is omitted. It performs correctness checks first and does not collect
comparative performance samples for a candidate that fails. Raw output is stored in
`benchmarks/results/raw/`; machine-readable and Markdown summaries are stored in
`benchmarks/results/summaries/`.

The local profile includes 1 KB/10 KB/100 KB cold and warm-labelled request samples,
10/50/100/250-request concurrency, 10 MB/100 MB upload and download, streaming,
slow-consumer streaming, separate JSON decode/parse timings, and cancellation while
waiting, streaming, downloading, and uploading. Native candidates keep shared
connection state where their prototype supports it: libcurl uses a shared
DNS cache through `CURLSH` and keeps an independent connection pool per request
multi handle; Rust uses a shared reqwest client backed by a long-lived Tokio
runtime. The libcurl prototype does not share its connection pool across those
independent multi handles because that configuration crashed under 250-way
concurrency. Numeric connection reuse is therefore reported from server
observations rather than inferred from warm latency.

By default, the runner starts a fresh deterministic server and a fresh child
process for each candidate, then merges only complete candidate documents. This
prevents one candidate's heap, socket, or native runtime state from contaminating
another candidate's measurements. Supplying `--base-url` opts into an externally
managed server for controlled experiments.

The default run uses three warmup iterations and ten measured iterations for every
scenario. Raw records retain every sample. Summaries include mean, p50, p95, and
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
transport. FFI stream diagnostics also retain buffered bytes at native completion
before the Dart consumer drains the queue; the current FFI queues are reported as
unbounded prototype queues.

The initial libcurl upload anomaly was traced to `Expect: 100-continue`: the local
Dart server does not send an interim 100 response, so libcurl waited its default
one-second expectation timeout before sending the body. The prototype now disables
that optional handshake for file uploads, which preserves the complete-body
contract and removes the fixed delay. This is a prototype measurement correction,
not evidence that libcurl is the production transport.

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
