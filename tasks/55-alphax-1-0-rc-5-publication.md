# Task 55 — AlphaX 1.0.0-rc.5 Publication

Status: [*] In Progress

## Goal

Publish the approved, feature-frozen AlphaX `1.0.0-rc.5` package family in the
required dependency order and verify clean hosted consumers without adding
features, tags, or a GitHub release.

## Scope and Non-goals

Scope:

- reconfirm the prepared release source and eight coordinated manifests;
- run only the required immediate pre-publication dry-run, archive, dependency,
  and security/path gates;
- publish the eight approved packages sequentially and verify each hosted
  version before continuing;
- validate clean hosted native, Web, pure-Dart, adapter, fixture, SSE,
  WebSocket, generator, OpenAPI-proof, Protobuf, transform, and test consumers;
- advance current-facing external examples from rc.4 to rc.5 after hosted
  validation and record the publication evidence.

Non-goals:

- do not add features or fix `POST_1_0` items;
- do not change frozen APIs or package architecture;
- do not run benchmarks;
- do not create a Git tag or GitHub release;
- do not publish stable `1.0.0`;
- do not stage or modify the pre-existing protected benchmark, mobile, signing,
  or historical release worktree changes.

## Owner

AlphaX maintainers / Codex implementation.

## Dependencies

- approved `docs/ALPHAX_1_0_FEATURE_FREEZE.md`;
- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`;
- ADR-0011 and `docs/ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md`;
- accepted Task 54 release preparation;
- publication approval for all eight packages;
- configured pub.dev publication access.

## Assumptions

- the package source remains unchanged from prepared commit
  `d4595e5699070671c1d12bba6852a227335e2f2e`, apart from this task's
  documentation-only reservation commit before publication;
- all eight approved packages publish as `1.0.0-rc.5` in the mandatory order;
- `alphax_http` and `alphax_generator` are coordinated family packages and are
  publishable at the approved prerelease version;
- hosted consumers must resolve from pub.dev without path dependencies,
  overrides, or workspace resolution;
- any publication or hosted-consumer failure stops the sequence and is recorded.

## Work Items

- [x] Read the freeze, scope, ADR, bounded-optionals, and release-preparation
  evidence and reserve Task 55.
- [*] Reconfirm the release source, package manifests, dependency graph, clean
  release-owned state, archive contents, dry-runs, and security/path audit.
- [ ] Publish `alphax`, `alphax_test`, `alphax_native`, `alphax_web`,
  `alphax_dio`, `alphax_transform`, `alphax_http`, and `alphax_generator` in
  order, verifying hosted resolution after each package.
- [ ] Run clean hosted-consumer and retained fixture validation without local
  path overrides.
- [ ] Update current-facing external examples to rc.5 and commit those changes
  separately after hosted validation.
- [ ] Complete the publication report, update this task with evidence, push
  owned commits, and stop with stabilization-only status.

## Validation

Required validation is intentionally release-oriented and does not repeat the
full Task 54 suite unless a material source/package change is discovered:

- pre-publication manifest/dependency/archive/security/path checks and zero-
  warning dry-runs for every package;
- sequential pub.dev acceptance, metadata, archive, and dependency-resolution
  checks after each publication;
- clean hosted native, Web, pure-Dart, Dio, Retrofit, package:http, Chopper,
  GraphQL HTTP, SSE, WebSocket, typed-generator, bounded OpenAPI, Protobuf,
  transform, and test consumers;
- hosted external example dependency/build/test gates;
- final format, analysis, documentation/link, dependency/security/path, and
  `git diff --check` checks for publication-owned changes only.

## Next Action

Finish the immediate pre-publication gate, then publish sequentially. Stop on
the first publication or hosted-resolution failure.

## Blockers

None currently.

## Outcome

In progress. Publication and hosted-consumer results will be appended after the
approved release sequence completes.

## References

- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/ALPHAX_1_0_FEATURE_FREEZE.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md`
- `docs/ALPHAX_1_0_RC_5_RELEASE_PREPARATION.md`
- `tasks/54-alphax-1-0-rc-5-release-preparation.md`

## History

- 2026-08-30: Created after explicit approval to publish the prepared
  `1.0.0-rc.5` release. No feature work, benchmark, tag, GitHub release, or
  stable publication is authorized.
