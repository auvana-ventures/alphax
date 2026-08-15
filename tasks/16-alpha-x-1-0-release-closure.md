# AlphaX 1.0 Release Closure

Status: [-] Blocked

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
- a concrete platform/tooling blocker is recorded as a blocker, not hidden by
  changing the approved scope.

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
- [-] Run focused macOS, Android, and iPhone checks when environments permit;
  preserve existing evidence and do not run broad benchmarks. The macOS
  security fixture passed. The signed iPhone run verified H2/H3 and invalid-TLS
  rejection, but its local H1 fixture was unreachable and a later automation
  retry hit `osascript: -2`. Android ADB was briefly visible and APK transfer
  succeeded, but package-install commit stalled; after reboot the wireless
  endpoint did not reappear.
- [x] Create `docs/ALPHAX_1_0_RELEASE_GATE.md`, update API/docs/migrations, and
  reconcile every required scope item with an exact state.
- [x] Run consolidated validation, security/dependency/configuration audits,
  review the complete diff, and commit logical milestones. The repository
  validation is green; device-only evidence remains an external blocker.

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

Recover Android ADB/package-manager access and run the focused Android release
checks. APK push/session write passed, but installation commit stalled and the
wireless endpoint disappeared after reboot. Re-run the signed iPhone focused
checks with a reachable H1 fixture.
Provider-limited proxy/custom-trust behavior and optional mTLS are already
accepted fail-closed boundaries; they are not pending maintainer decisions.

## Blockers

Android API 35 was visible over wireless TLS ADB for this attempt. The profile
APK built, pushed, and was written to an install session, but package-install
commit stalled without a result; after reboot the wireless endpoint did not
reappear, so no Android transport result was recorded. The signed iPhone
attached for H2/H3 and invalid-TLS checks, but both host
interfaces failed to reach the local H1 fixture and a later `flutter drive`
retry hit `osascript: -2`; H1/fallback, requirement, pin/custom-trust, and
redirect checks remain open on that device. These are environment blockers and
must not be solved by weakening production security or signing behavior. The
macOS focused custom-CA, pin, proxy, CONNECT, and authentication fixture is
complete. Provider-limited Cronet direct/explicit proxy/custom trust,
unsupported Dart IO pinning, optional mTLS, and explicit HTTPS proxy endpoint
parity are accepted fail-closed boundaries, not blockers.

## Outcome

`BLOCKED FOR 1.0 RC`: the transport-neutral foundations and adapter mappings
are implemented, but focused Android/iPhone release-path evidence remains
unavailable. The exact states are tracked in
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
- Android focused release attempt — ADB/device metadata, profile APK hash,
  push/session-write success, stalled install commit, and post-reboot endpoint
  loss are recorded in
  `benchmarks/mobile_gate/fixtures/phase1f_android_release_attempt.json`;
  no transport probe was counted.
