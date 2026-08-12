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
The upload endpoint returns the received count, an `ok` flag, and an
`x-alphax-uploaded-bytes` header; a mismatched `expected` count returns 400.

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
`CURLSH`, and Rust uses a shared reqwest client backed by a long-lived Tokio
runtime. Numeric connection reuse is still unavailable, so no reuse advantage is
claimed from warm samples alone.

By default, the runner starts a fresh deterministic server and a fresh child
process for each candidate, then merges only complete candidate documents. This
prevents one candidate's heap, socket, or native runtime state from contaminating
another candidate's measurements. Supplying `--base-url` opts into an externally
managed server for controlled experiments.

The default run uses three warmup iterations and ten measured iterations for every
scenario. Raw records retain every sample. Summaries include mean, p50, p95, and
standard deviation; p99 is reported only when a scenario has at least twenty
measured samples, otherwise it is explicitly unavailable.

Measure release artifact sizes separately:

```text
./benchmarks/scripts/measure-binary-size.sh
```

This reports a Dart AOT executable baseline and stripped native shared-library
artifact sizes. It does not compare raw build-directory sizes.

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
