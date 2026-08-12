#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
  curl_library="prototypes/libcurl_ffi/libalphax_curl.dylib"
  rust_library="prototypes/rust_http/target/release/libalphax_rust_http.dylib"
else
  curl_library="prototypes/libcurl_ffi/libalphax_curl.so"
  rust_library="prototypes/rust_http/target/release/libalphax_rust_http.so"
fi

make -C prototypes/libcurl_ffi
cargo build --release --manifest-path prototypes/rust_http/Cargo.toml

ALPHAX_CURL_LIBRARY="${ALPHAX_CURL_LIBRARY:-${PWD}/${curl_library}}" \
ALPHAX_RUST_LIBRARY="${ALPHAX_RUST_LIBRARY:-${PWD}/${rust_library}}" \
  dart run benchmarks/runner/bin/run_benchmarks.dart \
  --warmup "${ALPHAX_BENCHMARK_WARMUP:-3}" \
  --iterations "${ALPHAX_BENCHMARK_ITERATIONS:-10}" \
  --output "${ALPHAX_BENCHMARK_OUTPUT:-benchmarks/results}"
