#!/usr/bin/env bash
set -euo pipefail

for package in packages/*; do
  echo "Testing ${package}"
  (cd "${package}" && dart test)
done
