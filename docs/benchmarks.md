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

## Scenarios

The full plan covers cold and warm latency, sequential and sustainable concurrent
requests, 1 KB/10 KB/100 KB payloads, JSON parsing separation, 10 MB/100 MB/1 GB
downloads and uploads where practical, streaming, cancellation, H1/H2/H3, and
network profiles from good to intermittent mobile-like conditions.

## Required metadata

Record elapsed time, DNS/connect/TLS/TTFB/transfer timings where available,
throughput, requests/sec, CPU, Dart/native/process memory, connections and reuse,
bytes, cancellation latency, binary-size delta, OS, device, CPU, architecture,
Dart/Flutter/build/library versions, and benchmark commit hash.

## Fairness

Use equivalent release/profile settings, warm/cold parity, identical parsing scope,
documented pooling/timeouts, and complete raw results. Do not cherry-pick favorable
scenarios. Performance claims in README/docs must link to scenarios, source, raw
results, and environment metadata.
