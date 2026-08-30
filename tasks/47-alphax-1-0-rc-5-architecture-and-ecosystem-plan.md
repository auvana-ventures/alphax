# Task 47 — AlphaX 1.0.0-rc.5 Architecture and Ecosystem Plan

Status: [x] Completed

## Goal

Define a bounded rc.5 architecture and ecosystem scope that makes AlphaX feel like
one networking library for ordinary users while preserving the rc.4 transport
boundaries and avoiding premature implementation of the requested integrations.

## Scope and Non-goals

Scope:

- audit the published rc.4 package graph and public entry points;
- evaluate package simplification models and migration timing;
- assess direct typed REST, OpenAPI, package:http, Chopper, Protobuf, SSE,
  WebSocket, GraphQL, and gRPC seams;
- compare the proposed direction with Dio and maintained ecosystem packages;
- classify rc.5 scope tiers and define a dependency-aware implementation sequence;
- update the roadmap with the approved planning direction.

Non-goals:

- no rc.5 version changes or publication;
- no package creation, renaming, moving, or deprecation;
- no WebSocket, SSE, code-generation, OpenAPI, gRPC, or adapter implementation;
- no transport architecture change, benchmark cycle, or performance experiment;
- no tag or GitHub release.

## Owner

AlphaX maintainers / Codex architecture review.

## Dependencies

- Published AlphaX 1.0.0-rc.4 package graph and public APIs.
- Existing transport contracts, ADRs, package READMEs, and release documentation.
- Current official/upstream Dart, Flutter, Dio, Retrofit, Chopper, OpenAPI,
  protobuf, GraphQL, and gRPC documentation.

## Assumptions

- rc.4 package names and imports remain compatible while rc.5 is planned.
- `alphax` remains pure Dart and transport-independent unless a future approved
  architecture decision explicitly changes that boundary.
- Existing native transports remain Cronet/HttpEngine on Android and URLSession
  on Apple platforms; no replacement engine is in scope.
- The current working tree contains protected pre-existing benchmark/signing work;
  it must remain untouched.

## Work Items

- [x] Audit rc.4 package roles, dependencies, exports, and user installation paths.
- [x] Research official ecosystem seams and platform/dependency constraints.
- [x] Evaluate package simplification and stable-1.0 migration strategy.
- [x] Define rc.5 capability architecture, scope tiers, and task sequence.
- [x] Write the architecture/ecosystem report and update the roadmap proposal.
- [x] Review the task-owned diff and run documentation/link validation.

## Validation

Completed validation was read-only and documentation-focused:

- inspect package manifests and public exports;
- verify cited upstream sources and distinguish documented facts from inference;
- run Markdown/internal-link validation if available;
- run `markdownlint` for the task-owned Markdown;
- run a trailing-whitespace check and `git diff --check` for task-owned changes;
- confirm no production package, benchmark, or protected mobile/signing file is
  modified.

## Next Action

The architecture recommendation has been approved by the maintainer. The final
feature-RC governance and exact rc.5 scope are recorded separately in
`docs/decisions/0011-rc5-final-feature-candidate.md` and
`docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`.

## Blockers

None. Implementation remains separately gated by the accepted scope lock.

## Outcome

`APPROVED WITH FINAL FEATURE RC LOCK`. The maintainer approved Model A+:
preserve the rc.4 package graph, add native/Web entry façades, and use one broad
`package:http` compatibility seam, one dev-time generator surface, and protocol
sub-libraries instead of a package per feature. The approved release scope and
no-rc.6 rule are now authoritative in the final-feature ADR and scope-lock
document.

## References

- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- `docs/decisions/0003-public-api-transport-independence.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/roadmap.md`
- `packages/*/pubspec.yaml`
- Official source index in `docs/ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md`

## History

- 2026-08-30: Reserved Task 47 for rc.5 architecture and ecosystem planning.
- 2026-08-30: Completed source audit, upstream research, architecture report,
  roadmap proposal, and Markdown validation. Awaiting maintainer review; no
  production package changes were made.
- 2026-08-30: Maintainer approved Model A+ and locked rc.5 as the final feature
  candidate before stable 1.0. Scope governance is recorded separately; no
  implementation was started.
