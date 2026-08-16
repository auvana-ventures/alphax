# Package Onboarding Documentation

Status: [x] Completed

## Goal

Make the four AlphaX release-candidate package READMEs, changelogs, and the
basic example accurate and simple enough for a new Dart or Flutter user to
choose a package, install it, run a first request, and understand the example
limitations.

## Scope and Non-goals

Scope:

- review and update package README quick-start instructions;
- remove non-copyable or unexplained setup placeholders;
- clarify which package a normal application should install;
- document the current unpublished-RC installation path and the post-publication
  package path;
- make the basic example's host-project and fixture-server requirements clear;
- correct stale wording in affected changelogs.

Non-goals:

- no new public APIs, transport behavior, or package dependencies;
- no transport architecture changes;
- no broad benchmark or network matrix rerun;
- no package publication, tag, or GitHub release;
- no rewriting of historical benchmark or phase reports.

## Owner

Codex coordinator with maintainer review required before publication.

## Dependencies

- AlphaX 1.0.0-rc.1 package APIs and package boundaries;
- current `docs/ALPHAX_1_0_RC_REVIEW.md` publication set;
- `examples/basic` released-API usage;
- existing deterministic benchmark server, only as an explicitly documented
  example fixture.

## Assumptions

- the four packages remain the intended RC publication set;
- the RC remains unpublished while documentation is prepared;
- a beginner-friendly guide can explain Dart/Flutter setup without hiding the
  fact that a Dart or Flutter application is still required;
- the existing example remains host-independent rather than gaining generated
  platform projects.

## Work Items

- [x] Audit all package READMEs and changelogs against the public exports.
- [x] Add simple package selection, installation, and first-use instructions.
- [x] Replace unexplained Dio transport placeholders with runnable setup.
- [x] Clarify basic example execution, endpoint requirements, and limitations.
- [x] Review the combined documentation diff and run scoped validation.

## Validation

Planned:

- Markdown/link checks for changed documentation;
- Dart format/analyze/test for any changed example code;
- package README/changelog review against `pubspec.yaml` and public exports;
- example `flutter analyze`, `flutter test`, and host-independent bundle build;
- `git diff --check`.

Completed on 2026-08-16:

- `markdownlint --disable=MD013` for changed Markdown — passed;
- local relative Markdown link validation — passed;
- `dart analyze .` and `dart test` for `alphax` — passed, 33 tests;
- `dart analyze .` and `dart test` for `alphax_test` — passed, 10 tests;
- `dart analyze .` and `dart test` for `alphax_dio` — passed, 6 tests;
- `flutter analyze .` and `flutter test` for `alphax_native` — passed, 35
  tests;
- `flutter analyze`, `flutter test`, and `flutter build bundle --debug
  --target lib/main.dart` for `examples/basic` — passed;
- `tooling/scripts/validate_packages.sh` — all four package dry-runs passed;
  expected dirty-worktree warnings were emitted before the documentation
  commit;
- `git diff --check` — passed.

## Next Action

Maintainer review of the simplified onboarding text, followed by the normal RC
publication approval process. No package publication is part of this task.

## Blockers

None.

## Outcome

All four publishable package READMEs now explain who should use each package,
how to install it during and after the unpublished RC, and how to perform a
first operation. The Dio README no longer contains an undefined transport
placeholder. The basic example documents its host-project boundary, fixture
routes, local deterministic server, and expected Dart IO HTTP/3 failure.

## References

- `README.md`
- `packages/alphax/README.md`
- `packages/alphax_test/README.md`
- `packages/alphax_native/README.md`
- `packages/alphax_dio/README.md`
- `examples/basic/README.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`

## History

- 2026-08-16: Reserved task 19 after the RC package onboarding audit found
  technically accurate but insufficiently simple setup instructions.
- 2026-08-16: Completed the README/changelog/example documentation batch and
  passed scoped package, example, Markdown, link, dry-run, and diff validation.
