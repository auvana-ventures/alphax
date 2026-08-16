# AlphaX 1.0 Release Closure

Status: [x] Completed

## Goal

Reconcile the approved AlphaX 1.0 contract honestly and implement the missing
transport-neutral protocol, TLS, proxy, identity, capability, and redirect
security foundations without changing the accepted transport architecture or
starting a new benchmark/feature phase.

## Scope and Non-goals

Scope:

- audit every capability in `docs/ALPHAX_1_0_SCOPE.md`;
- add protocol preference-versus-requirement semantics;
- add constrained TLS, proxy, and client-identity contracts with honest
  capability/error behavior;
- map supported policy behavior across Dart IO, Android Cronet, and Apple
  URLSession where the selected providers permit it;
- verify and harden cross-origin redirect credential handling;
- resolve ADR 0005 and record foundational policy ADRs;
- update API inventory, security/conformance tests, release documentation, and
  the final 1.0 release gate.

Non-goals:

- no new transport architecture, C++ engine, Rust/libcurl production transport,
  or `alphax_flutter` package;
- no Phase 1G, performance benchmarking, protocol benchmark matrix, or
  transport-selection work;
- no cache, retry/resilience, observability, WebSocket/SSE, browser transport,
  GraphQL, REST generation, or full Dio adapter;
- no package publication or 1.0 tag.

## Owner

Codex coordinator with maintainer review required for any unresolved required
capability and before release-candidate approval.

## Dependencies

- accepted ADR 0004 and retained Phase 0/Phase 1 H3 and fallback evidence;
- Phase 1A transport-neutral contracts;
- Phase 1B Dart IO, Phase 1C Android Cronet, and Phase 1D Apple URLSession
  implementations;
- existing Phase 1F documentation and task record;
- physical Android/iPhone environments for focused release validation when
  device tooling permits it.

## Assumptions

- `alphax` remains pure Dart and implementation-independent;
- platform trust and networking stacks remain authoritative; no custom TLS
  engine is introduced;
- unsupported configured security/proxy policy fails predictably rather than
  silently degrading;
- local signing configuration remains uncommitted and is preserved for device
  work;
- H3 preference remains opportunistic: the provider and network determine the
  actual protocol, while an H3 requirement continues to fail closed when H3 is
  unavailable;
- live H3 negotiation on one Android network path is evidence about that path,
  not a universal 1.0 guarantee; no production QUIC hint or protocol-forcing
  behavior is introduced to manufacture a pass.

## Work Items

- [x] Read the approved scope, Phase 1A/1E/1F reports, ADRs, and public APIs;
  reserve this task and create the strict requirements audit.
- [x] Implement protocol requirement semantics and normalized requirement
  failures without weakening completion-time metadata semantics.
- [x] Implement constrained transport-neutral TLS policy, pinning/trust
  surfaces, client identity evaluation, proxy policy, and capability/error
  reporting.
- [x] Map policies to Dart IO, Android Cronet, and Apple URLSession; preserve
  secure defaults and reject unsupported policy requests.
- [x] Make cross-origin sensitive-header redirect behavior explicit or record
  the exact provider limitation for maintainer decision; add conformance tests.
- [x] Resolve ADR 0005 and add focused ADRs for protocol requirement, TLS, and
  proxy semantics where the decisions are architectural.
- [x] Run focused macOS, Android, and iPhone checks when environments permit;
  preserve existing evidence and do not run broad benchmarks. The macOS
  security fixture passed. The signed iPhone focused release/security run now
  passes H1/H2/H3, protocol requirement success/failure, custom trust,
  pinning, and redirect-header protection; the corrected evidence is retained
  in `benchmarks/mobile_gate/fixtures/phase1f_iphone_release_acceptance.json`.
  Android ADB is now visible over wired USB after reboot. The earlier direct
  package-install stall is retained in
  `benchmarks/mobile_gate/fixtures/phase1f_android_usb_install_attempt.json`.
  The release APK was then installed successfully through the device's
  ColorOS My Files -> Downloads -> Package Installer flow. Its focused runner
  completed, observed H2, and reported H3 preference -> H2 fallback. The
  initial installation-flow evidence is retained in
  `benchmarks/mobile_gate/fixtures/phase1f_android_download_install_acceptance.json`.
  A corrected focused runner then captured both public H3 endpoints falling
  back to H2, secure redirect rejection, cancellation, native file transfer,
  and lifecycle success. Its pre-fix protocol-requirement failure is retained
  in `benchmarks/mobile_gate/fixtures/phase1f_android_focused_pre_requirement_fix.json`.
  The Android adapter now rejects a mismatched known protocol before returning
  a response. The corrected APK was installed through ColorOS Downloads and
  the focused default/correct-pin/backup-pin/wrong-pin runs passed protocol
  failure, pinning, redirect safety, cancellation, file transfer, and
  lifecycle checks. Both public H3 endpoints negotiated H2 on the validated
  Wi-Fi and cellular paths; the live Android H3 result is retained as
  environment evidence, while the H3 requirement failure and fallback
  behavior are validated. An unvalidated cellular path is now rejected before
  probing and retained as separate environment evidence.
