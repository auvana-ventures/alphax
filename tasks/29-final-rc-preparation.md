# AlphaX 1.0 final release-candidate preparation

Status: [x] Completed

## Goal

Complete the maintainer-approved final AlphaX 1.0 RC preparation pass after the
policy API freeze, then commit and push the release-gate work for maintainer
publication approval without publishing, tagging, or adding features.

## Scope and Non-goals

Scope:

- review the complete policy-freeze and release-gate worktree diff;
- confirm the frozen public API, accepted ADRs, package publication set,
  dependency order, versions, security boundaries, and documentation;
- classify release-quality markers without reopening a capability-gap audit;
- run the final package, documentation, security, and platform validation;
- create the final RC review, commit the intentional changes, push `main`, and
  verify `origin/main` and worktree state.

Non-goals:

- no new product features or public API expansion;
- no transport architecture changes, benchmark reruns, or physical-device
  matrix reruns;
- no OAuth orchestration, persistence implementation, vendor resilience,
  WebSocket/SSE, observability, offline queue, or other deferred work;
- no pub.dev publication, git tag, GitHub release, or 1.0 final work.

## Owner

Codex, with maintainer approval required before publication.

## Dependencies

- completed `tasks/28-policy-api-freeze-fixes.md`;
- accepted policy ADRs 0009 and 0010;
- the AlphaX 1.0 scope, requirements audit, release gate, and policy-freeze
  review;
- available Dart, Flutter, Android, and Apple build tooling.

## Assumptions

- all current uncommitted changes are intentional AlphaX release work unless a
  read-only diff review identifies otherwise;
- all five package versions are prepared as `1.0.0-rc.1` and publication is
  still gated on maintainer approval and naming clearance;
- accepted platform and caller-owned limitations remain unchanged.

## Work Items

- [x] Inspect worktree, ADR status, scope documents, package manifests, and
      publication decisions.
- [x] Complete API-freeze, marker, README, security, dependency, and package
      archive review.
- [x] Run the consolidated RC validation and required platform builds.
- [x] Finalize `docs/ALPHAX_1_0_RC_REVIEW.md` and record all results.
- [x] Review, commit, push, and verify repository state.

## Validation

Planned:

- formatting, analysis, package tests, policy/conformance tests, examples,
  Dartdoc, Markdown/internal links, package dry-runs, platform builds,
  dependency/security audits, and `git diff --check`;
- no Phase 0 benchmark or broad physical-device rerun.

Completed commands/results:

- `dart format --set-exit-if-changed .`: passed, 122 files checked.
- `tooling/scripts/analyze_dart_packages.sh`: passed for all five packages and
  benchmark support packages.
- `tooling/scripts/test_packages.sh`: passed for all five packages, including
  policy, deterministic, and shared conformance tests.
- Flutter analyze/tests: passed for `examples/basic` and `examples/waypoint`.
- `dart doc --validate-links`: passed for all five packages with zero warnings.
- Markdown internal-link check, scoped MarkdownLint, and `git diff --check`:
  passed.
- `dart test`, `dart test -p chrome`, and `dart compile js` for `alphax_web`:
  passed. The Waypoint example has no Web target; its attempted Flutter Web
  build was therefore not applicable.
- Android release APK: passed. iOS and macOS Release no-code-sign builds via
  XcodeBuildMCP: passed; only pre-existing environment/stale-output warnings,
  no build errors.
- Clean package dry-runs: passed with zero warnings and no unexpected archive
  contents. Sizes: `alphax` 50 KB, `alphax_test` 10 KB, `alphax_native` 73 KB,
  `alphax_web` 9 KB, `alphax_dio` 12 KB.
- Dependency resolution/outdated review and native dependency review: passed
  with no discontinued/retracted resolved dependency. Standalone `dart pub
  audit` is unavailable in the installed Dart 3.13 CLI and was not claimed as
  passed.
- Security/credential/signing/path/endpoint audit: passed; no signing
  credentials, `DEVELOPMENT_TEAM`, machine paths, production benchmark
  endpoints, or diagnostic QUIC hint were found.

## Next Action

Maintainer review and approval before any publication or tag operation.

## Blockers

None known.

## Outcome

The policy/API contract commit is `c9a750d`. The final release-gate
documentation commit and pushed `origin/main` verification are reported in the
maintainer handoff. No package was published, no tag was created, and no
post-1.0 feature work was started.

## References

- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/ALPHAX_1_0_POLICY_FREEZE_REVIEW.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/phase1a-public-api-inventory.md`
- `docs/POLICIES.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/decisions/0006-protocol-preference-vs-requirement.md`
- `docs/decisions/0007-transport-neutral-tls-policy-and-pinning.md`
- `docs/decisions/0008-proxy-policy-semantics.md`
- `docs/decisions/0009-cookie-store-persistence-boundary.md`
- `docs/decisions/0010-private-variant-aware-http-cache-contract.md`

## History

- 2026-08-17: Reserved task 29 for final RC preparation after the AlphaX 1.0
  policy API freeze.
- 2026-08-17: Completed the final API, marker, security, package, documentation,
  platform-build, dry-run, and release-review gate. Waiting for maintainer
  publication approval.
