# Phase 1C — Android Cronet/HttpEngine transport

Status: [x] Completed

## Goal

Implement the Android production transport adapter in `alphax_native` against
the frozen Phase 1A transport contract, using Kotlin/Java platform integration
and a reusable Cronet/HttpEngine lifecycle. The adapter must report actual H1,
H2, and H3 negotiation when the selected provider supports it, preserve the
transport-neutral Dart API, and provide bounded streaming, cancellation,
progress, and native-capable file transfer.

## Scope and Non-goals

Scope:

- define and document the Android provider policy and capability downgrade
  behavior;
- add the Android platform adapter and its transport-neutral Dart facade;
- use one reusable engine/session with concurrent requests and deterministic
  shutdown;
- implement required methods, body forms, redirects, errors, timeouts,
  streaming, bounded delivery, progress, cancellation, and file paths where
  the provider supports them;
- run the shared transport conformance suite and Android-specific tests;
- validate H1/H2/H3 negotiation, fallback, TLS defaults, reuse, lifecycle, and
  resource release on at least one physical Android device;
- document actual provider/version requirements, limitations, binary impact,
  and evidence in `docs/phase1c-android-transport-review.md`.

Non-goals:

- C++ engine, Rust transport, libcurl, or a new FFI architecture;
- iOS/macOS URLSession work or any Phase 1D+ implementation;
- Dio integration, cache, retry/resilience, observability, WebSocket/SSE, or
  other deferred features;
- broad performance benchmarks or transport ranking;
- changing the pure-Dart `alphax` API unless a genuine transport-neutral
  contract defect is found and documented for maintainer review;
- claiming full AlphaX H1/H2/H3 support before Apple transport validation.

## Owner

Codex coordinator with maintainer review of provider policy, device evidence,
and any transport-neutral contract issue.

## Dependencies

- accepted `docs/decisions/0004-platform-native-mobile-transports.md`;
- `docs/ALPHAX_1_0_SCOPE.md`;
- Phase 1A contracts at commit `c16f665`;
- Phase 1B Dart IO fallback at commit `2eaabe2`;
- shared conformance and fixture support in `packages/alphax_test`;
- Flutter/Android SDK, Kotlin/Gradle, a supported Cronet/HttpEngine provider,
  and one physical Android device for final evidence.

## Assumptions

- `alphax` remains pure Dart and exposes no Android, Cronet, HttpEngine,
  Flutter, or platform-channel type;
- `alphax_native` is the approved Flutter/platform adapter boundary now that
  Android integration is an actual approved requirement;
- secure certificate verification remains enabled by default;
- provider capability and actual negotiated protocol are reported separately;
- unsupported capabilities fail predictably or are discoverable, never
  silently advertised;
- the final device evidence may be blocked if no reproducible H3-capable
  server/provider/device combination is available; such a blocker must be
  recorded rather than replaced by an unverified claim.

## Work Items

- [x] Inspect repository, Flutter/Android toolchains, provider APIs, and
  physical-device availability.
- [x] Define and document provider policy, supported Android versions, H3
  enablement, fallback, TLS, proxy, migration, and capability downgrade.
- [x] Add the reusable Android engine/session and platform-channel adapter.
- [x] Implement request/response methods, bodies, redirects, errors, timeouts,
  streaming, bounded backpressure, progress, cancellation, and lifecycle.
- [x] Implement and validate native-capable file upload/download paths where
  supported without changing the public AlphaX API.
- [x] Add Android-specific tests and run the shared conformance suite.
- [x] Run the shared contract behaviors through the physical-device harness;
  package-level `package:test` definitions remain host-side and transport-neutral.
- [x] Validate H1/H2 and fallback negotiation plus TLS and lifecycle on a
  physical Android device.
- [x] Verify live H3 negotiation on a supported provider/device/server path;
  Cloudflare negotiated H3 through Google Play Services Cronet with the
  diagnostic QUIC hint, and the second endpoint's H2 fallback was reported
  accurately. Repeat on the final release configuration in Phase 1E.
- [x] Write the Phase 1C review report and update only documentation that
  describes functionality actually implemented.

## Validation

Completed host-side checks:

- `dart format --output=none --set-exit-if-changed .` — pass;
- `tooling/scripts/analyze_dart_packages.sh` — pass;
- `tooling/scripts/test_packages.sh` — pass;
- `tooling/scripts/validate_packages.sh` — exit 0; the native package's dirty
  worktree warning was intentionally ignored, and no publication occurred;
- `flutter build apk --profile --target lib/phase1c_main.dart --no-pub` — pass;
- `./gradlew :alphax_native:compileProfileKotlin --no-daemon --rerun-tasks` — pass;
- Physical device `192.168.50.56:42799` (`M2003J6A1G`, Android 15/API 35):
  profile APK install and fixed harness — H1 methods, H1 streaming pause /
  resume, redirect/reuse observation, native file hashes, cancellation, and
  H2 negotiation passed; H3 fallback to H2 was reported accurately;
