# Task 34: Improve pub.dev package quality points

Status: [*] In Progress

## Goal

Audit the pub.dev score breakdown for all AlphaX packages and recover
repository-controlled quality points without changing the frozen 1.0 API,
transport architecture, or accepted platform boundaries.

## Scope and Non-goals

Scope:

- add a meaningful package-local `example/main.dart` to each published package;
- document the implicit `AlphaXCookieJar` constructor;
- expand the short `alphax_web` pubspec description;
- prepare a coordinated documentation/example-only `1.0.0-rc.3`;
- rerun package validation and verify refreshed pub.dev score reports.

Non-goals:

- no production API, transport, policy, or benchmark changes;
- no artificial platform declarations or unsupported transport implementations;
- no fake H3/Web/Linux/Windows capability claims;
- no OAuth, persistence, resilience, or other deferred feature work;
- no git tag or GitHub release.

## Owner

Maintainer-authorized Codex execution.

## Dependencies

- published `1.0.0-rc.2` package set;
- clean pushed repository at the current AlphaX main branch;
- pub.dev score analysis after each new package version is processed.

## Assumptions

- pub.dev's example check accepts a valid package-local `example/main.dart`;
- all five packages remain approved for coordinated RC publication;
- `alphax_native` platform support remains Android/iOS/macOS only by design.

## Work Items

- [x] Create the task record and capture the score breakdown for all packages.
- [x] Add package-specific examples for `alphax`, `alphax_test`,
  `alphax_native`, `alphax_web`, and `alphax_dio`.
- [x] Add the missing `AlphaXCookieJar` constructor documentation.
- [x] Expand the `alphax_web` description to meet pub.dev guidance.
- [x] Update RC3 changelogs, versions, and internal constraints.
- [x] Run formatting, analysis, tests, dry-runs, and example checks.
- [x] Publish all five RC3 packages in dependency order.
- [*] Verify score reports and document accepted remaining deductions.
- [x] Commit/push the source and publication records.

## Validation

- `dart format` and `dart analyze` for changed package scopes;
- relevant package tests and example analysis;
- `dart pub publish --dry-run` for all five packages;
- pub.dev API score and score-page checks after publication;
- final `git diff --check`, `git status`, `HEAD`, and `origin/main` checks.

## Next Action

Wait for pub.dev Pana analysis to finish, then record the final scores and the
accepted `alphax_native` platform deduction.

## Blockers

None known. The `alphax_native` platform deduction is an accepted capability
boundary, not a release defect.

## Outcome

Repository-controlled fixes are implemented and pushed in `df26226`. All five
RC3 packages were published successfully in dependency order after clean
zero-warning dry-runs. Pub.dev currently reports `[pending analysis]` and
`0/0` for all five score endpoints; final score verification remains pending
external Pana processing.

## References

- `https://pub.dev/help/scoring`
- `https://pub.dev/api/packages/alphax/score`
- `https://pub.dev/api/packages/alphax_test/score`
- `https://pub.dev/api/packages/alphax_native/score`
- `https://pub.dev/api/packages/alphax_web/score`
- `https://pub.dev/api/packages/alphax_dio/score`
- `packages/*/README.md`
- `packages/*/pubspec.yaml`

## History

- 2026-08-17: Created after auditing the RC2 pub.dev score reports. The
  repository-controlled losses were missing examples, one short description,
  and one undocumented implicit constructor; native platform deductions remain
  intentional.
