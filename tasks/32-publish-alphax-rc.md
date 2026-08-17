# Task 32: Publish AlphaX 1.0.0-rc.1 packages

Status: [x] Completed

## Goal

Publish the approved AlphaX `1.0.0-rc.1` package set to pub.dev in dependency
order and verify each package after upload.

## Scope and Non-goals

Scope:

- refresh the RC review record with the current documentation/branding commit
  and archive sizes;
- commit and push the release-record correction;
- publish `alphax`, `alphax_test`, `alphax_native`, `alphax_web`, and
  `alphax_dio` as `1.0.0-rc.1`;
- verify package pages, versions, README/changelog rendering, and dependency
  availability after publication.

Non-goals:

- no production code, API, transport, policy, benchmark, or version changes;
- no stable `1.0.0` release;
- no git tag or GitHub release;
- no post-1.0 feature work;
- no package publication outside the approved five-package RC set.

## Owner

Maintainer-authorized Codex execution using the maintainer's authenticated
pub.dev account.

## Dependencies

- maintainer approval for `1.0.0-rc.1` publication;
- authenticated pub.dev Google account in the active browser/CLI flow;
- clean pushed repository at the approved HEAD;
- package dependency order and prerelease constraints.

## Assumptions

- all five package names are available on pub.dev;
- the current clean-state dry-runs with zero warnings are the final upload
  inputs;
- pub.dev may take a short time to expose a newly uploaded dependency to the
  next package validation.

## Work Items

- [x] Refresh the RC review commit and archive-size record.
- [x] Commit and push the release-record correction.
- [x] Publish `alphax`.
- [x] Publish `alphax_test`.
- [x] Publish `alphax_native`.
- [x] Publish `alphax_web`.
- [x] Publish `alphax_dio`.
- [x] Verify all five pub.dev package pages and dependency resolution.
- [x] Record publication URLs, versions, and final outcome.

## Validation

- clean-state `dart pub publish --dry-run` for each package;
- interactive `dart pub publish` in the approved order;
- pub.dev API/version checks after upload;
- package README, changelog, documentation, platform, and dependency checks;
- final `git status`, `HEAD`, and `origin/main` verification.

## Next Action

Record the completed publication and wait for maintainer direction; do not
create a tag or GitHub release as part of this task.

## Blockers

None known. If pub.dev authentication or package validation stops an upload,
record the exact package and error before continuing.

## Outcome

All five approved packages were published successfully as `1.0.0-rc.1` on
2026-08-17 in dependency order:

- [alphax](https://pub.dev/packages/alphax)
- [alphax_test](https://pub.dev/packages/alphax_test)
- [alphax_native](https://pub.dev/packages/alphax_native)
- [alphax_web](https://pub.dev/packages/alphax_web)
- [alphax_dio](https://pub.dev/packages/alphax_dio)

The pub.dev API returned HTTP 200 with `latest.version = 1.0.0-rc.1` for each
package. The publication record was committed and pushed; no tag or GitHub
release was created. The package pages expose the expected README and
changelog content. Pub.dev resolves the core package logo, while the four
package-local README logos currently fall back to `[AlphaX]` because their
relative SVG paths are not resolved by pub.dev; this is a non-functional
post-publication branding follow-up and cannot be changed in an immutable
published version.

## References

- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `packages/*/pubspec.yaml`
- `https://dart.dev/tools/pub/publishing`
- `https://dart.dev/tools/pub/cmd/pub-lish`
- `https://pub.dev/packages/alphax`
- `https://pub.dev/packages/alphax_test`
- `https://pub.dev/packages/alphax_native`
- `https://pub.dev/packages/alphax_web`
- `https://pub.dev/packages/alphax_dio`

## History

- 2026-08-17: Publication task opened after maintainer authorization.
- 2026-08-17: RC review record refreshed and pushed in `af36265`.
- 2026-08-17: All five `1.0.0-rc.1` packages published and verified; task
  completed pending maintainer review.
