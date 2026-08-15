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
  preserve existing evidence and do not run broad benchmarks. macOS code/build
  checks pass; Android and iPhone release-path/device checks are blocked by
  package-manager/runner attachment failures.
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

Maintainer review must resolve the concrete device/tooling blockers and confirm
the provider-dependent policy boundary before AlphaX can be reported ready for
an RC. No approved requirement was silently downgraded.

## Blockers

Android wireless ADB/package-manager access stalled during release APK
installation and did not recover after the permitted reboot. The iPhone signed
runner built but Flutter/Xcode attachment ended with `osascript: -2`. These are
environment blockers and must not be solved by weakening production security or
signing behavior. Live macOS custom-CA/pinning/proxy fixtures were not recorded;
the implementation is present but that evidence remains open. The selected
Cronet provider cannot guarantee direct or explicit proxy routes, and no
selected adapter supports an HTTPS proxy endpoint or mTLS; the fail-closed
behavior requires maintainer acceptance as a capability-dependent boundary.

## Outcome

`BLOCKED FOR 1.0 RC`: the transport-neutral foundations and adapter mappings
are implemented, but physical release-path validation and focused live security
policy evidence remain unavailable in this environment. The exact states are
tracked in `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md` and
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
