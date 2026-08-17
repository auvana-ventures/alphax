# Task 33: Fix pub.dev README logo rendering

Status: [x] Completed

## Goal

Repair the AlphaX logo references in every published package README so GitHub,
VS Code, and pub.dev resolve the light/dark SVG assets, then publish a
documentation-only coordinated `1.0.0-rc.2`.

## Scope and Non-goals

Scope:

- replace package-relative README logo paths with absolute repository asset URLs;
- add the correction to each package changelog;
- advance all five coordinated package versions and internal RC constraints to
  `1.0.0-rc.2`;
- run focused package dry-runs and publish in dependency order;
- verify pub.dev README image rendering and record the immutable RC1 limitation.

Non-goals:

- no production code, API, transport, policy, benchmark, or dependency feature
  changes;
- no stable `1.0.0` release;
- no git tag or GitHub release;
- no changes to the supplied SVG artwork;
- no OAuth/browser automation beyond the authenticated pub.dev publication flow.

## Owner

Maintainer-authorized Codex execution using the maintainer's authenticated
pub.dev account.

## Dependencies

- existing published `1.0.0-rc.1` package set;
- clean pushed repository at `5f1f47e`;
- authenticated pub.dev publisher account;
- dependency order: `alphax`, `alphax_test`, `alphax_native`, `alphax_web`,
  `alphax_dio`.

## Assumptions

- a documentation-only RC2 is the correct immutable-package correction;
- the repository `main` branch is the intended stable source for README image
  URLs;
- all five packages remain approved for coordinated RC publication.

## Work Items

- [x] Create the task record and inspect the existing publication state.
- [x] Replace all package-relative logo references with absolute asset URLs.
- [x] Add RC2 changelog entries and update package versions/constraints.
- [x] Run focused formatting, metadata, dry-run, and image URL validation.
- [x] Publish all five packages in dependency order.
- [x] Verify pub.dev package pages and rendered logo URLs.
- [x] Commit/push the source and publication records.

## Validation

- `dart format --output=none --set-exit-if-changed` for changed Dart files;
- package manifest/version and dependency checks;
- `dart pub publish --dry-run` for all five packages;
- HTTP 200 checks for the absolute light/dark SVG URLs;
- pub.dev API, README, changelog, and image-reference checks after upload;
- final `git diff --check`, `git status`, `HEAD`, and `origin/main` checks.

## Next Action

Wait for maintainer review. Do not create a tag or GitHub release as part of
this documentation-only correction.

## Blockers

None known. RC1 is immutable; if publication is required to correct the public
README, the coordinated RC2 upload is the only supported path.

## Outcome

The five coordinated `1.0.0-rc.2` packages were published successfully on
2026-08-17 after clean dry-runs with zero warnings:

- [alphax](https://pub.dev/packages/alphax) — 52 KB
- [alphax_test](https://pub.dev/packages/alphax_test) — 12 KB
- [alphax_native](https://pub.dev/packages/alphax_native) — 75 KB
- [alphax_web](https://pub.dev/packages/alphax_web) — 11 KB
- [alphax_dio](https://pub.dev/packages/alphax_dio) — 14 KB

Pub.dev API checks report `latest.version = 1.0.0-rc.2` for every package.
Each rendered README now contains an absolute light/dark SVG repository URL,
has no `/packages/assets/...` relative reference, and its pub.dev-proxied dark
logo returns HTTP 200. The source/publication record is pushed; no tag or
GitHub release was created.

## References

- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `tasks/32-publish-alphax-rc.md`
- `packages/*/README.md`
- `packages/*/CHANGELOG.md`
- `packages/*/pubspec.yaml`

## History

- 2026-08-17: Created after pub.dev showed `/packages/assets/branding/...` 404
  for package-relative README logo paths.
- 2026-08-17: Published RC2, verified all five pub.dev pages and image proxy
  responses, and completed the task.
