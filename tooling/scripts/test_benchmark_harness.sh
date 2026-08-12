#!/usr/bin/env bash
set -euo pipefail

for package in benchmarks/server benchmarks/runner; do
  echo "Testing ${package}"
  (
    cd "${package}"
    dart pub get
    dart format --set-exit-if-changed .
    dart analyze
    dart test
  )
done
