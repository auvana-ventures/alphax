#!/usr/bin/env bash
set -euo pipefail

port="${ALPHAX_BENCHMARK_PORT:-8080}"
server_log="$(mktemp)"
server_pid=""
cleanup() {
  if [[ -n "${server_pid}" ]]; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi
  rm -f "${server_log}"
}
trap cleanup EXIT

dart run benchmarks/server/server.dart --port "${port}" >"${server_log}" 2>&1 &
server_pid=$!
for _ in {1..50}; do
  if curl --silent --fail "http://127.0.0.1:${port}/headers" >/dev/null; then
    break
  fi
  sleep 0.1
done

base_url="http://127.0.0.1:${port}/bytes/1024"
dart run prototypes/dart_io/bin/benchmark.dart --url "${base_url}" --requests 10 --concurrency 4
cargo run --manifest-path prototypes/rust_http/Cargo.toml -- --url "${base_url}" --requests 10 --concurrency 4

if [[ "$(uname -s)" == "Darwin" ]]; then
  library="prototypes/libcurl_ffi/libalphax_curl.dylib"
else
  library="prototypes/libcurl_ffi/libalphax_curl.so"
fi
make -C prototypes/libcurl_ffi
ALPHAX_CURL_LIBRARY="${library}" dart run prototypes/libcurl_ffi/bin/benchmark.dart \
  --url "${base_url}" --requests 10 --concurrency 4
