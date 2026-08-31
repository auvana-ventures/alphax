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

## Current release

AlphaX `1.1.0` is the next additive application-facade release built on the
stable 1.0 package family. Phase 0 research and transport validation remain
historical evidence; the current platform and package boundaries are documented
in the architecture overview and accepted ADRs. H3 remains provider- and
network-dependent with truthful fallback. Release work must preserve the frozen
low-level public API and must not turn historical evidence into a broader
capability claim.

## Package philosophy

The initial packages are:

- `alphax`: pure Dart, Flutter-independent contracts and client facade.
- `alphax_native`: platform transport boundary for Dart IO, Cronet, and
  URLSession.
- `alphax_dio`: optional focused Dio 5.x `HttpClientAdapter` boundary backed by
  an injected AlphaX client; it does not promise full Dio compatibility.
- `alphax_test`: deterministic transport and stream testing helpers.
- `alphax_web`: separate browser Fetch transport adapter with browser-owned
  protocol, CORS, TLS, proxy, and file-control limits.

Future packages must remain independently publishable, avoid circular dependencies,
and must not become mandatory dependencies of `alphax`. Do not create
`alphax_flutter` until Flutter-only integration exists.

## Architecture hypothesis

Phase 0 compared a sensible `dart:io` baseline with libcurl through a small C ABI
and a Rust HTTP stack through its C ABI. Those results remain historical
HTTP/1.1 evidence. AlphaX uses Android Cronet/HttpEngine and Apple
URLSession behind the transport-independent contract, with Dart IO as the
fallback/baseline. No C++ engine or production Rust transport is part of the
accepted architecture; introducing either would require separate evidence
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

The stable boundary does not include an offline queue, telemetry exporter,
complete DevTools extension, full Dio API compatibility, GraphQL framework
ownership, gRPC, a full OpenAPI compiler, custom QUIC/TLS controls, or a
model-specific authentication framework. The stable package family includes
the direct typed REST generator, SSE/WebSocket contracts, and the validated
compatibility seams described by the product documentation; those surfaces are
stable. The pure-Dart core includes
opt-in replay-aware retry, caller-owned token authentication, in-memory
cookies/cache, and a generic circuit breaker. The separate `alphax_web`
package provides browser Fetch support with unknown protocol metadata; it does
not change the native transport architecture. The focused `alphax_dio` adapter
is an optional boundary and full Dio parity remains out of scope.

## Source documents

- [Architecture overview](docs/architecture/overview.md)
- [Transport contract](docs/architecture/transport_contract.md)
- [Compatibility guide](docs/compatibility.md)
- [Architecture decisions](docs/decisions/)
- [Contributing guide](CONTRIBUTING.md)
