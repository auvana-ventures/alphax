# Phase 1E — Cross-Transport Parity and Release Validation

Status: [x] Completed

## Goal

Validate Dart IO, Android Cronet, and Apple URLSession as one
transport-independent AlphaX behavioral system, then stop before Phase 1F.
This package covers correctness, capability accuracy, completion-time metadata,
packaging, security, and release-configuration separation. It does not reopen
transport selection or performance benchmarking.

## Scope and Non-goals

Scope:

- produce the final Dart IO/Android/iOS/macOS capability matrix;
- exercise the shared and platform-specific conformance evidence already
  established in Phases 1B–1D;
- validate completion-time protocol metadata and truthful fallback reporting;
- document streaming, file, cancellation, timeout, redirect, error, and
  lifecycle parity;
- audit production dependencies, package artifacts, security boundaries, and
  test-only release configuration;
- create `docs/phase1e-cross-transport-validation.md`.

Non-goals:

- Phase 1F API hardening or release preparation;
- new transports, C++, Rust production code, libcurl production code, or
  transport architecture changes;
- performance comparisons, network shaping, protocol benchmarking, or broad
  benchmark reruns;
- Dio, caching, retry/resilience, observability, WebSocket/SSE, or other
  deferred features;
- publishing packages.

## Owner

Codex coordinator with maintainer review before Phase 1F.

## Dependencies

- pushed Phase 1D commit `50efa72`;
- accepted ADR 0004 and approved AlphaX 1.0 scope;
- proposed ADR 0005 completion-time protocol metadata;
- Phase 1B Dart IO, Phase 1C Android, and Phase 1D Apple evidence;
- physical-device and Apple build tooling where reruns are required.

## Assumptions

- the selected production architecture remains Dart IO fallback, Android
  Cronet/HttpEngine, and Apple URLSession;
- `alphax` remains pure Dart and public symbols remain transport-independent;
- capability, protocol preference, and actual negotiated protocol remain
  separate concepts;
- unknown protocol metadata is valid until a transport can provide authoritative
  completion information;
- no new performance data is required for this validation gate.

## Work Items

- [x] Build the final capability matrix with exact status vocabulary.
- [x] Run or reference shared conformance behavior for all applicable
  transports without weakening shared tests.
- [x] Validate completion-time metrics and fallback semantics across transports.
- [x] Document streaming, file-transfer, cancellation, timeout, redirect,
  error, and lifecycle parity.
- [x] Audit production dependency boundaries and package dry-run observations.
- [x] Perform the focused transport security review and release-configuration
  separation check.
- [x] Draft the evidence-based platform/protocol support statement.
- [x] Write the Phase 1E validation report and identify remaining 1.0 blockers.
- [x] Stop before Phase 1F and leave maintainer review as the next action.

## Validation

Planned consolidated checks:

- `dart format --set-exit-if-changed .` and `git diff --check` passed;
- package analysis and tests passed;
- platform/prototype analysis and benchmark contract/harness tests passed;
- package dry-run validation passed with expected dirty-tree warnings;
- Android physical correctness harness passed H1/H2/stream/file/cancel/lifecycle
  checks and recorded truthful H3→H2 fallback; retained Phase 1C H3 evidence was
  not rewritten;
- signed iPhone `flutter drive` shared conformance and macOS correctness passed;
- capability/protocol/completion metadata tests passed;
- dependency, signing/configuration, and secret/path audits passed;
- no performance matrix was run.

No performance ranking or benchmark matrix is part of this task.

## Next Action

Maintainer review of the Phase 1E report is required. Do not start Phase 1F
automatically.

## Blockers

The current Android network path fell back from H3 to H2; this is accurately
reported and does not invalidate the retained Phase 1C actual-H3 evidence. A
QUIC-permissive release-device acceptance check and a focused cross-origin
redirect security assertion remain release checklist items.

## Outcome

The final matrix, parity report, dependency/security review, and platform
support statement are in `docs/phase1e-cross-transport-validation.md`. The
transport layer is ready for 1.0 hardening review; Phase 1F and package
publication remain intentionally unstarted.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/phase1b-dart-io-review.md`
- `docs/phase1c-android-transport-review.md`
- `docs/phase1d-apple-transport-review.md`
- `packages/alphax_test/lib/src/transport_conformance.dart`

## History

- 2026-08-15: Task 14 reserved after Phase 1D commit `50efa72` was pushed.
  Phase 1E validation authorized; Phase 1F remains out of scope.
- 2026-08-15: Final capability matrix, cross-transport evidence, completion
  metadata validation, package/dependency audit, security review, release
  configuration review, and Phase 1E report completed. No performance benchmark
  was restarted and no production feature was added.
