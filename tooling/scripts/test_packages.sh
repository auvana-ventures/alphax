#!/usr/bin/env bash
set -euo pipefail

for package in packages/*; do
  echo "Testing ${package}"
  (
    cd "${package}"
    if grep -Eq '^[[:space:]]+sdk:[[:space:]]+flutter[[:space:]]*$' pubspec.yaml; then
      flutter test
    else
      dart test
    fi
  )
done
