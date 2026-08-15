# AlphaX

AlphaX is an experimental networking engine for Dart and Flutter
focused on efficient transport, modern HTTP protocols, streaming, observability,
and resilience.

## Status

**Phase 1E cross-transport validation in progress.** Phase 1D Apple transport
and signed iPhone correctness validation are complete. AlphaX remains
experimental and pre-release; its API may change. Packages are not intended for production adoption
or pub.dev publication until AlphaX naming clearance and the 1.0 release gate are
complete.

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
transport implementation selected by the accepted 1.0 platform strategy
      │
      ├── Dart IO fallback/baseline
      ├── Android Cronet/HttpEngine (Phase 1C)
      └── iOS/macOS URLSession (Phase 1D)
```

The public contract is transport-independent. Large transfers should prefer bounded
native buffers and direct native-to-file paths where the selected platform transport
supports them. No C++ engine or production Rust transport is part of the accepted
1.0 architecture. See [architecture documentation](docs/architecture/overview.md).

## Package map

| Package | Purpose | Current status |
| --- | --- | --- |
| [`alphax`](packages/alphax) | Pure Dart request/response, transport, cancellation, metrics, and error contracts | In development |
| [`alphax_native`](packages/alphax_native) | Platform transport integration boundary, Dart IO fallback, Android Cronet, and Apple URLSession adapters | Android, iOS, and macOS correctness validated; Phase 1E release parity in progress |
| [`alphax_dio`](packages/alphax_dio) | Future Dio `HttpClientAdapter` compatibility layer | Documentation/skeleton only |
| [`alphax_test`](packages/alphax_test) | Deterministic fake transports and test helpers | In development |

Future packages such as Flutter lifecycle integration, caching, resilience,
DevTools, OpenTelemetry, and offline replay will be added only when their concrete
contracts and dependencies are justified.

## Feature status

| Capability | Status |
| --- | --- |
| Transport-independent Dart API | Phase 1A complete |
| HTTP/1.1, HTTP/2, HTTP/3 | 1.0 platform goal; Android Cronet and Apple URLSession evidence retained; final cross-transport release validation in progress |
| Streaming and backpressure | Dart fallback; Android and Apple bounded delivery validated on available targets |
| Direct file transfer | Dart fallback; Android and Apple native paths validated on available targets |
| Dio/Retrofit compatibility | Optional/post-1.0 scope; not implemented |
| Cache and resilience modules | Deferred by 1.0 scope |
| Observability and OpenTelemetry | Deferred by 1.0 scope |

## Quick start

There is no released AlphaX package or stable installation command yet. During
Phase 1D, use the workspace packages directly and treat the API as experimental.
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

| Target | 1.0 direction | Current implementation |
| --- | --- | --- |
| macOS | URLSession-backed transport | Phase 1D correctness validated |
| Linux | Dart IO fallback initially | Phase 1B implemented |
| Android | Cronet/HttpEngine-backed transport | Phase 1C Android 15 verified |
| iOS | URLSession-backed transport | H1/H2/H3 and signed-device correctness validated |
| Windows | Dart IO fallback initially | Phase 1B implemented |
| Web | Where capabilities permit | Explicitly outside current implementation |

The pure-Dart `alphax` package has no Flutter SDK dependency. Platform support is
claimed only after CI builds and tests the relevant implementation.

## Security

TLS verification is secure by default in the intended transports. Explicit proxy
configuration, certificate pinning, and mTLS remain unsupported in the current
adapters; redaction, dependency updates, and reporting guidance are tracked in
[SECURITY.md](SECURITY.md).

## Roadmap

See [docs/roadmap.md](docs/roadmap.md) and the source [PRDs](docs/prd/).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md),
and the relevant architecture documents before making transport or public API
changes.

## License

Apache-2.0. See [LICENSE](LICENSE).
