#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-benchmarks/results/raw/binary-size-local.json}"
temporary_directory="$(mktemp -d)"
cleanup() {
  rm -rf "${temporary_directory}"
}
trap cleanup EXIT

size_of() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

strip_copy() {
  local source="$1"
  local destination="$2"
  cp "$source" "$destination"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    strip -x "$destination"
  else
    strip --strip-unneeded "$destination"
  fi
}

dart compile exe prototypes/dart_io/bin/benchmark.dart -o "${temporary_directory}/dart-baseline"
make -C prototypes/libcurl_ffi
cargo build --release --manifest-path prototypes/rust_http/Cargo.toml

if [[ "$(uname -s)" == "Darwin" ]]; then
  curl_library="prototypes/libcurl_ffi/libalphax_curl.dylib"
  rust_library="prototypes/rust_http/target/release/libalphax_rust_http.dylib"
else
  curl_library="prototypes/libcurl_ffi/libalphax_curl.so"
  rust_library="prototypes/rust_http/target/release/libalphax_rust_http.so"
fi

strip_copy "${curl_library}" "${temporary_directory}/libalphax_curl"
strip_copy "${rust_library}" "${temporary_directory}/libalphax_rust_http"

mkdir -p "$(dirname "${output_path}")"
cat >"${output_path}" <<EOF
{
  "git_commit": "$(git rev-parse HEAD)",
  "os": "$(uname -s)",
  "architecture": "$(uname -m)",
  "methodology": "Dart AOT executable baseline and stripped native shared-library artifacts; build directories excluded",
  "dart_baseline_bytes": $(size_of "${temporary_directory}/dart-baseline"),
  "libcurl_candidate_bytes": $(size_of "${temporary_directory}/libalphax_curl"),
  "rust_candidate_bytes": $(size_of "${temporary_directory}/libalphax_rust_http")
}
EOF

echo "Binary-size result: ${output_path}"
