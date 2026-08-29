# Task 44 — AlphaX User Experience and Release Review

Status: [x] Completed

## Goal

Perform the final pre-publication user-experience, documentation, and transport
control review for the coordinated AlphaX 1.0.0-rc.4 release. Make the quickest
start, automatic behavior, portable policy controls, explicit transport seams,
provider boundaries, and package differences factual and immediately usable.

## Scope and Non-goals

In scope:

- Audit the actual exported interfaces of all six RC packages.
- Decide whether automatic transport selection is complete, needs a small
  correction, or is manual by design.
- Update current-facing README and user customization documentation.
- Add only the smallest pre-release API correction if the audited ergonomics
  cannot provide the approved automatic/custom transport experience.
- Compile-test important documentation examples and run release-oriented checks.
- Produce the final UX/release review report.

Out of scope:

- Publishing packages, tags, or GitHub releases.
- New transport architecture, performance work, protocol controls, or provider
  features.
- Benchmark reruns or changes to benchmark/mobile/signing evidence.
- FFI/shared buffers, a second transport engine, automatic response transforms,
  isolate pools, progress coalescing, or credit batching.
- Modifying the known pre-existing mobile/signing files or retained benchmark
  evidence.

## Owner

AlphaX maintainers / Codex implementation agent

## Dependencies

- AlphaX 1.0.0-rc.4 release-preparation state.
- `PROJECT_CONTEXT.md`, architecture overview, transport contract, relevant ADRs,
  package PRDs, and current package source/README files.
- Existing Task 42/43 release review evidence and known validation limitations.

## Assumptions

- The release remains 1.0.0-rc.4 unless a material pre-release API issue requires
  maintainer review of the version policy.
- Documentation must describe only exported, tested behavior.
- `alphax` remains pure Dart and transport-independent.
- The four pre-existing mobile/signing changes and all benchmark evidence are
  user-owned or intentionally retained and must not be staged.
- No package is published during this task.

## Work Items

- [x] Audit public constructors, factories, controls, defaults, capabilities,
  and custom transport seams across all six packages.
- [x] Decide and document the automatic transport-selection UX and any minimal
  correction required outside `alphax` core.
- [x] Reconcile root/package README content and create/update the user
  customization guide with factual recipes and matrices.
- [x] Add or update compile-tested documentation examples without widening
  package boundaries.
- [x] Review provider-specific controls, platform limitations, security wording,
  Dio/package:http comparisons, and client-reuse guidance.
- [x] Run release-oriented validation, package dry-runs, and archive inspection
  without publishing.
- [x] Create the final UX/release review report and record remaining blockers.
- [x] Commit and push only task-owned accepted changes after validation.

## Validation

Planned validation includes scoped formatting and analysis, all six package tests,
documentation example compilation/tests, conformance/policy/transform/Web checks,
Android profile/release build, macOS build, available iOS build gate, Dartdoc,
Markdown/link validation, package dry-runs and archive inspection, dependency and
security/signing/path audits, and `git diff --check`. Performance benchmarks are
not rerun.

## Next Action

Wait for explicit maintainer approval before publishing the six `1.0.0-rc.4`
packages. Do not create a tag or GitHub release as part of this task.

## Blockers

None at task start. Known non-blocking repository limitations remain documented in
Task 43 and must be preserved unless this task directly changes their scope.

## Outcome

The public API audit classified the existing ergonomics as
`AUTO_UX_NEEDS_SMALL_FIX`. A single boundary-local correction was implemented:
`alphax_native.createAlphaXTransport()` automatically selects Cronet/HttpEngine
on Android, URLSession on iOS/macOS, and Dart IO on other native targets. The
pure-Dart `alphax` core still requires transport injection, Web remains an
explicit `alphax_web` package choice, and custom `AlphaXTransport` injection is
preserved.

The root README, all six package READMEs, the user customization guide, current
architecture/policy/migration wording, compile-tested examples, and this review
report now describe the actual package/API boundaries, defaults, provider-owned
behavior, error/capability semantics, reuse guidance, and factual ecosystem
comparisons. No benchmark was rerun and no provider-specific control was added.

The task-owned validation passed. Six post-commit package dry-runs completed with
zero warnings and the final archive sizes were 54 KB, 12 KB, 94 KB, 11 KB,
15 KB, and 14 KB in package order (`alphax`, `alphax_test`, `alphax_native`,
`alphax_web`, `alphax_dio`, `alphax_transform`). Pre-existing
benchmark/mobile/signing work and historical evidence remain unstaged.

## References

- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/ALPHAX_1_0_RC_4_RELEASE_PREPARATION.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/prd/10_README_BLUEPRINT.md`
- `docs/USAGE_AND_CUSTOMIZATION.md`
- `docs/ALPHAX_USER_EXPERIENCE_AND_RELEASE_REVIEW.md`
- `packages/alphax_native/lib/src/alpha_x_transport_factory.dart`

## History

- 2026-08-29 — Task reserved and initialized for the approved final UX,
  documentation, and transport-control review.
- 2026-08-29 — Added and tested the boundary-local automatic native transport
  factory; reconciled current-facing documentation and package examples.
- 2026-08-29 — Completed package, example, Android, macOS, iOS-simulator,
  Dartdoc, dependency, link, Markdown, security/path, and diff validation.
- 2026-08-29 — Committed task-owned changes as `8813673`, `d8753c3`, and
  `2ab706e`, then recorded the final review metadata in `1080f29`; pushed all
  task-owned commits to `origin/main` and verified the remote matches HEAD.
