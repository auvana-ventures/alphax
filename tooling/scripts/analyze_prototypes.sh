#!/usr/bin/env bash
set -euo pipefail

for prototype in prototypes/dart_io prototypes/libcurl_ffi prototypes/rust_http; do
  echo "Analyzing ${prototype}"
  (cd "${prototype}" && dart pub get && dart analyze)
done
