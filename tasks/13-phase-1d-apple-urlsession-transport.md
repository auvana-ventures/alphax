# Phase 1D — Apple URLSession transport

Status: [x] Completed

## Goal

Implement one shared Swift URLSession transport adapter for iOS and macOS in
`alphax_native`, against the frozen Phase 1A AlphaX contract. The adapter must
preserve transport-independent Dart APIs while providing correct HTTP methods,
request/response bodies, streaming, bounded platform delivery, cancellation,
file transfers, progress, lifecycle, capability reporting, and actual protocol
observation for Apple networking.

## Scope and Non-goals

Scope:

- add shared Apple URLSession implementation with thin iOS/macOS plugin entry
  points;
- use reusable URLSession instances and deterministic invalidation;
- map required methods, body forms, redirects, errors, timeouts, streaming,
  bounded delivery, progress, cancellation, and native-capable file paths;
- report actual HTTP/1.1, HTTP/2, and HTTP/3 where URLSession metrics expose it,
  including truthful preferred-H3 fallback;
- run transport-neutral conformance behavior on Apple targets and platform
  specific correctness tests;
- validate at least one physical iPhone and macOS without performance ranking;
- document deployment targets, protocol evidence, limitations, and Phase 1E
  release-validation blockers.

Non-goals:

- Phase 1E cross-transport parity/release validation;
- HTTP/3 implementation or custom QUIC/TLS;
- C++ engine, Rust transport, libcurl, or FFI architecture;
- background URLSession transfer as a 1.0 capability;
- pinning, mTLS, retry/resilience, cache, observability, Dio, WebSocket, SSE,
  or other deferred features;
- changing the pure-Dart `alphax` API unless a genuine transport-neutral defect
  is discovered and reviewed;
- transport benchmarking or performance ranking.

## Owner

Codex coordinator with maintainer review of Apple protocol evidence, lifecycle,
and any transport-neutral contract issue.

## Dependencies

- accepted `docs/decisions/0004-platform-native-mobile-transports.md`;
- approved 1.0 scope in `docs/ALPHAX_1_0_SCOPE.md`;
- Phase 1A contracts and conformance suite;
- Phase 1B Dart IO fallback;
- Phase 1C Android Cronet adapter and H3 evidence at commit `fbdd5de`;
- Flutter Apple plugin tooling, Swift/Foundation URLSession, macOS SDK, and a
  physical iPhone for final H3 evidence.

## Assumptions

- `alphax` remains pure Dart and no Foundation, URLSession, Flutter, or native
  task type crosses the public API;
- iOS and macOS share the transport core wherever Foundation behavior permits;
- platform trust and ATS defaults remain enabled;
- URLSession task metrics are the authoritative protocol source when available;
- unavailable metrics or capabilities remain unknown/unsupported rather than
  being fabricated;
- Phase 1D may document a protocol-observation limitation for streamed starts
  if Foundation exposes the negotiated protocol only after task completion;
  this must be explicit and carried into Phase 1E review.

## Work Items

- [x] Inspect Apple deployment targets, URLSession APIs, Flutter plugin
  registration, and physical-device/macOS availability.
- [x] Define shared URLSession engine/session lifecycle and Apple provider
  capability policy.
- [x] Add iOS/macOS plugin entry points and transport-neutral Dart facade.
- [x] Implement required methods, headers, body forms, redirects, errors, and
  timeouts.
- [x] Implement progressive response streaming with bounded delivery and
  pause/resume/cancellation semantics.
- [x] Implement native file upload/download paths and monotonic progress.
- [x] Implement actual protocol metrics and preferred-H3 fallback reporting.
- [x] Implement replayable streamed-body redirect reset and await URLSession
  invalidation during close.
- [x] Release the shared Apple session on iOS engine detach/plugin teardown and
  strip sensitive headers on cross-origin redirect follow.
- [x] Make concurrent close callers join one completion future and allow a
  later facade to create a fresh URLSession only after invalidation completes.
- [x] Resolve completion-time negotiated-protocol metadata with the smallest
  transport-neutral `AlphaXResponse.completionMetrics` and
  `completionProtocolFallback` contract additions, including terminal stream
  metadata.
