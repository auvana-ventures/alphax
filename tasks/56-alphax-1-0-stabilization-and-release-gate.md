# Task 56: AlphaX 1.0 stabilization and release gate

Status: [x] Completed

## Goal

Complete the stabilization-only gate for the published AlphaX `1.0.0-rc.5`
candidate and determine whether it is ready for `1.0.0` version preparation.

## Scope and Non-goals

Scope is limited to hosted rc.5 verification, frozen public API review,
correctness/security/compatibility/platform-conformance validation, package and
documentation corrections, and release-gate evidence.

Non-goals are new features, new packages, architecture or transport changes,
new protocol/provider controls, reconnect behavior, gRPC, expanded OpenAPI or
GraphQL work, generator expansion, serialization expansion, benchmarks, rc.6
feature scope, stable publication, tags, and GitHub releases.

## Owner

AlphaX maintainers / Codex implementation agent.

## Dependencies

- Published AlphaX `1.0.0-rc.5` packages on pub.dev.
- Accepted rc.5 feature freeze and bounded optional decisions.
- Existing local Dart, Flutter, browser, and native validation tooling.

## Assumptions

- Task 55 publication evidence is authoritative where package source and
  manifests are unchanged.
- The existing dirty benchmark/mobile and historical documentation work is
  protected pre-existing work and must not be staged or modified.
- Any useful but non-blocking improvement is classified `POST_1_0` and is not
  implemented.

## Work Items

- [x] Read governing freeze, scope, ADR, publication, project, and architecture
  documents; inspect the protected worktree state.
- [x] Reserve the next monotonic task number and create this task record.
- [x] Reconfirm hosted rc.5 package metadata, dependency resolution, and the
  publication incident disposition.
- [x] Review the frozen public API inventory and classify every finding as
  `STABLE_BLOCKER` or `POST_1_0`.
- [x] Run the final package, policy, security, platform, protocol, generator,
  ecosystem, documentation, dependency, archive, and path validation gates.
- [x] Apply only bounded stabilization blockers or documentation corrections,
  preserving frozen APIs and protected pre-existing work.
- [x] Prepare the stable limitations, migration, release-notes, publication,
  and hosted-consumer plans without bumping versions or publishing stable.
- [x] Complete the stabilization report and determine
  `READY_FOR_1_0_VERSION_PREPARATION` or `STABLE_BLOCKERS_REMAIN`.
- [x] Commit and push only Task 56-owned changes if the gate is complete.

## Validation

Completed 2026-08-30:

- `bash tooling/scripts/test_packages.sh`: all eight package suites passed
  (`alphax` 95, `alphax_dio` 6, `alphax_generator` 4, `alphax_http` 24,
  `alphax_native` 61, `alphax_test` 10, `alphax_transform` 11,
  `alphax_web` 10).
- `bash tooling/scripts/analyze_dart_packages.sh`: all package and repository
  Dart analysis targets passed; tool-generated analyzer-option edits were
  restored because they were not part of the candidate.
- Tracked Dart formatting audit passed after formatting the two retained
  OpenAPI proof files; typed REST, Protobuf, and OpenAPI fixtures passed their
  analysis/tests and build-runner generated zero outputs.
- Basic and Waypoint analysis/tests passed; Waypoint Android debug APK,
  macOS debug, and iOS simulator no-code-sign builds passed.
- Hosted rc.5 metadata and fresh-cache dependency resolution passed for all
  eight packages; retained hosted consumers and Chrome/native fixtures remain
  green from the accepted publication evidence.
- `dart doc --validate-links` passed for all eight packages with zero errors;
  local Markdown target validation passed for 146 tracked Markdown files.
- Dependency, runtime-boundary, public-export, security, secret/signing/path,
  and protected-worktree audits passed.
- Clean-worktree `dart pub publish --dry-run` / Flutter equivalent passed for
  all eight packages with zero warnings; archive listings contained no
  forbidden build, fixture, benchmark-data, secret, signing, or local-path
  content.
- `git diff --check` passed. No benchmark, stable publication, tag, or GitHub
  release command was run.

## Next Action

Authorize the separate stable version-preparation task. No feature work is
permitted.

## Blockers

None at task creation.

## Outcome

`READY_FOR_1_0_VERSION_PREPARATION`. No `STABLE_BLOCKER` was found. The
published rc.5 candidate remains feature-frozen; stabilization-owned changes
are documentation corrections and current-SDK formatting for the retained
OpenAPI proof only.

## References

- `docs/ALPHAX_1_0_FEATURE_FREEZE.md`
- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_1_0_RC_5_PUBLICATION_REPORT.md`
- `docs/ALPHAX_1_0_RC_5_RELEASE_PREPARATION.md`
- `docs/ALPHAX_1_0_STABILIZATION_AND_RELEASE_GATE.md`
- `tasks/55-alphax-1-0-rc-5-publication.md`

## History

- 2026-08-30: Created for the authorized stabilization-only release gate.
- 2026-08-30: Hosted rc.5 metadata and fresh-cache resolution reconfirmed for
  all eight packages; the benign alphax propagation incident remains resolved.
- 2026-08-30: Frozen API review found no `STABLE_BLOCKER`; current-facing
  Phase 0/scope language was corrected and the retained OpenAPI proof was
  formatted to satisfy the current repository gate.
- 2026-08-30: Package suites, retained consumers/fixtures, available native/Web
  builds, docs/link, dependency, security/path, and archive checks passed.
- 2026-08-30: Clean-worktree package dry-runs passed with zero warnings; the
  bounded stabilization commit was created without staging protected work.