- `dart doc --validate-links` in `packages/alphax_native` — 0 warnings/errors;
- markdownlint on changed documentation — pass;
- `git diff --check` — pass.
- `flutter test test/android_cronet_protocol_test.dart` in
  `packages/alphax_native` — pass; provider capability, H3 negotiation, and
  H3-to-H2 fallback mappings are covered.
- `flutter build apk --profile --target lib/phase1c_h3_main.dart --no-pub` —
  pass; focused single-protocol probe APK built successfully.
- Initial focused physical-device probe on `192.168.50.56:42799` — provider and
  configuration captured; H3-preferred request returned actual `http2` with
  explicit fallback metadata.
- Final focused physical-device probe on the same device and validated Wi-Fi —
  temporary `addQuicHint("cloudflare-quic.com", 443, 443)` produced actual
  `http3` from Cloudflare; `https://http3.is/` returned actual `http2` with
  explicit fallback metadata. The diagnostic hint was removed after probing.
- `benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json` —
  captured machine-readable H3 integration evidence.
- `./gradlew :alphax_native:compileProfileSources --no-daemon --rerun-tasks` —
  pass after removing the temporary diagnostic hint from the adapter source.
- `jq empty benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json`
  and markdownlint on the updated report/task — pass.
- Host endpoint check — `cloudflare-quic.com` returned HTTP 200 and
  `Alt-Svc: h3=":443"`; host curl has no HTTP/3 client support, so no
  independent host QUIC handshake was claimed.

Completed device checks:

- Android-specific H1/H2 protocol, lifecycle, bounded streaming, file,
  cancellation, and fallback evidence on a physical device;
- actual H1/H2 negotiated-protocol output and provider/version capture;
- device execution of the fixed contract behaviors.

Remaining release validation:

- Phase 1E must repeat actual H3 negotiation on the supported release
  application/provider configuration before AlphaX 1.0 makes a broad Android
  HTTP/3 support claim. This is not a Phase 1C blocker.

## Next Action

Stop for maintainer review. Do not start URLSession or Phase 1D work
automatically.

## Blockers

None for Phase 1C. Phase 1E retains a release-validation item: demonstrate
actual H3 negotiation on the supported release configuration and preserve
truthful H1/H2 fallback reporting.

## Outcome

Android plugin implementation, host profile build, static analysis, package
tests, package dry-runs, dartdoc validation, physical H1/H2 correctness, and
focused H3 capability evidence are green. Cloudflare negotiated actual H3 on
the physical Android device through Google Play Services Cronet after the
temporary diagnostic hint; `http3.is` demonstrated truthful H3-to-H2 fallback.
Phase 1C is complete and no Apple or Phase 1D work was started.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/architecture/transport_contract.md`
- `docs/phase1b-dart-io-review.md`
- `packages/alphax_test/lib/src/transport_conformance.dart`
- `benchmarks/mobile_gate/lib/phase1c_main.dart`
- `benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json`
- `docs/phase1c-android-transport-review.md`

## History

- 2026-08-14: Task 12 reserved after Phase 1B commit `2eaabe2` was pushed;
  Phase 1C discovery started. No Android implementation files existed before
  this task.
- 2026-08-14: Added the Flutter plugin boundary, provider-selected reusable
  Cronet engine, bounded platform-channel delivery, native file paths, fixed
  device correctness harness, CI Flutter routing, and review documentation.
- 2026-08-14: Host profile APK, Dart/Flutter analysis, package tests, package
  dry-runs, and dartdoc passed. Physical Android validation remains blocked by
  device connectivity.
- 2026-08-14: Physical Android `M2003J6A1G` validation passed all H1 methods,
  H1 streaming pause/resume, redirect/reuse observation, cancellation, native
  file upload/download hashes, and H2 negotiation using Google Play Services
  Cronet `151.0.7922.29`. H3 fallback to H2 was reported accurately; live H3
  negotiation was not observed on the current network. Fixed Cronet upload
  final-chunk semantics and cancellation/credit race handling were verified.
- 2026-08-14: Focused H3 probe confirmed the selected
  `Google-Play-Services-Cronet-Provider`, API 35 device, Cronet
  `151.0.7922.29`, explicit QUIC enablement, endpoint H3 advertisement, and
  truthful H3-to-H2 fallback. Added provider/protocol regression tests. The
  final focused probe temporarily added `addQuicHint("cloudflare-quic.com", 443,
  443)`, verified actual H3 on Cloudflare, verified H2 fallback on
  `https://http3.is/`, captured the evidence fixture, and removed the hint from
  the adapter source. Phase 1C is complete for maintainer review.