- [x] Add protocol metadata tests covering valid `unknown`, early-known
  protocols, and authoritative completion metrics.
- [x] Add an isolated Flutter integration runner for the shared `alphax_test`
  conformance suite without adding Flutter to `alphax`.
- [x] Validate and document URLSession system-proxy inheritance, unsupported
  explicit proxy configuration, proxy authentication limits, HTTP CONNECT
  ownership, and H3 fallback implications.
- [x] Add Apple-specific correctness tests while preserving the shared
  conformance suite.
- [x] Execute the shared `alphax_test` conformance suite through the new real
  Apple platform integration runner. The physical-device `flutter drive`
  runner built, signed, connected to the Dart VM service, reported `All tests
  passed.`, and exited successfully.
- [x] Validate iOS on a physical iPhone and macOS correctness without a
  performance benchmark matrix. Both platforms passed the focused H1/H2/H3,
  fallback, streaming, file, cancellation, TLS, and lifecycle checks.
- [x] Write `docs/phase1d-apple-transport-review.md` and record Phase 1E
  blockers without starting Phase 1E.

## Validation

Validation completed or attempted:

- `dart format --set-exit-if-changed .` — passed;
- `tooling/scripts/analyze_dart_packages.sh` — passed for all Dart packages;
- `tooling/scripts/test_packages.sh` — passed, including 33 `alphax_native`
  tests and Apple protocol mapping tests. The package is Flutter-backed, so
  the canonical command is `flutter test`; a direct `dart test` invocation is
  not applicable because it cannot load `dart:ui`.
- prototype analysis and benchmark contract/harness tests — passed;
- `tooling/scripts/validate_packages.sh` — all four dry-runs passed; the
  expected dirty-worktree warning appeared for the uncommitted native package;
- Flutter iOS Profile build with `--no-codesign` — passed;
- XcodeBuildMCP macOS Profile arm64 build — passed;
- XcodeBuildMCP macOS launch correctness harness — passed H1/H2/H3/fallback,
  methods, redirect, streaming pause/resume, cancellation, TLS rejection,
  streamed request body, request-timeout category mapping, native file
  transfer, progress, and close-after-invalidation checks;
- signed physical iPhone Profile harness — passed H1, H2, H3, truthful H3
  fallback, methods/bodies, streaming pause/resume, cancellation, timeout,
  TLS rejection, native file transfer/progress, and close/reuse lifecycle;
- shared Flutter `integration_test` runner through `flutter drive` on the
  signed iPhone — passed; the driver connected to the Dart VM service, all
  shared conformance tests passed, and the command exited 0;
- XcodeBuildMCP iOS Profile device build with
  `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` — passed;
- `scutil --proxy` — passed; the validation Mac had no active HTTP/HTTPS proxy;
- shared platform conformance runner — added under
  `benchmarks/mobile_gate/integration_test/` with
  `benchmarks/mobile_gate/test_driver/integration_test.dart`; `flutter drive`
  is the canonical physical-device execution path and passed;
- focused macOS Profile harness rerun with `https://www.apple.com/` as the H2
  endpoint — passed all checks: H1/H2/H3, fallback, methods/bodies, streaming
  pause/resume, cancellation, timeout mapping, TLS rejection, native file
  transfer/progress, and close/reuse lifecycle;
- focused macOS rerun initially exposed Foundation omitting a materialized
  `OPTIONS` body from a data task. The adapter now uses a data-backed upload
  task for `OPTIONS` byte bodies only; the rerun passed all required methods
  and bodies, including the exact echoed payload;
- signed iPhone `flutter drive` rerun on the current Wi-Fi fixture address
  passed the shared Apple conformance suite. A separate direct
  `flutter run` result-printing launch built and installed but did not attach
  within Flutter's device-debug timeout; the prior complete signed-device
  result remains preserved above and this is recorded as tooling attachment
  behavior, not a transport result;
- `dart format --set-exit-if-changed .` — passed with no changes;
- `tooling/scripts/validate_packages.sh` — passed for all four packages; only
  expected dirty-worktree warnings were reported for uncommitted changes;
- `git diff --check` — passed; generated analyzer excludes were restored and
  no certificates, provisioning files, credentials, or local paths were added;
- package documentation and task report updated to distinguish verified
  behavior, API decisions, proxy limitations, and device-only blockers.

