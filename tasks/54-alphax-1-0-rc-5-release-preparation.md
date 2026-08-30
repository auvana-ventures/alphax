# Task 54 — AlphaX 1.0.0-rc.5 Release Preparation

Status: [x] Completed

## Goal

Prepare the frozen AlphaX 1.0.0-rc.5 package family for coordinated publication
without publishing, tagging, creating a release, or adding feature scope.

## Scope and Non-goals

Scope:

- audit the current eight-package workspace graph and classify the coordinated
  publication set;
- update selected package versions and current internal AlphaX constraints to
  `1.0.0-rc.5`;
- update package changelogs and rc.4-to-rc.5 migration/current-facing release
  documentation;
- perform final frozen API, platform, ecosystem, security, dependency,
  packaging, and release validation;
- derive the publication dependency order and hosted-consumer validation plan;
- record release readiness in the final preparation report.

Non-goals:

- do not add features or change frozen APIs;
- do not fix POST_1_0 items or create an rc.6 backlog;
- do not publish packages, create tags, or create a GitHub release;
- do not run performance experiments;
- do not stage or modify the unrelated pre-existing benchmark/release worktree;
- do not rewrite historical rc.4, rc.3, fixture, or external references unless
  they are explicitly classified as current-release metadata.

## Owner

AlphaX maintainers / Codex implementation.

## Dependencies

- accepted `docs/ALPHAX_1_0_FEATURE_FREEZE.md`;
- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`;
- ADR-0011 and the bounded-optionals review;
- completed and pushed Tasks A–E plus resolved F/G/H evidence;
- the existing eight-package workspace and repository publication policy.

## Assumptions

- all eight current workspace packages are candidates for coordinated rc.5
  publication unless the package audit proves otherwise;
- `alphax_http` and `alphax_generator` use the coordinated `1.0.0-rc.5`
  prerelease identity if package readiness is confirmed;
- package publication remains a separate, explicitly approved action;
- version preparation may update current constraints and changelogs but must
  preserve historical evidence and hosted-consumer references by classification;
- the current dirty benchmark/release files belong to prior work and remain
  outside this task.

## Work Items

- [x] Reserve Task 54 and read the freeze/governing release documents.
- [x] Audit package purpose, versions, dependencies, archive readiness, and
  coordinated publication classification.
- [x] Prepare selected package versions and internal AlphaX constraints.
- [x] Update package changelogs and current-facing rc.5 migration/release docs.
- [x] Complete final API, platform, ecosystem, security, dependency, and path
  review without changing frozen feature scope.
- [x] Run consolidated release validation and clean zero-warning dry-runs.
- [x] Record publication order, hosted-consumer plan, limitations, and readiness.
- [x] Review the Task 54-only diff, commit, push, confirm `HEAD == origin/main`,
  and stop without publishing or tagging.

## Validation

Completed checks:

- `dart format --set-exit-if-changed packages` and the changed Waypoint source;
- Dart/Flutter analysis for all eight packages and all eight package suites;
- typed REST native, pure-Dart, Web, OpenAPI, and Protobuf fixtures;
- Web Chrome tests, native temporary-consumer tests, Android profile/release,
  macOS debug, and iOS simulator no-code-sign builds;
- retained A–E/F/G/H compatibility evidence and ecosystem fixtures;
- Dartdoc link validation, repository Markdownlint, relative-link checks,
  dependency, security/path, secret/signing, and protected-work audits;
- clean post-commit dry-runs and archive inspection for every `PUBLISH_RC5`
  package, all with zero warnings;
- `git diff --check`; no benchmarks.

## Next Action

Release preparation is complete. Return for explicit maintainer approval before
any publication; do not publish, tag, or create a release in Task 54.

## Blockers

None currently.

## Outcome

Completed. All eight workspace packages are prepared at `1.0.0-rc.5`, with
coordinated internal constraints, current-facing release/migration docs,
package changelogs, a final compatibility/platform/security/dependency review,
and zero-warning clean package dry-runs. The exact publication order and
hosted-consumer plan are in
`docs/ALPHAX_1_0_RC_5_RELEASE_PREPARATION.md`.

## References

- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/ALPHAX_1_0_FEATURE_FREEZE.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md`
- `docs/ALPHAX_1_0_RC_4_RELEASE_PREPARATION.md`
- `docs/ALPHAX_1_0_RC_4_PUBLICATION_REPORT.md`
- `docs/ALPHAX_1_0_RC_5_RELEASE_PREPARATION.md`

## History

- 2026-08-30: Created after the approved AlphaX 1.0 feature freeze. No
  publication, tag, release, feature work, or benchmark work is authorized by
  this task.
- 2026-08-30: Audited all eight package manifests and classified all eight as
  `PUBLISH_RC5`; prepared coordinated `1.0.0-rc.5` versions, native platform
  metadata, changelogs, current-facing documentation, and the additive rc.4 to
  rc.5 migration guidance.
- 2026-08-30: Completed package analysis/tests, typed consumer fixtures,
  OpenAPI/Protobuf fixtures, Web Chrome, clean temporary native platform builds,
  Dartdoc, Markdown/link, dependency, security/path, and archive checks. The
  focused preparation commit is `5ba48c4`.
- 2026-08-30: All eight clean post-commit package dry-runs passed with zero
  warnings: `alphax` 67 KB, `alphax_test` 12 KB, `alphax_native` 104 KB,
  `alphax_web` 17 KB, `alphax_dio` 15 KB, `alphax_transform` 14 KB,
  `alphax_http` 12 KB, and `alphax_generator` 17 KB. Archive inspections found
  no generated output, local paths, secrets, signing material, or benchmark
  artifacts.
- 2026-08-30: Pushed the preparation and evidence-record commits to
  `origin/main`; final `HEAD == origin/main` was verified. No package was
  published, no tag was created, and no GitHub release was created.
