# AlphaX 1.0 Release Candidate Preparation

Status: [x] Completed

## Goal

Prepare AlphaX for maintainer review of the first release candidate,
`1.0.0-rc.1`, without publishing, tagging, changing the transport architecture,
adding features, or restarting benchmarks.

## Scope and Non-goals

Scope:

- review and commit the existing release-gate implementation and retained
  focused Android/iPhone/macOS evidence;
- freeze and re-audit the public API, ADR statuses, package metadata, platform
  claims, migration/security/changelog/license documentation, and examples;
- run the complete release-candidate validation and package publication
  dry-runs;
- create the RC review document, commit the approved release-preparation batch,
  push `main`, and verify repository and security state.

Non-goals:

- no pub.dev publication, GitHub release, git tag, or package final release;
- no new transport architecture, production feature, public API addition, or
  post-1.0 work;
- no broad transport performance benchmarking or historical-report rewrite;
- no signing credentials, certificates, private keys, or maintainer-local
  project configuration in the release commits.

## Owner

Codex coordinator with maintainer approval required before publication.

## Dependencies

- completed AlphaX 1.0 release-gate work in task 16;
- accepted ADRs 0004 through 0008;
- clean or explicitly classified current worktree;
- available Dart, Flutter, Apple, Android, and package-publishing tooling for
  the requested validation scope.

## Assumptions

- the initial RC version is `1.0.0-rc.1`;
- `alphax`, `alphax_native`, and `alphax_test` are intended for RC publication;
- `alphax_dio` remains unpublished unless its empty boundary is deliberately
  approved during review;
- existing focused device reports are retained as evidence and are not
  regenerated or rewritten;
- the current transport architecture and public API are frozen for this RC.

## Work Items

- [x] Classify the current worktree and reserve release-preparation changes.
- [x] Freeze and verify the public API, ADRs, platform matrix, and capability
  boundaries.
- [x] Set consistent RC versions and decide the `alphax_dio` publication state.
- [x] Complete package metadata, README, migration, changelog, license,
  security, and example review.
- [x] Run final validation, audits, and package publication dry-runs.
- [x] Create the RC review document with exact evidence and verdict.
- [x] Commit release-gate work and retained evidence, push `main`, and verify
  remote/worktree/security state.

## Validation

The final consolidated pass covered formatting, Dart/Flutter analysis, package
and conformance tests, deterministic fixtures, Dartdoc, Markdown/link checks,
package dry-runs, example validation, Android/iOS/macOS builds,
dependency/native/security audits, and `git diff --check`.

Results:

- `dart format --set-exit-if-changed` passed for packages, the example, and
  the mobile gate.
- Dart analysis passed for `alphax`, `alphax_native`, `alphax_test`, and
  `alphax_dio`.
- Flutter analysis passed for `benchmarks/mobile_gate` and `examples/basic`.
- All four package test suites, shared conformance tests, benchmark contract
  tests, and benchmark harness tests passed.
- Deterministic JSON fixtures passed `jq` validation.
- Dartdoc with `--validate-links` passed for all four packages with zero
  warnings and zero errors.
- Local Markdown links passed. The new RC review document and newly authored
  prose documentation passed Markdown lint; large table-heavy historical docs
  retain baseline line-length/table-style warnings.
- The example widget test and host-independent bundle build passed. An APK
  build was not applicable because the example intentionally has no platform
  host project.
- The Android production Flutter host APK/plugin build, iOS no-code-sign
  build, and macOS no-code-sign build passed. Plugin-only standalone Gradle
  invocation was not used as release validation because its version/plugin
  management is supplied by the Flutter host.
- Dependency, native dependency, license/notice, signing/secret, endpoint,
  machine-path, and certificate/private-key audits passed.
- Clean publication dry-runs passed with zero warnings and zero errors:
  `alphax` 28 KB, `alphax_test` 8 KB, and `alphax_native` 72 KB. `alphax_dio`
  was intentionally excluded because it is `publish_to: none`.
- `git diff --check` passed.
- After cleanup and push, `git rev-parse HEAD` equals
  `git rev-parse origin/main`, and `git status --short --branch` reports a
  clean worktree.

Broad transport performance benchmarks were intentionally excluded.

## Next Action

Wait for maintainer approval and naming clearance. Publication, tagging, and
post-1.0 work are intentionally excluded from this task.

## Blockers

None. Publication remains intentionally out of scope and requires maintainer
approval after this task.

## Outcome

AlphaX is prepared for `1.0.0-rc.1` maintainer review. The public API is frozen,
ADRs 0004 through 0008 are Accepted, `alphax_dio` is deliberately unpublished,
the RC review document is complete, and the release-gate/evidence commits plus
RC review closeout are pushed to `origin/main`. No publication, tag, GitHub
release, transport change, feature work, or benchmark restart was performed.

## References

- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/phase1a-public-api-inventory.md`
- `docs/MIGRATION.md`
- `SECURITY.md`
- `CHANGELOG.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/decisions/0006-protocol-preference-vs-requirement.md`
- `docs/decisions/0007-transport-neutral-tls-policy-and-pinning.md`
- `docs/decisions/0008-proxy-policy-semantics.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`

## History

- 2026-08-16: Reserved task 17 for AlphaX 1.0 RC preparation after task 16
  reached `UNBLOCKED FOR 1.0 RC REVIEW`.
- 2026-08-16: Completed RC metadata, package-boundary, documentation,
  example, security, license, API-freeze, and validation work. Committed
  release acceptance as `7cbe8db`, release-gate documentation as `896ddb0`,
  and the RC review as `e7d284b`.
- 2026-08-16: Clean package dry-runs reported archives of 28 KB (`alphax`),
  8 KB (`alphax_test`), and 72 KB (`alphax_native`), all with zero warnings
  and zero errors. Cleaned disposable build output, verified no signing or
  machine-specific artifacts, and confirmed `HEAD == origin/main` with a
  clean worktree.
