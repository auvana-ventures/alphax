# Task 57: AlphaX 1.0 stable version preparation

Status: [*] In Progress

## Goal

Prepare the frozen AlphaX package family and current-facing documentation for
stable `1.0.0` publication without changing runtime behavior, public APIs, or
feature scope.

## Scope and Non-goals

Scope is limited to coordinated version/constraint updates, stable package
metadata, final changelogs, migration and release documentation, stable
release notes, validation, package dry-runs, and publication planning.

Non-goals are package publication, tags, GitHub releases, feature work, API
redesign, capability audits, post-1.0 work, benchmarks, new packages,
dependency freshness upgrades, hosted example updates before publication, and
runtime implementation changes.

## Owner

AlphaX maintainers / Codex implementation agent.

## Dependencies

- Published AlphaX `1.0.0-rc.5` package family.
- Accepted feature freeze and completed stabilization gate.
- Final stabilization HEAD `b9cb39ed375f642d4a272b5f547ad90847a917a7`.
- Existing Dart, Flutter, browser, native, package, and release validation
  tooling.

## Assumptions

- All eight rc.5 packages remain the stable publication set unless a concrete
  release defect proves otherwise.
- rc.5 package source and behavior are frozen; stable preparation changes only
  versions, constraints, metadata, changelogs, and current-facing docs.
- Historical rc.5 reports, tasks, fixtures, and hosted evidence remain
  historical and are not rewritten.
- Protected benchmark/mobile/history work in the dirty worktree must remain
  untouched and unstaged.
- Windows remains `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE`.

## Work Items

- [x] Read the freeze, scope, publication, and stabilization governance; inspect
  the protected worktree and reserve Task 57.
- [ ] Audit rc.5 references and classify current, historical, fixture, hosted,
  and external occurrences.
- [ ] Bump all eight package versions and coordinated internal AlphaX
  constraints to `1.0.0`.
- [ ] Add concise stable changelog entries and update current-facing metadata,
  READMEs, migration, roadmap, and usage documentation.
- [ ] Prepare stable release notes, GitHub release body, publication order, and
  hosted-consumer plan without publishing or tagging.
- [ ] Compare stable-preparation public/package source with rc.5 and run the
  required validation, audits, and clean zero-warning dry-runs.
- [ ] Complete this report and determine `PREPARED_FOR_PUBLICATION` or
  `BLOCKED`.
- [ ] Commit and push only Task 57-owned changes if preparation is complete.

## Validation

Planned validation includes formatting, Dart/Flutter analysis, all eight package
suites, retained conformance/policy/security/compatibility fixtures, typed
consumer fixtures, OpenAPI/Protobuf boundaries, available platform gates,
Dartdoc, Markdown/internal links, dependency and SDK audits, public API/source
comparison, clean stable package dry-runs/archive inspection, and
`git diff --check`. No publication, tag, release, benchmark, or post-1.0
feature command is authorized.

## Next Action

Complete the version-reference audit and apply the coordinated stable metadata
batch.

## Blockers

None at task creation.

## Outcome

In progress.

## References

- `docs/ALPHAX_1_0_FEATURE_FREEZE.md`
- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/ALPHAX_1_0_RC_5_PUBLICATION_REPORT.md`
- `docs/ALPHAX_1_0_STABILIZATION_AND_RELEASE_GATE.md`
- `docs/MIGRATION.md`
- `tasks/56-alphax-1-0-stabilization-and-release-gate.md`

## History

- 2026-08-30: Created for the authorized stable version-preparation task.
