# Compatibility

AlphaX `1.0.0` is the current stable release. The `alphax` package targets Dart
`>=3.8.0 <4.0.0` and has no Flutter SDK constraint. Choose the deployment
package for the platform, then add an adapter or tooling package only when the
application needs that integration.

## Platform support

The 1.0 platform strategy is:

- Android API 24+: Cronet/HttpEngine provider, H1/H2/H3 where the selected
  provider and network path support them;
- iOS 15+ and macOS 12+: Foundation URLSession, H1/H2/H3 where the OS and
  network path support them;
- Linux and Windows: Dart IO H1 fallback;
- Web: use the separate `alphax_web` Browser Fetch adapter. Ordinary HTTP is
  supported, but browser protocol metadata is unknown and concrete protocol
  requirements fail closed.

Protocol capability, request preference, actual negotiated protocol, and
fallback are separate values. H3 preference does not guarantee H3 use.

Dio `HttpClientAdapter` compatibility is implemented as a focused
`alphax_dio` boundary over an injected `AlphaXClient`. It is not full Dio API
compatibility; existing Retrofit clients remain on their normal Retrofit → Dio
→ adapter path.

`alphax_http` provides a `package:http` `BaseClient` seam for Chopper, GraphQL
HTTP, and other libraries that accept an injected client. `alphax_generator`
emits direct AlphaX typed REST clients as development tooling. The bounded
OpenAPI template integration is proof-only, not a full OpenAPI SDK generator.

## Caller-layer compatibility

Serialization remains caller-owned. `json_serializable`, Freezed, and Protobuf
can provide model encoding/decoding through AlphaX byte and JSON bodies;
Protobuf interoperability does not imply gRPC support. SSE and WebSocket are
first-class AlphaX contracts, but neither automatically reconnects or replays
messages. GraphQL WebSocket integration remains a caller-owned bridge.

## Compatibility principles

- Preserve normal Dio options, interceptors, cancellation, `FormData`, progress,
  streams, and Retrofit-generated clients where the focused adapter supports
  them.
- Do not require native code for ordinary `alphax` contract tests.
- Do not claim a protocol or provider capability that the selected platform
  does not report.
- Treat transport-specific features as optional capabilities rather than inventing
  unsupported metrics or semantics.
