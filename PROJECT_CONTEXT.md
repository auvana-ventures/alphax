# AlphaX Project Context

## Vision

AlphaX is an open-source, modular networking ecosystem for Dart and Flutter. It
aims to combine a strong Dart developer experience with evidence-backed native
transport, modern HTTP protocols, efficient streaming and file transfer,
observability, caching, and resilience.

## Positioning

AlphaX is not “Dio but faster.” Dio, `package:http`, and `dart:io` remain useful
baselines and adoption paths. AlphaX must earn differentiation through measured
transport behavior, low-copy large transfers, poor-network behavior, metrics, and
official modular capabilities.

## Current phase

Phase 0 is research and transport validation. The working project name is AlphaX;
the repository is `alphax`, but packages must not be published to pub.dev until
naming clearance is complete. No production native transport has been selected.

## Package philosophy

The initial packages are:

- `alphax`: pure Dart, Flutter-independent contracts and client facade.
- `alphax_native`: experimental native transport boundary.
- `alphax_dio`: future Dio adapter skeleton.
- `alphax_test`: deterministic transport and stream testing helpers.

Future packages must remain independently publishable, avoid circular dependencies,
and must not become mandatory dependencies of `alphax`. Do not create
`alphax_flutter` until Flutter-only integration exists.

## Architecture hypothesis

Phase 0 compares a sensible `dart:io` baseline with libcurl through FFI and a Rust
HTTP stack. The production choice is an experiment outcome, not a preference. A
Rust-plus-C++ production boundary requires measurable justification.

The public Dart API owns requests, responses, middleware, policy, decoding, and
application integration. Native code owns transport mechanisms, connection
management, protocol negotiation, low-level timings, and bounded streaming where
the selected implementation supports them.

## Engineering priorities

1. Measure before optimizing.
2. Keep the public contract transport-independent.
3. Minimize copies across FFI and distinguish minimal-copy from zero-copy accurately.
4. Make cancellation, ownership, shutdown, and backpressure deterministic.
5. Preserve secure TLS defaults and redact sensitive telemetry.
6. Treat tests, documentation, reproducible benchmarks, and binary size as product
   requirements.

Performance-sensitive architectural changes require an experiment and an ADR. Do
not change architecture based solely on preference.

## Explicit non-goals

Phase 0 does not implement a full cache, offline queue, circuit breaker, telemetry
exporter, complete DevTools extension, complete Dio adapter, GraphQL integration,
REST generation, production Cronet/URLSession transports, custom QUIC/TLS, or a
full authentication framework.

## Source documents

- [Product vision](docs/prd/01_PRODUCT_VISION.md)
- [Package architecture](docs/prd/02_REPOSITORY_PACKAGES.md)
- [Native transport](docs/prd/03_NATIVE_TRANSPORT.md)
- [API and Dio compatibility](docs/prd/04_API_DIO.md)
- [Phase 0 implementation specification](docs/prd/12_PHASE_0_IMPLEMENTATION_SPEC.md)
- [Architecture overview](docs/architecture/overview.md)
- [Architecture decisions](docs/decisions/)
