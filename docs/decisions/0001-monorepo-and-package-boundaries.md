# ADR-0001: Monorepo and Package Boundaries

- Status: Accepted for Phase 0
- Date: 2026-08-12

## Context

AlphaX is intended to become a modular Dart and Flutter networking ecosystem. The
transport contract, native implementation, compatibility adapter, and test helpers
have different dependencies and release concerns.

## Decision

Use a public Melos/Dart workspace repository named `alphax` with these initial
packages:

- `alphax`: pure Dart public contract and client facade.
- `alphax_native`: experimental native boundary.
- `alphax_dio`: future Dio compatibility adapter skeleton.
- `alphax_test`: deterministic testing helpers.

Use Apache-2.0 licensing. Do not create `alphax_flutter` or future optional modules
until concrete Flutter-only or module-specific integration exists.

## Consequences

Packages can be validated and evolved independently without forcing Flutter or a
native dependency into the core. The repository carries more metadata and requires
dependency-boundary discipline. Packages remain unpublished until AlphaX naming
clearance and architecture review are complete.

## Revisit conditions

Revisit package boundaries when a concrete dependency, platform lifecycle concern,
or release cadence cannot be isolated without creating a new package.
