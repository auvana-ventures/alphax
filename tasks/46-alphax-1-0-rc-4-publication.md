# Task 46 — AlphaX 1.0.0-rc.4 publication

Status: [x] Completed

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

- [x] Reserve Task 46 and verify repository/remote state and protected worktree
  ownership.
- [x] Commit and push the approved Task 45 documentation separately.
- [x] Audit current-facing documentation, metadata, constraints, package
  archives, dependency order, and security/path contents.
- [x] Run final release validation and six zero-warning publish dry-runs.
- [x] Apply the publication decision gate; create a blocked report and stop if
  any required condition fails.
- [x] Publish all six packages sequentially only after the gate passes, checking
  pub.dev resolution before each dependent package.
- [x] Run hosted-only clean-consumer validation, including Retrofit generation
  and the `alphax_transform` consumer.
- [x] Update standalone examples to hosted RC4, validate them, and push the
  separate post-publication example/docs change.
- [x] Create the final publication report, update task outcome/history, and
  push allowed release documentation.
- [x] Leave tags and GitHub releases pending and stop for maintainer direction.

## Validation

Required validation includes formatting, Dart/Flutter analysis, all six package
test suites, conformance/policy tests, the hosted Retrofit fixture, transform
tests, Web tests/build, Dartdoc, Markdown/internal-link checks, Android
profile/release consumer build, clean macOS and available iOS consumer builds,
workspace resolution, dependency/security/signing/path audits, six plain
`dart pub publish --dry-run` checks with zero warnings, hosted clean consumers,
and `git diff --check`. Phase 0 and integration-cost benchmarks are excluded.

## Next Action

Wait for maintainer direction on the optional `v1.0.0-rc.4` Git tag and GitHub
release. No further publication or RC5 work is authorized by this task.

## Blockers

None at task start.

## Outcome

`ALPHAX 1.0.0-RC.4 PUBLISHED SUCCESSFULLY`. All six packages were accepted by
pub.dev in dependency order and passed hosted-only clean-consumer validation,
including the generated Retrofit/Dio/Freezed fixture. Standalone examples were
updated to hosted RC4 and current-facing documentation was refreshed. No tag or
GitHub release was created.

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
- 2026-08-30 — Task 45 documentation and Task 46 record were pushed; final
  validation and all six zero-warning dry-runs passed.
- 2026-08-30 — Published all six RC4 packages sequentially, verified hosted
  consumers, updated examples/docs, and recorded the publication report.
