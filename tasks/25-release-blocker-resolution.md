# Release Blocker Resolution

Status: [x] Completed

## Goal

Make the AlphaX 1.0.0-rc.1 release validation truthful and green by resolving the
repository-wide analysis blocker without broadening the frozen production API,
restarting transport benchmarks, or publishing artifacts.

## Scope and Non-goals

Scope:

- establish the correct analyzer boundary between releasable workspace packages
  and standalone benchmark tooling;
- keep the mobile benchmark app independently analyzable from its own Flutter
  package root;
- rerun the release-scoped validation and record the evidence in the RC review.

Non-goals:

- no transport architecture changes;
- no H3 guarantee or benchmark changes;
- no new public API;
- no pub.dev publication, GitHub release, tag, commit, or push;
- no rewrite of historical benchmark reports.

## Owner

Codex, with maintainer review required before publication.

## Dependencies

- existing AlphaX workspace and package manifests;
- `benchmarks/mobile_gate/pubspec.yaml` and its resolved Flutter package graph;
- repository CI scripts and `docs/ALPHAX_1_0_RC_REVIEW.md`.

## Assumptions

- `benchmarks/mobile_gate` is standalone release evidence and is not a package
  intended for pub.dev publication;
- package-scoped analysis is the authoritative validation for releasable Dart
  packages, while the mobile gate is validated from its own app root;
- the existing dirty worktree contains intentional maintainer changes and must
  be preserved.

## Work Items

- [x] Reproduce the root `dart analyze` failure and identify its affected files.
- [x] Resolve the mobile gate's own Flutter dependencies and confirm
      `flutter analyze` passes from `benchmarks/mobile_gate`.
- [x] Make the root analyzer exclude standalone mobile benchmark sources while
      retaining the existing package-scoped and CI validation paths.
- [x] Run the consolidated release-scoped validation after the fix.
- [x] Update RC review evidence, package status, and this task outcome.

## Validation

Completed checks:

- `dart format --set-exit-if-changed .`: passed;
- root `dart analyze`: passed;
- `tooling/scripts/analyze_dart_packages.sh`: passed;
- `tooling/scripts/test_packages.sh`: passed;
- `tooling/scripts/validate_packages.sh`: passed with only expected dirty-
  worktree warnings and no package-content errors;
- prototype analysis, benchmark contract, and benchmark harness scripts: passed;
- `flutter pub get && flutter analyze` in `benchmarks/mobile_gate`: passed;
- Waypoint dependency resolution, analysis, tests, bundle build, and macOS
  application build: passed;
- Android release APK, iOS device no-code-sign build, and macOS release
  no-sign build through XcodeBuildMCP: passed;
- Dartdoc link validation for all five prepared packages: passed with zero
  warnings and zero errors;
- signing/secret/path/endpoint/native-dependency audits and `git diff --check`:
  passed.

The iOS simulator-only compile was not promoted to a gate: the retained
benchmark FFI archives are device-built and are intentionally validated on
physical-device targets. The accepted iOS device no-code-sign build passed.

## Next Action

Maintainer review is the next action. Publication, tagging, and pushing remain
outside this task.

## Blockers

None. The repository is ready for maintainer RC review.

## Outcome

The root analyzer no longer reports false failures from the standalone mobile
gate, while the mobile gate remains independently analyzable from its own
Flutter package root. Release package analysis, tests, docs, dry-runs, audits,
and required build checks pass.

## References

- `analysis_options.yaml`
- `benchmarks/mobile_gate/analysis_options.yaml`
- `benchmarks/mobile_gate/pubspec.yaml`
- `tooling/scripts/analyze_dart_packages.sh`
- `.github/workflows/ci.yml`
- `docs/ALPHAX_1_0_RC_REVIEW.md`

## History

- 2026-08-17: Created after reproducing the root analyzer failure. The failure
  was limited to `benchmarks/mobile_gate`, where root analysis could not resolve
  Flutter and standalone benchmark dependencies. The app passes analysis after
  resolving its own dependencies.
- 2026-08-17: Added the root-only `benchmarks/mobile_gate/**` analyzer
  exclusion, fixed package README links exposed by dartdoc, completed the
  release validation/build pass, and recorded the result in the RC review.
- 2026-08-17: Release-preparation commits `534b627`, `25cb525`, and `cd1c550`
  were created and pushed to `origin/main`; the clean-state package dry-runs
  passed with zero warnings and zero errors.
