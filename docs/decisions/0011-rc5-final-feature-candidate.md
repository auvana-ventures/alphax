# ADR-0011: AlphaX 1.0.0-rc.5 Is the Final Feature Candidate

- Status: Accepted
- Date: 2026-08-30

## Context

AlphaX 1.0.0-rc.4 is published with six coordinated packages and a stable
transport architecture. Task 47 evaluated the next capability set and accepted
an additive Model A+ direction: preserve the pure-Dart `alphax` core and the
existing native/Web package boundaries, simplify ordinary entry points, and use
shared ecosystem seams instead of a package per feature.

Without an explicit release boundary, the remaining ecosystem ideas could keep
expanding the pre-1.0 scope and delay stabilization. The project needs one final
feature candidate before stable 1.0.0.

## Decision

AlphaX 1.0.0-rc.5 is the final release candidate permitted to introduce planned
1.0 features or additive public capability surfaces. Its exact scope is frozen
in [`ALPHAX_1_0_RC_5_SCOPE_LOCK.md`](../ALPHAX_1_0_RC_5_SCOPE_LOCK.md).

The committed rc.5 scope is:

- entry façades and package-role UX under Model A+;
- one broad `alphax_http` compatibility seam for `package:http` consumers;
- first-class SSE as an `alphax` sub-library;
- first-class WebSocket lifecycle contracts using maintained/provider APIs;
- one AlphaX-owned direct typed REST generator surface.

Bounded optional rc.5 work is limited to an OpenAPI Generator template proof,
Protobuf ergonomics, and representative ecosystem validation. Each is allowed
to be removed or deferred without creating an rc.6 feature backlog.

After rc.5, there is no rc.6 feature cycle. No new 1.0 feature discovery,
ecosystem expansion, package architecture, transport architecture, or
speculative performance work may be added. The project moves directly into
stable-1.0 stabilization.

Only the following work may change the code before stable:

- correctness fixes;
- security fixes;
- API consistency fixes required by the frozen surface;
- documentation corrections;
- packaging/build fixes;
- compatibility regressions;
- platform validation fixes.

If a stabilization fix requires another prerelease artifact, an `rc.5.x` or
later RC number may be produced only as a stabilization candidate. It must not
add feature scope or reopen capability discovery.

The sequence is:

```text
1.0.0-rc.4  published
     ↓
1.0.0-rc.5  final feature candidate
     ↓
stabilization-only verification
     ↓
1.0.0       stable
```

## Alternatives considered

- Keep discovering features until stable: rejected because it makes the 1.0
  boundary indefinite.
- Allow an rc.6 feature cycle: rejected by the release decision.
- Freeze only the core and continue adding ecosystem packages: rejected because
  package growth and integration scope are part of the product boundary.
- Move all proposed work to post-1.0: rejected because the additive UX,
  compatibility seam, and committed protocol surfaces are the final approved
  pre-stable feature set.

## Consequences

- Maintainers can remove bounded optional features when implementation cost or
  provider semantics are disproportionate without replacing them with new
  pre-stable scope.
- Every rc.5 task must reference the scope lock and remain independently
  reviewable.
- A newly discovered request is classified as `RELEASE_BLOCKING` or
  `POST_1_0`; it cannot enter rc.5 merely because it is useful.
- Once Tasks A–E and the bounded F–H decisions are resolved, the repository
  declares `ALPHAX 1.0 FEATURE FREEZE`.
- Stable 1.0 uses a release gate rather than another capability audit.
- gRPC, a full OpenAPI compiler, GraphQL framework ownership, core/package-role
  restructuring, advanced provider controls, and new performance/zero-copy
  work remain post-1.0 or explicitly rejected for rc.5.

## Evidence and revisit conditions

This decision is based on the accepted Task 47 architecture/ecosystem plan and
the current rc.4 architecture and release state. Revisit only for a documented
release-governance error or a stabilization issue that prevents a correct,
secure, compatible stable 1.0 release. A new feature request is not a reason to
reopen this ADR.

## Implementation evidence

Task 53 resolved the bounded optional scope without changing this decision:

- A complete — entry façades and package-role UX;
- B complete — `alphax_http` compatibility seam;
- C complete — first-class SSE;
- D complete — first-class WebSocket lifecycle contract;
- E complete — direct typed REST generator;
- F resolved — official OpenAPI Generator template proof accepted;
- G resolved — existing AlphaX byte APIs are sufficient for Protobuf;
- H resolved — bounded ecosystem compatibility validation completed.

The final evidence is in
[`ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md`](../ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md).
The resulting stable boundary is
[`ALPHAX_1_0_FEATURE_FREEZE.md`](../ALPHAX_1_0_FEATURE_FREEZE.md), which records
the prohibition on new features before `1.0.0` and the release-preparation-only
next step.

References:

- [`ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md`](../ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md)
- [`ALPHAX_1_0_RC_5_SCOPE_LOCK.md`](../ALPHAX_1_0_RC_5_SCOPE_LOCK.md)
- [`tasks/47-alphax-1-0-rc-5-architecture-and-ecosystem-plan.md`](../../tasks/47-alphax-1-0-rc-5-architecture-and-ecosystem-plan.md)
