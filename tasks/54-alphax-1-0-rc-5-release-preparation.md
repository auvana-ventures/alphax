# Task 54 — AlphaX 1.0.0-rc.5 Release Preparation

Status: [*] In Progress

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
- [*] Audit package purpose, versions, dependencies, archive readiness, and
  coordinated publication classification.
- [ ] Prepare selected package versions and internal AlphaX constraints.
- [ ] Update package changelogs and current-facing rc.5 migration/release docs.
- [ ] Complete final API, platform, ecosystem, security, dependency, and path
  review without changing frozen feature scope.
- [ ] Run consolidated release validation and clean zero-warning dry-runs.
- [ ] Record publication order, hosted-consumer plan, limitations, and readiness.
- [ ] Review the Task 54-only diff, commit, push, confirm `HEAD == origin/main`,
  and stop without publishing or tagging.

## Validation

Planned checks:

- format and analysis for all eight packages;
- all package tests, transport/policy/conformance tests, retained A–E fixtures,
  and retained F/G/H fixtures;
- native, Web, and pure-Dart consumer/build checks available locally;
- Android, macOS, available iOS, and available Web/desktop validation gates;
- Dartdoc, Markdown/internal-link checks, dependency/security/path audits;
- post-version `dart pub publish --dry-run` with zero warnings for every
  `PUBLISH_RC5` package and archive inspection;
- `git diff --check`; no benchmarks.

## Next Action

Complete release preparation, push the preparation commit, and return for
explicit maintainer approval before any publication.

## Blockers

None currently.

## Outcome

Pending.

## References

- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/ALPHAX_1_0_FEATURE_FREEZE.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md`
- `docs/ALPHAX_1_0_RC_4_RELEASE_PREPARATION.md`
- `docs/ALPHAX_1_0_RC_4_PUBLICATION_REPORT.md`

## History

- 2026-08-30: Created after the approved AlphaX 1.0 feature freeze. No
  publication, tag, release, feature work, or benchmark work is authorized by
  this task.
