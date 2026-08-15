# Phase 1F — Release Hardening

Status: [-] Blocked

## Goal

Harden the approved AlphaX transport architecture and public packages for the
first 1.0 release-candidate review without adding transports or broad product
features. Freeze the public API, close focused security and release checks,
improve migration usability, and record every required 1.0 item as complete or
concretely blocked.

## Scope and Non-goals

Scope:

- review and freeze the public AlphaX API and exported-symbol inventory;
- add focused cross-origin redirect-header security assertions for applicable
  Android and Apple paths;
- perform release/profile-oriented physical Android H3 and signed iPhone
  acceptance checks where the connected devices and network permit;
- finalize package metadata, README guidance, changelogs, dartdoc, migrations,
  and a minimal production-like example;
- audit production dependencies, signing/configuration boundaries, CocoaPods
  packaging, and required 1.0 scope completion;
- create `docs/phase1f-release-hardening.md`.

Non-goals:

- new transport engines, C++, Rust production code, libcurl production code, or
  changes to the accepted Android Cronet / Apple URLSession / Dart IO strategy;
- Phase 1E benchmarking, transport selection, network shaping, or broad
  performance work;
- caching, retry/resilience, observability, WebSocket/SSE, full Dio adapter, or
  other deferred features;
- publishing to pub.dev, tagging 1.0, or starting work after Phase 1F.

## Owner

Codex coordinator with maintainer release approval required after this task.

## Dependencies

- pushed Phase 1E commit `4af24f3`;
- accepted ADR 0004 and retained H3/fallback evidence;
- ADR 0005 completion-time protocol metadata semantics;
- Phase 1B Dart IO, Phase 1C Android, and Phase 1D Apple implementations;
- connected Android/iPhone devices and valid local signing configuration for
  device-only validation;
- CocoaPods/Flutter and XcodeBuildMCP tooling for Apple checks.

## Assumptions

- the accepted transport architecture and pure-Dart `alphax` boundary are
  frozen;
- local iOS development-team settings may remain in the worktree for device
  validation but must not be staged or committed;
- public protocol claims remain evidence-based and distinguish capability,
  preference, actual negotiation, and fallback;
- CocoaPods is sufficient for the 1.0 Apple packaging path unless validation
  exposes a concrete blocker;
- a release-candidate review may report a concrete environmental blocker
  without weakening TLS, signing, or provider behavior.

## Work Items

- [-] Review every production public export and freeze the 1.0 API inventory.
  Export review is complete, but final freeze is blocked by the policy and
  protocol-requirement API decision.
- [-] Add focused cross-origin stripping assertions for Authorization,
  Proxy-Authorization, and Cookie, covering applicable Android and Apple
  transports. The deterministic fixture and focused runner exist; physical
  execution remains blocked by device/tooling state.
- [-] Run release/profile-oriented Android physical H3 acceptance and retain
  provider, protocol, fallback, and device evidence.
- [-] Run signed iPhone release-oriented acceptance and preserve H1/H2/H3,
  fallback, streaming, file, cancellation, and lifecycle evidence.
- [x] Finalize package metadata, changelogs, README, migration guidance,
  Dartdoc, and the minimal example application.
- [x] Audit production dependencies, release configuration, signing material,
  native/benchmark boundaries, and CocoaPods/SPM packaging choice.
- [x] Compare all REQUIRED FOR 1.0 scope items and mark each COMPLETE or
  BLOCKED with a concrete reason.
- [x] Run the consolidated Phase 1F validation suite and write the release
  hardening report. Repository checks passed; device-only checks remain
  concretely blocked as recorded below.
- [x] Stop after Phase 1F without publishing or tagging; leave maintainer
  release approval as the next action.

## Validation

Planned consolidated checks:

- Dart formatting, analysis, tests, dartdoc/link checks, and package dry-runs;
  - shared transport conformance plus focused Dart/Android/Apple security tests;
  - release/profile Android physical acceptance and signed iPhone acceptance,
  subject to device/network availability;
- macOS URLSession validation;
- Flutter example analysis/tests;
- Markdown/docs checks, `git diff --check`, secret/signing/path audits, and
  production dependency/configuration audits.

Validation completed on 2026-08-15:

- `dart format --set-exit-if-changed .` — passed;
- package analysis, package tests, package metadata validation, prototype
  analysis, benchmark contract/harness tests — passed;
- `dart test` for the deterministic benchmark server — passed;
- package dry-runs — passed with expected dirty-worktree warnings only;
- dartdoc dry-runs and link validation for all four packages — passed;
- `flutter analyze` and `flutter test` for `examples/basic` — passed;
- `flutter analyze` for `benchmarks/mobile_gate` — passed;
- macOS profile conformance, protocol/fallback, and redirect-security runners
  — passed;
- iOS profile no-code-sign build — passed;
- Android profile APK build — passed; device installation hung;
- Markdown checks with MD013 disabled for intentional long tables, diff check,
  and secret/signing/native dependency audits — passed.

The signed iPhone focused runners and Android physical Phase 1F runner remain
blocked by the environment, without any security or transport bypass.

No transport-ranking benchmark or broad benchmark matrix is part of this task.

## Next Action

Resolve the explicit API decision and recover Android/iPhone device validation,
then rerun only the focused release-gate assertions. Await maintainer approval
before publishing or tagging; do not start Phase 1G work.

## Blockers

- Android release/profile APK installation hangs in the connected device
  package manager, so the Phase 1F device runner cannot start.
- The focused signed iPhone runner builds and installs, but Flutter/Xcode
  attachment fails with `osascript: -2`; prior signed H1/H2/H3 evidence is
  preserved and no signing/TLS workaround was used.
- The accepted 1.0 scope names `AlphaXTlsPolicy`, `AlphaXProxyPolicy`, and a
  protocol requirement surface that are not present in the frozen Phase 1A
  public API. Adding them requires maintainer approval for a transport-neutral
  API change.

## Outcome

Phase 1F release hardening is implemented and documented, but the release
candidate gate is blocked by the concrete device/tooling validation failures
and the unresolved transport-neutral policy/requirement API decision. No
package was published and no tag was created.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/phase1e-cross-transport-validation.md`
- `docs/phase1d-apple-transport-review.md`
- `docs/phase1c-android-transport-review.md`
- `packages/alphax_test/lib/src/transport_conformance.dart`

## History

- 2026-08-15: Task 15 reserved after Phase 1E documentation was committed
  and pushed as `4af24f3`. Phase 1F authorized; no Phase 1G work is in scope.
- 2026-08-15: Reviewed and cleaned public exports, added security/protocol
  fixtures, hardened package/docs/examples, and recorded Phase 1F blockers in
  `docs/phase1f-release-hardening.md`. Device validation was not bypassed.
