#!/usr/bin/env bash
set -euo pipefail

for package in packages/*; do
  echo "Testing ${package}"
  (
    cd "${package}"
    if rg -q '^\s+sdk:\s+flutter\s*$' pubspec.yaml; then
      flutter test
    else
      dart test
    fi
  )
done
