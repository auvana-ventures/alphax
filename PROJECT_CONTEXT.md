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

Phase 0 research and transport validation is complete. Phase 1A contracts, the
Dart IO fallback, the Phase 1C Android Cronet transport, the Phase 1D Apple
URLSession implementation, and the Phase 1E/1F release-gate evidence are
complete for `1.0.0-rc.1` maintainer review. Android, macOS, and signed
physical-iPhone H1/H2/H3 correctness evidence is retained; H3 remains
provider- and network-dependent with truthful fallback. ADR 0004 is accepted
for the AlphaX 1.0 platform strategy. The working project name is AlphaX; the
repository is `alphax`, but packages must not be published to pub.dev until
naming clearance and maintainer release approval are complete.

## Package philosophy

The initial packages are:

- `alphax`: pure Dart, Flutter-independent contracts and client facade.
- `alphax_native`: experimental native transport boundary.
- `alphax_dio`: optional focused Dio 5.x `HttpClientAdapter` boundary backed by
  an injected AlphaX client; it does not promise full Dio compatibility.
- `alphax_test`: deterministic transport and stream testing helpers.

Future packages must remain independently publishable, avoid circular dependencies,
and must not become mandatory dependencies of `alphax`. Do not create
`alphax_flutter` until Flutter-only integration exists.

## Architecture hypothesis

Phase 0 compared a sensible `dart:io` baseline with libcurl through a small C ABI
and a Rust HTTP stack through its C ABI. Those results remain historical
HTTP/1.1 evidence. AlphaX 1.0 uses Android Cronet/HttpEngine and Apple
URLSession behind the transport-independent contract, with Dart IO as the
fallback/baseline. No C++ engine or production Rust transport is part of the
accepted 1.0 architecture; introducing either would require separate evidence
and an accepted ADR.

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

The current RC does not include an offline queue, telemetry exporter, complete
DevTools extension, full Dio API compatibility, GraphQL integration, REST
generation, custom QUIC/TLS, or a full model-specific authentication framework.
The pure-Dart core now includes opt-in replay-aware retry, caller-owned token
authentication, in-memory cookies/cache, and a generic circuit breaker. The
separate `alphax_web` package provides browser Fetch support with unknown
protocol metadata; it does not change the native transport architecture. The
focused `alphax_dio` adapter is an optional 1.0 boundary and full Dio parity
remains out of scope.

## Source documents

- [Product vision](docs/prd/01_PRODUCT_VISION.md)
- [Package architecture](docs/prd/02_REPOSITORY_PACKAGES.md)
- [Native transport](docs/prd/03_NATIVE_TRANSPORT.md)
- [API and Dio compatibility](docs/prd/04_API_DIO.md)
- [Phase 0 implementation specification](docs/prd/12_PHASE_0_IMPLEMENTATION_SPEC.md)
- [Architecture overview](docs/architecture/overview.md)
- [Architecture decisions](docs/decisions/)