- [x] Add a self-contained Android/iPhone H3 acceptance runner that uses only
  approved public endpoints and persists its machine-readable report in the
  app documents directory for later retrieval over network tooling; do not
  broaden the two-check release gate. Android profile APK and signed-device
  iOS profile builds passed; alternate-network execution remains external
  validation.
- [x] Correct the disposable Android H3 runner's network-path selection so it
  requests and binds the app process to cellular data before Cronet starts,
  requires an active/validated/unrestricted runtime path, records the observed
  path, and fails clearly without probing when that path is unavailable. This
  does not change the production transport architecture or protocol reporting.
- [x] Export each focused Android report to the public `Downloads/AlphaX`
  folder through Android scoped storage while retaining the private app-
  document copy as the authoritative report. Runtime device execution and
  retrieval were validated over ADB.
- [x] Update the disposable H3 runner to prewarm and retry each approved
  endpoint on the same Cronet engine, recording Alt-Svc discovery attempts
  without adding a diagnostic QUIC hint or changing production transport code.
- [x] Reconcile the 1.0 release gate so environment-dependent live Android H3
  availability is a documented follow-up rather than an RC blocker, while
  retaining truthful fallback and fail-closed requirement semantics.
- [x] Create `docs/ALPHAX_1_0_RELEASE_GATE.md`, update API/docs/migrations, and
  reconcile every required scope item with an exact state.
- [x] Run consolidated validation, security/dependency/configuration audits,
  review the complete diff, and record the current validation. Prior and final
  repository validation are green; device-only H3 availability remains a
  documented non-gating follow-up.

## Validation

Affected validation will include:

- scoped Dart formatting, analysis, unit tests, and shared conformance tests;
- package dry-run validation and dartdoc/link checks;
- macOS URLSession focused TLS/pinning/proxy/protocol/redirect tests;
- Android/iPhone focused physical checks only when device/tooling is available;
- native/plugin build checks for changed platform code;
- Markdown/docs checks, `git diff --check`, and secret/signing/native
  dependency/configuration audits.

Commands and outcomes are appended below after the consolidated validation
pass. No package publication or release tag was performed.

## Next Action

Maintainer review and normal RC approval are the next actions. If additional
live Android H3 evidence is desired, run the bounded runner on a validated
QUIC-permissive path; this is non-gating. Preserve the live Android H3 report
as environment evidence and do not add a production QUIC hint or force H3.
Provider-limited proxy/custom-trust behavior and optional mTLS are already
accepted fail-closed boundaries; they are not pending maintainer decisions.

## Blockers

No implementation blocker remains. Android API 35 is visible over wireless
TLS ADB, and the supported ColorOS My Files -> Downloads -> Package Installer
flow installed the corrected APKs successfully. Focused physical runs passed
protocol-requirement failure, SPKI correct/backup/mismatch behavior,
cross-origin redirect protection, file transfer, cancellation, and lifecycle.
The tested Android Wi-Fi and cellular paths both fell back from H3 to H2;
that live H3 success observation remains an environment-dependent follow-up,
not a production correctness failure. The signed iPhone focused
release/security gate and macOS focused custom-CA, pin, proxy, CONNECT, and
  authentication fixtures are complete. Provider-limited Cronet direct/explicit
proxy/custom trust, unsupported Dart IO pinning, optional mTLS, and explicit
HTTPS proxy endpoint parity are accepted fail-closed boundaries, not blockers.

## Outcome

