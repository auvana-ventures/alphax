#!/usr/bin/env bash
set -euo pipefail

for package in packages/alphax packages/alphax_native packages/alphax_dio packages/alphax_test; do
  echo "Validating ${package}"
  (cd "${package}" && dart pub publish --dry-run)
done
