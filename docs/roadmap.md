# Roadmap

The definitive AlphaX 1.0 scope and implementation sequence are maintained in
[`ALPHAX_1_0_SCOPE.md`](ALPHAX_1_0_SCOPE.md).

That document defines the only valid 1.0 classifications, required release
gate, package changes, and Phase 1A–1F exit criteria. This roadmap page is kept
as a navigation entry point so older phase labels cannot contradict the 1.0
scope.

Historical Phase 0 benchmark evidence remains under
[`benchmarks/results/summaries`](../benchmarks/results/summaries/). It is not
rewritten by the 1.0 scope or transport ADR.

## Post-1.0 extension track

The optional `alphax_transform` package provides explicit one-shot native
isolate JSON transformation for already-buffered payloads. It is independently
publishable and does not change the 1.0 transport architecture or add automatic
thresholds, streaming parsing, or persistent workers. Its measured guidance
and limitations are recorded in
[`ALPHAX_TRANSFORM_EXTENSION_IMPLEMENTATION.md`](ALPHAX_TRANSFORM_EXTENSION_IMPLEMENTATION.md).

## AlphaX 1.0.0-rc.5 final feature candidate

AlphaX 1.0.0-rc.5 is the final feature release candidate before stable 1.0.0.
There will be no rc.6 feature cycle. After rc.5 publication, the project moves
directly into stable-1.0 stabilization.

The accepted Model A+ architecture keeps `alphax` pure Dart and
transport-independent, preserves the rc.4 package boundaries, and simplifies
ordinary native/Web setup through existing integration-package façades. It does
not create a universal Flutter-aware umbrella, split `alphax_core`, add a
package per feature, or introduce another networking engine.

### Locked rc.5 scope

Must-have:

1. entry façades and package-role UX;
2. one `alphax_http` compatibility seam for `package:http` consumers.

Committed features:

1. first-class SSE sub-library;
2. first-class WebSocket lifecycle contract;
3. direct AlphaX typed REST generator.

Bounded optional work:

1. official OpenAPI Generator template proof;
2. Protobuf ergonomics without a core runtime dependency;
3. representative Chopper, GraphQL, and generated-client compatibility fixtures.

gRPC, a full OpenAPI compiler, GraphQL framework ownership, package-role
restructuring, advanced provider controls, and new performance/zero-copy work
remain post-1.0. Features may be removed from rc.5 when evidence shows that they
would delay stable 1.0 disproportionately; removal does not create an rc.6
backlog. New discoveries are release-blocking only when required for correctness,
security, frozen API coherence, or an already-approved rc.5 feature.

When the locked rc.5 work and bounded decisions are resolved, declare
`ALPHAX 1.0 FEATURE FREEZE`. The stable release then uses one release gate for
API, correctness, supported platforms, security, ecosystem fixtures, and
packaging. No capability-discovery cycle or open-ended feature queue continues
before stable.

See the [rc.5 scope lock](ALPHAX_1_0_RC_5_SCOPE_LOCK.md),
[ADR-0011](decisions/0011-rc5-final-feature-candidate.md), and
[post-1.0 roadmap](POST_1_0_ROADMAP.md).