`UNBLOCKED FOR 1.0 RC REVIEW`: the transport-neutral foundations and adapter
mappings are implemented, the runner's discovery sequence and network guard are
validated, and the release gate no longer treats live Android H3 availability
as a universal 1.0 claim. The exact states are tracked in
`docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md` and
`docs/ALPHAX_1_0_RELEASE_GATE.md`.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/phase1f-release-hardening.md`
- `docs/phase1e-cross-transport-validation.md`
- `docs/phase1a-public-api-inventory.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/decisions/0006-protocol-preference-vs-requirement.md`
- `docs/decisions/0007-transport-neutral-tls-policy-and-pinning.md`
- `docs/decisions/0008-proxy-policy-semantics.md`

## History

- 2026-08-15: Task 16 reserved for strict AlphaX 1.0 release closure after
  Phase 1F identified foundational policy and protocol-requirement gaps.
- 2026-08-15: Added fail-closed protocol requirements, immutable TLS/trust/pin
  policy, opaque client identity, proxy policy/capabilities, normalized policy
  errors, and cross-origin sensitive-header redirect protection.
- 2026-08-15: Accepted ADRs 0005–0008 as applicable; preserved Android and
  Apple H3/fallback evidence and the diagnostic-only QUIC history.
- 2026-08-15: Consolidated repository validation passed; Android package
  manager/wireless ADB and signed iPhone attachment remained unavailable, so
  the task is blocked for RC approval rather than marked complete.
- 2026-08-15: Focused macOS security fixture passed custom trust, SPKI pin,
  proxy routing/CONNECT, Basic authentication, and fail-closed error checks.
  Signed iPhone H2/H3/invalid-TLS probes passed; local H1 reachability and
  subsequent automation remained environment-blocked. Maintainer proxy/mTLS
  decisions are recorded as accepted boundaries, not blockers.
- 2026-08-15: Signed iPhone focused release/security rerun passed H1/H2/H3,
  H3 requirement success/failure, custom trust, primary/backup pinning,
  invalid-certificate rejection, and cross-origin sensitive-header protection.
  A native canonical-protocol normalization defect was fixed and the
  machine-readable result was retained in
  `benchmarks/mobile_gate/fixtures/phase1f_iphone_release_acceptance.json`.
- 2026-08-15: Committed focused fixture and Apple proxy normalization in
  `0af3c69` (`test: add macOS TLS and proxy release fixtures`).
- 2026-08-15: Committed requirements, ADR validation, and release-gate
  reconciliation in `e92a382` (`docs: reconcile AlphaX 1.0 security release
  gate`).
- 2026-08-15: Android wireless ADB became visible on the physical API 35
  device; APK push and install-session write passed, but package-install commit
  stalled. After the permitted reboot the wireless endpoint did not reappear;
  no transport probe was counted and the attempt is recorded as environment
  evidence.
- 2026-08-15: Android returned over wired USB after reboot. Stale package
  sessions were abandoned and both profile and release Phase 1C APKs passed
  transfer and package parsing/integrity checks, but `adb install`, direct
  `pm install`, and the profile `--ignore-dexopt-profile` retry all stalled at
  90% in the Oplus install stage. No Android transport result was counted;
  evidence is retained in
  `benchmarks/mobile_gate/fixtures/phase1f_android_usb_install_attempt.json`.
- 2026-08-15: Android release-equivalent APKs were installed through the
  supported Downloads flow. Default, correct-pin, backup-pin, and wrong-pin
  focused runs passed all non-H3 checks, including the corrected protocol
  requirement failure, SPKI pinning, redirect security, cancellation, file
  transfer, and lifecycle. Both known-good H3 endpoints negotiated H2 on
  Wi-Fi. Combined evidence is retained in
  `benchmarks/mobile_gate/fixtures/phase1f_android_final_release_focused.json`.
- 2026-08-15: Added the self-contained two-check H3 runner for Android and
  iPhone. It defaults to the approved public endpoints, creates only the
  selected production transport, saves
  `alphax-phase1f-h3-release.json` in the app documents directory, and keeps
  the report path visible in the app. Android profile and signed-device iOS
  profile builds passed; alternate-network execution remains pending.
- 2026-08-16: The persisted Android report confirmed both public endpoints
  were reachable and advertised H3, but both requests negotiated H2. The
  runner's `Mobile-data` value was only a build-time label, so a focused
  runner-only network-selection fix was authorized to bind the app process to
  cellular data and record the runtime path before Cronet initialization.
- 2026-08-16: The disposable runner now requests cellular data through the
  Android `ConnectivityManager`, binds the app process before Cronet
  initialization, records runtime transport/capability state, and restores the
  default process network after the focused check. The profile APK was built
  and copied to the device Downloads folder as
  `alphax_phase1f_h3_cellular_selector.apk`; device execution remains pending.
- 2026-08-16: Added a runner-only Android `MediaStore` export so each report
  is also visible under `Downloads/AlphaX` without broad storage permissions;
  the private app-document report remains the source copy.
- 2026-08-16: Preserved the cellular H3 fallback report, changed the focused
  runner to prewarm and retry each approved origin for Alt-Svc discovery, and
  reconciled H3 release evidence with the transport-neutral preference and
  requirement contract. A physical rerun also confirmed that an unvalidated
  cellular path is rejected before probing. Live Android H3 remains a
  non-gating network-path follow-up; no production QUIC hint or
  protocol-forcing behavior was added.
- 2026-08-16: Installed the corrected profile APK over ADB. The device's
  cellular path reported `validated: false`; the runner rejected the path
  before Cronet initialization and persisted
  `benchmarks/mobile_gate/fixtures/phase1f_android_h3_cellular_unvalidated.json`.
  Android and iOS profile builds, analysis, formatting, package tests, JSON
  parsing, and diff checks passed.

## Validation Record

- `flutter pub get` — passed.
- `dart format --set-exit-if-changed .` — passed.
- `dart analyze packages/alphax packages/alphax_native packages/alphax_test` —
  passed with no issues.
- `dart test` in `packages/alphax` — passed.
- `flutter test` in `packages/alphax_native` — passed.
- `dart test` in `packages/alphax_test` — passed.
- `tooling/scripts/validate_packages.sh` — passed; package dry-runs only, no
  publication.
- `tooling/scripts/analyze_dart_packages.sh` and
  `tooling/scripts/test_packages.sh` — passed.
- `flutter build apk --debug --target lib/main.dart` — passed.
- `flutter build macos --debug` — passed.
- `flutter build ios --no-codesign --debug` — Xcode build passed; Flutter’s
  expected no-codesign app-copy step reported no signed `Runner.app`.
- Dartdoc dry-runs for production Dart packages — passed.
- `git diff --check` — passed.
- Secret/signing/native-dependency audit — passed for intended production
  changes; local iOS development-team configuration remains untracked from the
  commit set.
- `flutter run --profile --no-pub -d macos --target
  lib/phase1f_macos_security_main.dart` with generated temporary fixture
  material — passed all recorded macOS TLS/pinning/proxy checks; evidence is in
  `benchmarks/mobile_gate/fixtures/phase1f_macos_security_policy.json`.
- Signed iPhone profile run — actual H2, actual H3, and invalid-TLS rejection
  passed; local H1 endpoint was unreachable from the device. A later focused
  `flutter drive` retry ended with `osascript: -2`.
- `tooling/scripts/analyze_dart_packages.sh` — passed.
- `tooling/scripts/analyze_prototypes.sh` — passed.
- `tooling/scripts/test_benchmark_contract.sh` — passed.
- `tooling/scripts/test_benchmark_harness.sh` — passed.
- `tooling/scripts/validate_packages.sh` — passed with zero package warnings
  after the implementation commit; no publication was performed.
- `flutter build macos --profile --no-pub` — passed.
- `flutter build ios --profile --no-codesign --no-pub` — Xcode build passed.
- Fresh-output `dart doc --validate-links` for all four production packages —
  passed with zero warnings and zero errors. Existing ignored doc output can
  produce stale-tree warnings and was not used as release evidence.
- `markdownlint` — baseline and changed historical/table-heavy reports retain
  pre-existing line-length and second-H1 findings; no repository CI rule
  requires this tool.
- `git diff --check` after the closure commits — passed; the local iOS signing
  project modification remains unstaged and excluded from both commits.
- `dart format --set-exit-if-changed benchmarks/mobile_gate/lib/phase1f_h3_self_check_main.dart` — passed.
- `flutter analyze --no-pub` in `benchmarks/mobile_gate` — passed with no issues
  after the Alt-Svc retry and validated-network guard changes.
- `dart analyze packages/alphax packages/alphax_native packages/alphax_test` —
  passed with no issues.
- `dart test` in `packages/alphax`, `flutter test` in `packages/alphax_native`,
  and `dart test` in `packages/alphax_test` — all passed.
- `jq empty` over all mobile-gate JSON fixtures and `git diff --check` — passed.
- `flutter build apk --profile --no-pub --target lib/phase1f_h3_self_check_main.dart` —
  passed; profile APK was 78.8 MB.
- `flutter build ios --profile --no-codesign --no-pub --target lib/phase1f_h3_self_check_main.dart` —
  passed; unsigned profile `Runner.app` was 29.5 MB.
- Physical Android rerun after ADB installation — package install and launch
  passed; the runtime cellular path reported `validated: false`, so the runner
  persisted a blocked-environment report with zero H3 probes rather than
  misclassifying DNS failure as protocol fallback.
- Android focused release attempt — ADB/device metadata, profile APK hash,
  push/session-write success, stalled install commit, and post-reboot endpoint
  loss are recorded in
  `benchmarks/mobile_gate/fixtures/phase1f_android_release_attempt.json`;
  no transport probe was counted.
- Signed iPhone focused release/security runner — passed H1 fixture reachability,
  H2/H3 negotiation, protocol requirement success/failure, custom trust,
  primary/backup pinning, invalid-certificate rejection, and cross-origin
  sensitive-header protection. Evidence is in
  `benchmarks/mobile_gate/fixtures/phase1f_iphone_release_acceptance.json`.
- `flutter analyze --no-pub` in `benchmarks/mobile_gate` — passed.
- `flutter build ios --profile --no-codesign --no-pub` — passed after the
  Apple protocol-normalization fix.
- `flutter build macos --profile --no-pub` — passed after the shared Apple
  protocol-normalization fix.
- The Apple protocol-requirement fallback is bounded when task metrics never
  arrive; iOS and macOS profile builds passed after this lifecycle fix.
- Known Android endpoint `192.168.50.56:42799` was retried; ping reached the
  host, but the recorded ADB port and port 5555 both refused connections.
  `adb devices` and mDNS discovery remain empty; no Android result is inferred.
- Android USB recovery attempt — device shell and package manager responded;
  storage, install settings, profile/release APK transfer, and package
  parsing/integrity checks passed. Both APK install paths stalled at 90% with
  no final status and the package remained absent. No Android transport probe
  was run; evidence is in
  `benchmarks/mobile_gate/fixtures/phase1f_android_usb_install_attempt.json`.
- Android Download-folder recovery — the release APK was copied to
  `/sdcard/Download/alphax_phase1c_release.apk`, opened from ColorOS My Files,
  and installed successfully through Package Installer. The focused runner
  completed with H2 success and accurate H3-preference -> H2 fallback; the
  remaining protocol-requirement, pinning, and redirect-security checks remain
  open. Evidence is in
  `benchmarks/mobile_gate/fixtures/phase1f_android_download_install_acceptance.json`.
- Android focused runner pre-fix — on the physical API 35 device and
  Google-Play-Services Cronet `151.0.7922.29`, Cloudflare and Google both
  returned HTTP/2 with truthful H3 fallback; redirect security, cancellation,
  native file transfer, and lifecycle passed. The runner exposed that Android
  `send()` returned a lower-protocol response before the completion-time
  requirement error. Evidence is in
  `benchmarks/mobile_gate/fixtures/phase1f_android_focused_pre_requirement_fix.json`.
- Android focused adapter correction — Android now rejects a known mismatched
  negotiated protocol before returning a response for `send`, streaming, and
  file-transfer entry points. `alphax_native` analysis and Flutter tests pass;
  physical rerun is pending device reconnection.
- Self-contained H3 runner — `flutter pub get`, `flutter analyze --no-pub`,
  Android profile APK build, Flutter iOS profile no-code-sign build, and
  XcodeBuildMCP Profile device build all passed. The runner persists its
  report under the app documents directory. `flutter test --no-pub` has no
  `test/` directory in this validation app and was not treated as a product
  failure; there are no unit tests in that app target.
- XcodeBuildMCP signed iPhone build-and-run — the self-contained H3 runner
  installed and launched successfully on device `CC5119BA-1DBD-54D2-AD8C-1F15FC5E5B6F`;
  the report remains in the app Documents container for device-tool retrieval.
- Android cellular-selector runner — `flutter analyze --no-pub` passed;
  profile APK build passed; artifact SHA-256 is
  `527fb256f8fcbee876464f2b2fea81780dbcc855ca0c49ba45cd8024709f6470`; the
  same hash was verified at
  `/sdcard/Download/alphax_phase1f_h3_cellular_selector.apk`. Physical
  execution and report retrieval remain pending. The runner also exports a
  timestamped copy under `Downloads/AlphaX` through Android scoped storage.
