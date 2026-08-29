#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
package_dir=$(cd "$script_dir/.." && pwd)
test_dir="$package_dir/ios/Tests"
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/alphax-apple-correctness.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT

swiftc_path=$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc

"$swiftc_path" \
  "$package_dir/ios/Classes/AlphaXURLSessionTiming.swift" \
  "$package_dir/ios/Classes/AlphaXURLSessionBackpressure.swift" \
  "$package_dir/ios/Classes/AlphaXURLSessionFileFinalizer.swift" \
  "$test_dir/AlphaXURLSessionCorrectnessTests.swift" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -o "$build_dir/alphax-apple-urlsession-correctness-tests"

"$build_dir/alphax-apple-urlsession-correctness-tests"
