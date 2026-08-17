#!/usr/bin/env bash
set -euo pipefail

for package in packages/alphax packages/alphax_native packages/alphax_dio packages/alphax_test packages/alphax_web; do
  echo "Validating ${package}"
  (
    cd "${package}"
    if rg -q '^\s+sdk:\s+flutter\s*$' pubspec.yaml; then
      flutter pub publish --dry-run --ignore-warnings
    else
      dart pub publish --dry-run --ignore-warnings
    fi
  )
done
