# AlphaX 1.0 Release Candidate Preparation

Status: [*] In Progress

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

- [ ] Classify the current worktree and reserve release-preparation changes.
- [ ] Freeze and verify the public API, ADRs, platform matrix, and capability
  boundaries.
- [ ] Set consistent RC versions and decide the `alphax_dio` publication state.
- [ ] Complete package metadata, README, migration, changelog, license,
  security, and example review.
- [ ] Run final validation, audits, and package publication dry-runs.
- [ ] Create the RC review document with exact evidence and verdict.
- [ ] Commit release-gate work and retained evidence, push `main`, and verify
  remote/worktree/security state.

## Validation

The final consolidated pass will cover formatting, Dart/Flutter analysis,
package and conformance tests, deterministic fixtures, Dartdoc, Markdown/link
checks, package dry-runs, example validation, Android/iOS/macOS builds,
dependency/native/security audits, and `git diff --check`. Broad transport
benchmarks are intentionally excluded.

## Next Action

Review the current diff and package/release metadata, then implement only the
bounded RC-preparation corrections before the final validation pass.

## Blockers

None known at task creation. Publication remains intentionally out of scope and
requires maintainer approval after this task.

## Outcome

Pending final validation, commit/push verification, and RC review document.

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

## History

- 2026-08-16: Reserved task 17 for AlphaX 1.0 RC preparation after task 16
  reached `UNBLOCKED FOR 1.0 RC REVIEW`.
