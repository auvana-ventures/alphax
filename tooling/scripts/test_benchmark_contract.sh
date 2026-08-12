#!/usr/bin/env bash
set -euo pipefail

(cd benchmarks/client && dart pub get && dart test)
