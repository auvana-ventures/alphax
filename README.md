# AlphaX

AlphaX is an experimental, high-performance networking engine for Dart and Flutter
focused on efficient transport, modern HTTP protocols, streaming, observability,
and resilience.

## Status

**Phase 0 — research and transport validation.** AlphaX is pre-release, not
production-ready, and its API may change. Packages are not intended for production
adoption or pub.dev publication until AlphaX naming clearance and the transport
architecture review are complete.

## Why this exists

AlphaX explores whether a carefully designed native transport can improve streaming,
large file transfers, poor-network behavior, memory usage, and observability while
preserving a pleasant Dart API. It complements rather than dismisses `dart:io`,
`package:http`, and Dio; benchmark evidence will determine where it is useful.

## What it is and is not

AlphaX is a modular networking engine with a transport-independent Dart contract.
It is not currently a GraphQL framework, REST generator, database, state manager,
full synchronization platform, VPN, custom TLS/QUIC implementation, or analytics
SDK.

## Architecture

```text
Dart application
      │
      ▼
alphax (pure Dart contracts and client facade)
      │
      ▼
transport implementation selected by Phase 0 evidence
      │
      ├── dart:io baseline
      ├── libcurl through FFI prototype
      └── Rust HTTP prototype
```

The public contract is transport-independent. Large transfers should prefer bounded
native buffers and direct native-to-file paths where the selected transport supports
them. See [architecture documentation](docs/architecture/overview.md).

## Package map

| Package | Purpose | Phase 0 status |
| --- | --- | --- |
| [`alphax`](packages/alphax) | Pure Dart request/response, transport, cancellation, metrics, and error contracts | In development |
| [`alphax_native`](packages/alphax_native) | Experimental native transport boundary | Skeleton only |
| [`alphax_dio`](packages/alphax_dio) | Future Dio `HttpClientAdapter` compatibility layer | Documentation/skeleton only |
| [`alphax_test`](packages/alphax_test) | Deterministic fake transports and test helpers | In development |

Future packages such as Flutter lifecycle integration, caching, resilience,
DevTools, OpenTelemetry, and offline replay will be added only when their concrete
contracts and dependencies are justified.

## Feature status

| Capability | Status |
| --- | --- |
| Transport-independent Dart API | In development |
| HTTP/1.1, HTTP/2, HTTP/3 | Experimental/planned; transport validation required |
| Streaming and backpressure | Contract under review |
| Direct file transfer | Planned for transport prototype evaluation |
| Dio/Retrofit compatibility | Planned; not implemented in Phase 0 |
| Cache and resilience modules | Planned; deferred |
| Observability and OpenTelemetry | Planned; deferred |

## Quick start

There is no released AlphaX package or stable installation command yet. During
Phase 0, use the workspace packages directly and treat the API as experimental.
Only released APIs will be documented here after the transport decision.

## Dio and Retrofit

The planned adoption path is an `alphax_dio` adapter that preserves normal Dio
options, interceptors, cancellation, `FormData`, progress, streams, and Retrofit
generated clients. The adapter is intentionally not implemented until the transport
lifecycle is validated.

## Performance

AlphaX makes no unsupported speed or “zero-copy” claims. Benchmarks compare
`dart:io`, Dio, `package:http`, libcurl/FFI, and Rust candidates under documented
conditions. Methodology, raw results, and environment metadata will be linked from
[the benchmark documentation](docs/benchmarks.md).

## Platform and protocol matrix

| Target | Phase 0 | Long-term intent |
| --- | --- | --- |
| macOS | Native prototypes and CI | Supported |
| Linux | Native prototypes and CI | Supported |
| Android | Deferred | Supported after transport selection |
| iOS | Deferred | Supported after transport selection |
| Windows | Deferred | Supported after transport selection |
| Web | Deferred | Where capabilities permit |

The pure-Dart `alphax` package has no Flutter SDK dependency. Platform support is
claimed only after CI builds and tests the relevant implementation.

## Security

TLS verification is secure by default in the intended transports. Certificate
pinning, mTLS, proxy support, redaction, dependency updates, and reporting guidance
are tracked in [SECURITY.md](SECURITY.md).

## Roadmap

See [docs/roadmap.md](docs/roadmap.md) and the source [PRDs](docs/prd/).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md),
and the relevant architecture documents before making transport or public API
changes.

## License

Apache-2.0. See [LICENSE](LICENSE).
