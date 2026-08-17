# Task 32: Publish AlphaX 1.0.0-rc.1 packages

Status: [*] In Progress

## Goal

Publish the approved AlphaX `1.0.0-rc.1` package set to pub.dev in dependency
order and verify each package after upload.

## Scope and Non-goals

Scope:

- refresh the RC review record with the current documentation/branding commit
  and archive sizes;
- commit and push that release-record correction;
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

- [*] Refresh the RC review commit and archive-size record.
- [ ] Commit and push the release-record correction.
- [ ] Publish `alphax`.
- [ ] Publish `alphax_test`.
- [ ] Publish `alphax_native`.
- [ ] Publish `alphax_web`.
- [ ] Publish `alphax_dio`.
- [ ] Verify all five pub.dev package pages and dependency resolution.
- [ ] Record publication URLs, versions, and final outcome.

## Validation

- clean-state `dart pub publish --dry-run` for each package;
- interactive `dart pub publish` in the approved order;
- pub.dev API/version checks after each upload;
- package README, changelog, documentation, platform, and dependency checks;
- final `git status`, `HEAD`, and `origin/main` verification.

## Next Action

Update `docs/ALPHAX_1_0_RC_REVIEW.md`, commit/push it, then begin with
`alphax`.

## Blockers

None known. If pub.dev authentication or package validation stops an upload,
record the exact package and error before continuing.

## Outcome

Pending publication.

## References

- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `packages/*/pubspec.yaml`
- `https://dart.dev/tools/pub/publishing`
- `https://dart.dev/tools/pub/cmd/pub-lish`

## History

- 2026-08-17: Publication task opened after maintainer authorization.
