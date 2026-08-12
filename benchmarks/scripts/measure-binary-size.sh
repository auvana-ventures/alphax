#!/usr/bin/env bash
set -euo pipefail

output_path="${1:-benchmarks/results/raw/binary-size-local.json}"
temporary_directory="$(mktemp -d)"

size_of() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

strip_copy() {
  local source="$1"
  local destination="$2"
  cp "$source" "$destination"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    strip -x "$destination"
  else
    strip --strip-unneeded "$destination"
  fi
}

dependency_json() {
  local artifact="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    otool -L "$artifact" \
      | tail -n +2 \
      | sed 's/^[[:space:]]*//' \
      | awk '{ path=$1; sub(/^.*\//, "", path); $1=path; print }' \
      | jq -Rsc 'split("\n") | map(select(length > 0))'
  else
    ldd "$artifact" \
      | sed -E 's#([^[:space:]]*/)+([^[:space:]]+)#\2#g' \
      | jq -Rsc 'split("\n") | map(select(length > 0))'
  fi
}

description_json() {
  file "$1" | sed -E 's#^[^:]+: #artifact: #'
}

dart compile exe prototypes/dart_io/bin/benchmark.dart -o "${temporary_directory}/dart-baseline-app"
dart compile exe prototypes/libcurl_ffi/bin/benchmark.dart -o "${temporary_directory}/libcurl-app"
dart compile exe prototypes/rust_http/bin/ffi_benchmark.dart -o "${temporary_directory}/rust-app"
make -C prototypes/libcurl_ffi
cargo build --release --manifest-path prototypes/rust_http/Cargo.toml

if [[ "$(uname -s)" == "Darwin" ]]; then
  curl_library="prototypes/libcurl_ffi/libalphax_curl.dylib"
  rust_library="prototypes/rust_http/target/release/libalphax_rust_http.dylib"
else
  curl_library="prototypes/libcurl_ffi/libalphax_curl.so"
  rust_library="prototypes/rust_http/target/release/libalphax_rust_http.so"
fi

strip_copy "${temporary_directory}/dart-baseline-app" "${temporary_directory}/dart-baseline-app-stripped"
strip_copy "${temporary_directory}/libcurl-app" "${temporary_directory}/libcurl-app-stripped"
strip_copy "${temporary_directory}/rust-app" "${temporary_directory}/rust-app-stripped"
strip_copy "$curl_library" "${temporary_directory}/libalphax_curl-stripped"
strip_copy "$rust_library" "${temporary_directory}/libalphax_rust_http-stripped"

mkdir -p "$(dirname "$output_path")"
jq -n \
  --arg git_commit "$(git rev-parse HEAD)" \
  --argjson git_worktree_dirty "$(git status --porcelain | grep -q . && echo true || echo false)" \
  --arg os "$(uname -s)" \
  --arg architecture "$(uname -m)" \
  --arg dart_version "$(dart --version 2>&1)" \
  --arg curl_version "$(curl --version | head -n 1)" \
  --arg rust_version "$(rustc --version)" \
  --argjson dart_dependencies "$(dependency_json "${temporary_directory}/dart-baseline-app-stripped")" \
  --argjson libcurl_app_dependencies "$(dependency_json "${temporary_directory}/libcurl-app-stripped")" \
  --argjson rust_app_dependencies "$(dependency_json "${temporary_directory}/rust-app-stripped")" \
  --argjson libcurl_native_dependencies "$(dependency_json "${temporary_directory}/libalphax_curl-stripped")" \
  --argjson rust_native_dependencies "$(dependency_json "${temporary_directory}/libalphax_rust_http-stripped")" \
  --arg dart_description "$(description_json "${temporary_directory}/dart-baseline-app-stripped")" \
  --arg libcurl_app_description "$(description_json "${temporary_directory}/libcurl-app-stripped")" \
  --arg rust_app_description "$(description_json "${temporary_directory}/rust-app-stripped")" \
  --arg libcurl_native_description "$(description_json "${temporary_directory}/libalphax_curl-stripped")" \
  --arg rust_native_description "$(description_json "${temporary_directory}/libalphax_rust_http-stripped")" \
  --argjson dart_app_bytes "$(size_of "${temporary_directory}/dart-baseline-app-stripped")" \
  --argjson libcurl_app_bytes "$(size_of "${temporary_directory}/libcurl-app-stripped")" \
  --argjson rust_app_bytes "$(size_of "${temporary_directory}/rust-app-stripped")" \
  --argjson libcurl_native_bytes "$(size_of "${temporary_directory}/libalphax_curl-stripped")" \
  --argjson rust_native_bytes "$(size_of "${temporary_directory}/libalphax_rust_http-stripped")" \
  '{
    git_commit: $git_commit,
    git_worktree_dirty: $git_worktree_dirty,
    os: $os,
    architecture: $architecture,
    toolchains: {
      dart: $dart_version,
      libcurl: $curl_version,
      rust: $rust_version
    },
    methodology: {
      build_mode: "release Dart AOT executables and stripped native shared libraries",
      application_artifact: "each candidate app is compiled from its release benchmark entry point; baseline is Dart IO, native candidates include their FFI wrapper",
      alpha_x_incremental_size: "candidate stripped application artifact minus stripped Dart baseline application artifact; this is a harness-artifact delta, not a production-app delta",
      bundled_native_library_size: "stripped libcurl or Rust shared library copied as a separate distributable file",
      dependency_accounting: "dynamic dependency lists are recorded separately; system-provided libraries are not added to bundled native-library bytes",
      system_dependency_caveat: "macOS observations are not extrapolated to Android, iOS, Linux, or Windows",
      comparability_limit: "equivalent production application packaging is not yet available; compare native payloads and disclosed dependencies separately from the harness executable delta"
    },
    artifacts: {
      dart_baseline: {
        application_artifact_bytes: $dart_app_bytes,
        alpha_x_incremental_bytes: 0,
        bundled_native_library_bytes: 0,
        stripped: true,
        description: $dart_description,
        dynamic_dependencies: $dart_dependencies
      },
      libcurl: {
        application_artifact_bytes: $libcurl_app_bytes,
        alpha_x_incremental_bytes: ($libcurl_app_bytes - $dart_app_bytes),
        bundled_native_library_bytes: $libcurl_native_bytes,
        stripped: true,
        application_description: $libcurl_app_description,
        native_description: $libcurl_native_description,
        application_dynamic_dependencies: $libcurl_app_dependencies,
        native_dynamic_dependencies: $libcurl_native_dependencies
      },
      rust: {
        application_artifact_bytes: $rust_app_bytes,
        alpha_x_incremental_bytes: ($rust_app_bytes - $dart_app_bytes),
        bundled_native_library_bytes: $rust_native_bytes,
        stripped: true,
        application_description: $rust_app_description,
        native_description: $rust_native_description,
        application_dynamic_dependencies: $rust_app_dependencies,
        native_dynamic_dependencies: $rust_native_dependencies
      }
    }
  }' >"$output_path"

echo "Binary-size result: $output_path"
