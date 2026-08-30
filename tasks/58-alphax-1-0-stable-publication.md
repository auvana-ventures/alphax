# Task 58: AlphaX 1.0 stable publication

Status: [x] Completed

## Goal

Publish the approved AlphaX 1.0.0 package family sequentially, verify each
hosted artifact and dependency edge, validate clean hosted consumers, update
current examples after hosted validation, and create the approved stable tag
and GitHub release. No feature or runtime work is in scope.

## Scope and Non-goals

Scope is limited to publication of `alphax`, `alphax_test`, `alphax_native`,
`alphax_web`, `alphax_dio`, `alphax_transform`, `alphax_http`, and
`alphax_generator` at `1.0.0`; hosted verification; current example pin
updates; publication evidence; tag `v1.0.0`; and the `AlphaX 1.0.0` GitHub
release.

Non-goals are features, API redesign, benchmarks, post-1.0 work, dependency
freshness upgrades, package restructuring, release candidates, or changes to
the frozen runtime source.

## Owner

AlphaX maintainers / Codex implementation agent.

## Dependencies

- Accepted stable preparation at `53991e2519e82fc4fdedc64e8cc3eb782a2daa2f`.
- All eight packages prepared at `1.0.0`.
- Zero-warning stable dry-runs and release validation from Task 57.
- Pub.dev publication credentials and GitHub release credentials.

## Assumptions

- The approved publication order is `alphax`, `alphax_test`, `alphax_native`,
  `alphax_web`, `alphax_dio`, `alphax_transform`, `alphax_http`, then
  `alphax_generator`.
- Protected benchmark/mobile/history changes in the worktree remain untouched
  and unstaged.
- Windows remains `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE`.
- A failed or ambiguous immutable publication stops the sequence until hosted
  state is checked; no blind retry is allowed.

## Work Items

- [x] Reconfirm stable source, manifests, constraints, package set, and clean
  release-owned state.
- [x] Create Task 58 and establish the publication source commit.
- [x] Run immediate zero-warning dry-runs and inspect archives from the clean
  publication worktree.
- [x] Publish and verify each of the eight packages sequentially.
- [x] Run clean hosted stable consumers and bounded retained fixtures.
- [x] Update current examples to `^1.0.0` after hosted validation and verify
  their normal gates.
- [x] Create the successful publication report, stable tag, and GitHub release.
- [x] Complete this task with final provenance, hosted results, incidents, and
  the exact stable handoff.

## Validation

Immediate validation is limited to package manifests, dependency constraints,
zero-warning dry-runs, archive inspection, and security/path checks. After
publication, validation covers hosted metadata and dependency resolution,
clean native/Web/pure-Dart consumers, Dio/Retrofit, `package:http`/Chopper/
GraphQL HTTP, SSE, WebSocket, typed generator, bounded OpenAPI, Protobuf,
transform, test helpers, and current examples. No benchmarks are authorized.

## Next Action

Stop. AlphaX 1.0.0 stable publication and hosted verification are complete.

## Blockers

None at task creation.

## Outcome

All eight packages were published at `1.0.0`, hosted consumers passed, current
examples were moved to stable constraints, and the approved `v1.0.0` tag and
`AlphaX 1.0.0` GitHub release were created. The final state is
`ALPHAX 1.0.0 — STABLE RELEASED`.

## References

- `docs/ALPHAX_1_0_STABLE_VERSION_PREPARATION.md`
- `docs/ALPHAX_1_0_STABILIZATION_AND_RELEASE_GATE.md`
- `docs/ALPHAX_1_0_FEATURE_FREEZE.md`
- `docs/ALPHAX_1_0_RELEASE_NOTES.md`
- `docs/MIGRATION.md`
- `tasks/57-alphax-1-0-stable-version-preparation.md`

## History

- 2026-08-30: Created for the approved AlphaX 1.0.0 stable publication.
- 2026-08-30: Confirmed prepared source `53991e2`, stable manifests, and Task
  58 availability; protected unrelated work remains untouched.
- 2026-08-30: Published all eight stable packages sequentially from source
  `77be267`; verified hosted metadata, dependency resolution, archive hashes,
  and clean hosted consumers.
- 2026-08-30: Updated current `basic` and `waypoint` examples in separate
  commit `efccb5b` after hosted validation.
- 2026-08-30: Created annotated tag `v1.0.0` at `77be267` and published the
  `AlphaX 1.0.0` GitHub release.
- 2026-08-30: Completed the publication report and final provenance checks;
  GitHub release URL is
  `https://github.com/auvana-ventures/alphax/releases/tag/v1.0.0`; protected
  benchmark/mobile/history work remains untouched.
