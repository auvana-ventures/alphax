# Mobile sanity gate

Status: [x] Completed

## Goal

Run the final, narrowly scoped Phase 0 mobile sanity gate on one physical
Android device and one physical iPhone. Compare the existing Dart IO,
libcurl/minimal-C-ABI/FFI, and Rust reqwest/hyper/C-ABI/FFI candidates using
only the requested five workloads. Produce one concise historical report and
stop for maintainer review without creating ADR 0004 or beginning Phase 1.

## Scope and Non-goals

Scope:

- Use one physical Android device and one physical iPhone; no emulators or
  simulators.
- Run warm small GET, 64 concurrent small GETs, 32 MiB download, 8 MiB upload,
  and one fixed mixed workload with three warmups and 9–10 measured runs.
- Reuse the existing deterministic server endpoints, benchmark contract, and
  native bridge APIs where they can be loaded on the devices.
- Record correctness, wall time, available process resources, connection
  observations, negotiated protocol, metadata, and incremental artifacts.
- Preserve all historical Phase 0 datasets and reports.

Non-goals:

- No new transport architecture or C++ engine.
- No HTTP/2 or HTTP/3 implementation work, network shaping, broad scenario
  matrix, extra clients, resilience features, or profiling unrelated to
  correctness.
- No production mobile transport implementation, ADR 0004, Phase 1 work, or
  package publication.

## Owner

Codex, with maintainer review required before ADR 0004 or Phase 1.

## Dependencies

- Existing Phase 0 transport prototypes and deterministic benchmark server.
- One reachable physical Android device and one reachable physical iPhone.
- Mobile-loadable release/profile artifacts for both native bridge candidates.
- A benchmark-only Flutter runner if no existing mobile runner is present.

## Assumptions

- HTTP protocol differences are disclosed and are not treated as equivalent
  unless the existing implementation negotiates the same protocol.
- Native fixes are out of scope unless a correctness defect prevents a fair
  run; any such fix is documented and rerun before comparison.
- Process CPU/RSS are recorded only when the device tooling provides reliable
  measurements without broad profiling work.

## Work Items

- [x] Inspect connected devices, existing mobile runner, and native artifact
  support.
- [x] Add only the minimum benchmark-only mobile runner and fixed workload
  definition required by this gate.
- [x] Build the signed profile runner and run all requested scenarios on the
  physical iPhone.
- [x] Build release/profile artifacts and run all requested scenarios on the
  physical Android device.
- [x] Validate byte counts, deterministic hashes, concurrency completion,
  protocol disclosure, and metadata.
- [x] Write the concise mobile sanity-gate report and stop for review.

## Validation

Completed local validation:

- `dart analyze benchmarks/mobile_gate prototypes/libcurl_ffi prototypes/rust_http`
  passed.
- `dart test` in both FFI prototype packages passed with their expected native
  library tests skipped because no host library path was supplied.
- Android arm64 profile APK build passed after linking the rebuilt libcurl and
  Rust artifacts.
- iOS arm64 profile build with code signing disabled passed after linking the
  rebuilt static libcurl and Rust artifacts.
- iOS signed profile build/install/launch passed on the physical iPhone after
  exporting the native bridge symbols from the executable.
- iPhone result contains 150 measured samples, all three candidates initialized,
  all correctness/hash checks passed, and all runs reported HTTP/1.1.
- The first Android capture exposed one Rust direct-download completion race:
  the native byte count and later hash were correct, but one immediate Dart file
  length read was short by 3,520 bytes. The Rust success path now explicitly
  flushes Tokio's file before delivering completion; the focused Rust FFI test
  and the corrected physical Android run passed.
- Corrected Android result contains 150 measured samples, all three candidates
  initialized, all correctness/hash checks passed, and all runs reported
  HTTP/1.1.
- Android profile APK and native bridge artifact sizes were recorded. iOS raw
  static archive and signed Profile app measurements were retained as artifact
  observations, not final per-candidate incremental app-size claims.
- Final validation passed: `dart format --output=none --set-exit-if-changed`
  for the affected Dart packages, `cargo fmt --check`, `dart analyze
  benchmarks/mobile_gate prototypes/libcurl_ffi prototypes/rust_http`,
  `cargo test --manifest-path prototypes/rust_http/Cargo.toml`, native Dart FFI
  tests for libcurl and Rust, and `git diff --check`.
- `git diff --check` passed; no signing profiles, credentials, local paths, or
  native binaries are tracked.

The iPhone capture predates the Rust flush correction because the physical
iPhone is now disconnected. It was already correctness-clean, and no iPhone
failure was observed; this provenance limitation is disclosed in the final
report rather than silently rewriting the historical raw result.

## Next Action

Stop for maintainer review of the mobile sanity-gate report. Do not create ADR
0004, modify the production transport architecture, publish packages, or begin
Phase 1.

## Blockers

None for the approved mobile gate. The iPhone is disconnected after its clean
capture; no additional device run is being started.

## Outcome

The approved physical-device comparison is complete. The iPhone raw result is
preserved at
`benchmarks/results/raw/mobile-sanity-gate/iphone-ios18.7.9-arm64-ad4b7b1.json`;
the corrected Android raw result is preserved at
`benchmarks/results/raw/mobile-sanity-gate/android-m2003j6a1g-android15-arm64-ad4b7b1-rust-flush.json`;
the concise comparison is recorded at
`benchmarks/results/summaries/phase0-mobile-sanity-gate.md`.

## References

- `benchmarks/results/summaries/phase0-final-transport-decision.md`
- `benchmarks/client/lib/benchmark_transport.dart`
- `prototypes/libcurl_ffi/`
- `prototypes/rust_http/`
- `prototypes/dart_io/`

## History

- 2026-08-14: Created for the maintainer-approved mobile sanity gate.
- 2026-08-14: Added the scoped runner, deterministic workload/hash validation,
  profile native artifacts, and local static analysis. Physical execution was
  blocked by Android wireless-debugging and iOS provisioning prerequisites.
- 2026-08-14: Android ADB was restored, but profile APK installation remains
  blocked by device-side package-manager behavior; no scenario data collected.
- 2026-08-14: Copied the validated profile APK to the physical Android
  device's `/sdcard/Download/AlphaX-Mobile-Gate-profile.apk` for manual
  installation.
- 2026-08-14: iPhone signing/trust was restored. The first signed run exposed
  missing executable exports for the static native bridges; the benchmark-only
  Xcode link flags were corrected and the affected run was repeated.
- 2026-08-14: iPhone completed 150 measured samples with all candidates
  initialized and all correctness/hash checks passing. Android ADB then became
  unavailable again (`connection refused`); no Android data was accepted.
- 2026-08-14: Android ADB was restored. One Rust direct-download sample exposed
  a short immediate file-length observation despite a complete later hash. The
  Rust native success path was corrected with an explicit Tokio file flush;
  focused host tests passed.
- 2026-08-14: Rebuilt the optimized Android arm64 Rust bridge and Profile APK.
  The corrected Android run completed 150/150 measured samples with all
  correctness and hash checks passing. The final mobile report was written;
  no production transport or ADR was changed.
