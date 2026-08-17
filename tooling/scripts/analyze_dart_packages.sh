#!/usr/bin/env bash
set -euo pipefail

# The repository contains independent Dart packages outside the root workspace
# (benchmarks and native prototypes). Analyze each package from its own root so
# its package_config.json resolves local package: imports on clean CI runners.
for package in packages/* benchmarks/client benchmarks/server benchmarks/runner; do
  echo "Analyzing ${package}"
  (
    cd "${package}"
    if grep -Eq '^[[:space:]]+sdk:[[:space:]]+flutter[[:space:]]*$' pubspec.yaml; then
      flutter pub get
      flutter analyze
    else
      dart pub get
      dart analyze
    fi
  )
done
