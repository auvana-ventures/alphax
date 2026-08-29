# Task 46 — AlphaX 1.0.0-rc.4 publication

Status: [*] In Progress

## Goal

Perform the final independent RC4 release gate, publish the six coordinated
AlphaX packages only if every required check is clean, verify the hosted
packages with disposable consumers, and record the publication outcome.

## Scope and Non-goals

In scope:

- Verify the pushed RC4 source state and release-owned worktree cleanliness.
- Review current-facing documentation, package metadata, dependency order,
  security, and publication contents.
- Run the final requested validation and zero-warning package dry-runs.
- Publish `alphax`, `alphax_test`, `alphax_native`, `alphax_web`,
  `alphax_dio`, and `alphax_transform` sequentially if the gate passes.
- Validate the published packages with hosted-only disposable consumers,
  including the Retrofit-through-Dio path.
- Update standalone examples to hosted RC4 dependencies after publication and
  record the release report.

Out of scope:

- New features, RC5 planning, transport or performance changes, and benchmark
  reruns.
- Package simplification, new adapters, direct Retrofit integration, or
  changes to accepted platform/provider boundaries.
- Publishing any package when a pre-publication gate fails.
- Creating a tag, GitHub release, or GitHub release assets without separate
  explicit authorization.
- Staging or modifying pre-existing benchmark/mobile/signing changes,
  historical evidence, raw results, ignored logs, or unrelated maintainer work.

## Owner

AlphaX maintainers / Codex implementation agent

## Dependencies

- Task 45 ecosystem compatibility documentation is accepted and must be pushed
  before the release gate.
- The six package manifests are coordinated at `1.0.0-rc.4`.
- Pub.dev credentials and network access are available if the gate passes.
- Existing release, platform, and security validation from the RC4 review
  remains available as historical evidence; this task reruns the checks required
  by the publication gate.

## Assumptions

- The current protected benchmark/mobile/signing changes are pre-existing user
  work and remain untouched.
- RC4 has not already been published; this is verified against pub.dev before
  any publish command. An already-existing RC4 version will not be republished.
- Current-facing documentation may be updated for the post-publication state,
  while historical audit and benchmark reports remain historical.
- The expected publication order is the actual manifest dependency order unless
  inspection proves otherwise.
- Tag and GitHub release actions remain pending because this instruction does
  not explicitly authorize them.

## Work Items

- [*] Reserve Task 46 and verify repository/remote state and protected worktree
  ownership.
- [ ] Commit and push the approved Task 45 documentation separately.
- [ ] Audit current-facing documentation, metadata, constraints, package
  archives, dependency order, and security/path contents.
- [ ] Run final release validation and six zero-warning publish dry-runs.
- [ ] Apply the publication decision gate; create a blocked report and stop if
  any required condition fails.
- [ ] Publish all six packages sequentially only after the gate passes, checking
  pub.dev resolution before each dependent package.
- [ ] Run hosted-only clean-consumer validation, including Retrofit generation
  and the `alphax_transform` consumer.
- [ ] Update standalone examples to hosted RC4, validate them, and push the
  separate post-publication example/docs change.
- [ ] Create the final publication report, update task outcome/history, and
  push allowed release documentation.
- [ ] Leave tags and GitHub releases pending and stop for maintainer direction.

## Validation

Required validation includes formatting, Dart/Flutter analysis, all six package
test suites, conformance/policy tests, the hosted Retrofit fixture, transform
tests, Web tests/build, Dartdoc, Markdown/internal-link checks, Android
profile/release consumer build, clean macOS and available iOS consumer builds,
workspace resolution, dependency/security/signing/path audits, six plain
`dart pub publish --dry-run` checks with zero warnings, hosted clean consumers,
and `git diff --check`. Phase 0 and integration-cost benchmarks are excluded.

## Next Action

Commit and push only the Task 45-owned documentation, then continue the final
RC4 gate from the pushed commit. Do not publish until every gate condition is
independently green.

## Blockers

None at task start.

## Outcome

Pending final release gate and publication outcome.

## References

- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/ALPHAX_1_0_RC_4_RELEASE_PREPARATION.md`
- `docs/ALPHAX_ECOSYSTEM_COMPATIBILITY_REVIEW.md`
- `docs/USAGE_AND_CUSTOMIZATION.md`
- `packages/*/pubspec.yaml`

## History

- 2026-08-30 — Task 46 reserved for the approved conditional RC4 publication
  and hosted-consumer verification workflow.
