# Task 35: Fix CI Flutter test selection and hosted example dependencies

Status: [*] In Progress

## Goal

Make the package CI test selector work on the standard GitHub Actions runner
without assuming ripgrep is installed, and make the user-facing Flutter
examples consume the published AlphaX RC3 packages from pub.dev.

## Scope and Non-goals

Scope:

- replace the CI scripts' non-portable `rg` feature detection with a standard
  runner-compatible check;
- preserve `flutter test` for Flutter packages and `dart test` for pure Dart
  packages;
- change `examples/basic` and `examples/waypoint` from repository path
  dependencies to hosted `1.0.0-rc.3` dependencies;
- regenerate the affected example lockfiles from pub.dev resolution;
- verify the pushed CI run.

Non-goals:

- no production AlphaX API, transport, policy, or benchmark changes;
- no changes to benchmark/prototype local path dependencies;
- no new package publication or version change;
- no broad CI redesign.

## Owner

Maintainer-authorized Codex execution.

## Dependencies

- published `1.0.0-rc.3` AlphaX packages;
- GitHub Actions runner with Flutter stable;
- pub.dev access for example dependency resolution.

## Assumptions

- POSIX `grep` is available on the GitHub-hosted Ubuntu runner;
- `sdk: flutter` is the repository's stable marker for selecting Flutter test
  and analysis commands;
- the two application examples are intended to demonstrate released packages,
  while benchmark and prototype projects intentionally remain source-local.

## Work Items

- [x] Inspect the failed CI run and identify the test-package failure.
- [x] Create a portable Flutter-package detection path in CI scripts.
- [x] Change user-facing example dependencies to hosted RC3 packages.
- [x] Regenerate and inspect example lockfiles.
- [x] Run focused validation and the relevant package/example tests.
- [ ] Commit, push, and verify the resulting CI run.

## Validation

- shell syntax checks for modified CI scripts;
- package analysis/tests, including `flutter test` for `alphax_native`;
- `flutter pub get` and tests for `examples/basic` and `examples/waypoint`;
- lockfile source/version inspection;
- `git diff --check`;
- GitHub Actions run status and failed-step logs after push.

## Next Action

Commit and push the portable CI detection and hosted example dependency changes,
then verify the new GitHub Actions run.

## Blockers

None known.

## Outcome

The failed CI path is fixed by replacing the unavailable `rg` dependency with
POSIX `grep` in both package test and analysis scripts. The user-facing Basic
and Waypoint examples now resolve AlphaX `1.0.0-rc.3` packages from pub.dev;
their regenerated local lockfiles show `source: hosted` and `url: https://pub.dev`.
The package test script, both example test suites, package analysis, and both
example analyses pass locally. Push and remote CI verification remain pending.

## References

- `.github/workflows/ci.yml`
- `tooling/scripts/test_packages.sh`
- `tooling/scripts/analyze_dart_packages.sh`
- `examples/basic/pubspec.yaml`
- `examples/waypoint/pubspec.yaml`
- GitHub Actions run `32029988101`

## History

- 2026-08-17: Created after the CI test job failed because `rg` was not
  installed on the GitHub-hosted runner and user-facing example lockfiles still
  resolved AlphaX packages from local RC1 paths.
- 2026-08-17: Replaced `rg` feature detection with `grep`, migrated the two
  user-facing examples to hosted RC3 dependencies, and passed the focused local
  package/example validation.
