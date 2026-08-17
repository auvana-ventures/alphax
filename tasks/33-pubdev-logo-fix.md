# Task 33: Fix pub.dev README logo rendering

Status: [*] In Progress

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

- [ ] Create the task record and inspect the existing publication state.
- [ ] Replace all package-relative logo references with absolute asset URLs.
- [ ] Add RC2 changelog entries and update package versions/constraints.
- [ ] Run focused formatting, metadata, dry-run, and image URL validation.
- [ ] Publish all five packages in dependency order.
- [ ] Verify pub.dev package pages and rendered logo URLs.
- [ ] Commit/push the source and publication records.

## Validation

- `dart format --output=none --set-exit-if-changed` for changed Dart files;
- package manifest/version and dependency checks;
- `dart pub publish --dry-run` for all five packages;
- HTTP 200 checks for the absolute light/dark SVG URLs;
- pub.dev API, README, changelog, and image-reference checks after upload;
- final `git diff --check`, `git status`, `HEAD`, and `origin/main` checks.

## Next Action

Update all package README/changelog/version metadata, validate the archives, and
publish `1.0.0-rc.2` in dependency order.

## Blockers

None known. RC1 is immutable; if publication is required to correct the public
README, the coordinated RC2 upload is the only supported path.

## Outcome

Pending implementation and publication.

## References

- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `tasks/32-publish-alphax-rc.md`
- `packages/*/README.md`
- `packages/*/CHANGELOG.md`
- `packages/*/pubspec.yaml`

## History

- 2026-08-17: Created after pub.dev showed `/packages/assets/branding/...` 404
  for package-relative README logo paths.