## Next Action

Maintainer review is required for the completed implementation and
macOS/iPhone evidence. Do not begin Phase 1E from this task.

## Blockers

No Phase 1D blockers remain. The signed physical iPhone validation and the
shared Apple conformance runner both passed. The transport-neutral response
contract exposes completion-time metrics and fallback metadata without leaking
URLSession types or buffering the body.
Proxy behavior is no longer an undocumented blocker: system inheritance and
the unsupported explicit-proxy boundary are recorded in the review report.

## Outcome

The shared iOS/macOS URLSession adapter and focused closure changes are
implemented. macOS and signed physical-iPhone Profile correctness validation
passed with actual H1, H2, H3, and truthful H3 fallback metrics plus streamed
request bodies, exact request-timeout mapping, streaming, cancellation, TLS,
progress, native file checks, and lifecycle checks. The shared Apple
conformance runner also passed on the signed iPhone through `flutter drive`.
The final fresh macOS build fixed the custom streamed-upload `InputStream`'s
required Foundation lifecycle hooks; the rerun completed without a native
exception. A follow-up review fix resets replayable streamed bodies before
redirect replacement streams and waits for URLSession invalidation before
acknowledging native close.
No Phase 1E work was started and no package was published.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/architecture/transport_contract.md`
- `packages/alphax/lib/src/alpha_x_response.dart`
- `packages/alphax_test/lib/src/transport_conformance.dart`
- `docs/phase1b-dart-io-review.md`
- `docs/phase1c-android-transport-review.md`
- `packages/alphax_test/lib/src/transport_conformance.dart`
- `packages/alphax_native/lib/src/android_cronet_transport.dart`

## History

- 2026-08-14: Task 13 reserved after Phase 1C commit `fbdd5de` was pushed;
  Apple URLSession implementation authorized. No Phase 1E work started.
- 2026-08-15: Shared Swift adapter, Dart facade, Apple protocol tests, macOS
  correctness harness, package validation, and documentation completed. The
  physical iPhone attempt was blocked by missing Xcode team/profile settings;
  preserve this task as blocked until maintainer-provided signing is available.
- 2026-08-15: Self-review corrected explicit Apple timer errors to preserve the
  actual connect/request/read/overall timeout category. The final macOS
  Profile build and iOS no-code-sign Profile build passed again; Flutter
  package tests remained green.
- 2026-08-15: The focused fresh macOS harness exposed missing Foundation
  lifecycle hooks in the custom streamed-upload `InputStream`. Implemented
  `streamStatus`, delegate/property accessors, and run-loop scheduling hooks;
  rebuilt through XcodeBuildMCP and reran the harness successfully, including
  streamed request-body and request-timeout mapping checks.
- 2026-08-15: Code review identified replayable streamed-body redirect replay
  and close callback-quiescence gaps. Added native upload-cursor reset before
  replacement streams and awaited URLSession invalidation during close; no
  public Phase 1A API changed.
- 2026-08-15: Focused maintainer closure added transport-neutral completion
  metrics and final fallback metadata for immutable/streamed responses,
  protocol-state tests, an isolated Flutter shared-conformance runner, and
  explicit URLSession proxy limitations. The additive API decision is recorded
  in proposed ADR 0005. The signed physical-iPhone Profile harness later
  passed H1/H2/H3 and fallback validation; the shared Debug integration runner
  still exits before VM-service startup and remains the only Phase 1D blocker.
- 2026-08-15: The local Runner signing team was configured. The signed iPhone
  Profile harness passed actual H1, H2, H3, and H3-to-H1 fallback plus the
  focused correctness checks. The direct Flutter Debug integration listener
  was not reliable on the device, so the canonical `flutter drive` driver was
  added and the shared conformance suite passed with VM-service evidence.
- 2026-08-15: A focused macOS rerun found that Foundation omitted a
  materialized `OPTIONS` body on the data-task path. The Apple adapter now
  selects a data-backed upload task for that method only; the full macOS
  correctness harness passed afterward. The signed iPhone shared-conformance
  driver also passed on the current Wi-Fi fixture address; a direct
  result-printing launch remained subject to the known Flutter/Xcode attach
  timeout after build/install.
