#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
package_dir=$(cd "$script_dir/.." && pwd)
test_dir="$package_dir/ios/Tests"
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/alphax-apple-progress-interest.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT

swiftc_path=$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc

"$swiftc_path" \
  "$package_dir/ios/Classes/AlphaXProgressInterest.swift" \
  "$test_dir/AlphaXProgressInterestTests.swift" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -o "$build_dir/alphax-apple-progress-interest-tests"

"$build_dir/alphax-apple-progress-interest-tests"
