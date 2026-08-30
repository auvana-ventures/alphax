# AlphaX 1.0

AlphaX 1.0 is the stable package line prepared from the published 1.0.0-rc.5
candidate. The source tree contains the final stable metadata; package
publication is a separate release action.

## What AlphaX is

AlphaX is a transport-independent Dart HTTP client contract and policy layer.
Applications choose a deployment package or provide a custom
`AlphaXTransport`; the core does not require a particular networking engine.

## Platform-native networking

`alphax_native` provides the native Flutter entry façade and selects the
existing platform transport. Android uses the available Cronet/HttpEngine
provider, Apple platforms use URLSession, and Linux/Windows use the Dart IO
fallback. `alphax_web` provides the browser Fetch entry façade.

## Protocol visibility

Android and Apple providers may negotiate H1, H2, or H3 according to the
provider, operating system, server, proxy, and network. AlphaX reports the
actual protocol and fallback metadata where the provider can authoritatively
report them. Protocol preference may fall back; protocol requirements fail
closed. Dart IO is an H1-only fallback, and browser protocol details remain
browser-owned.

## Security and policy

Secure platform TLS defaults, host-scoped pinning where supported, explicit
proxy policy, authentication middleware, cookies, caching, retries, and
resilience are composed through the frozen AlphaX client and transport
contracts. Unsupported security or proxy controls fail honestly rather than
silently weakening the request.

## Streaming and files

AlphaX supports bounded response streaming, cancellation, multipart/file
transfers, and native file paths where the selected provider exposes them.
Progress is opt-in. `alphax_transform` remains an optional explicit one-shot
transform for already-buffered JSON payloads.

## SSE and WebSocket

`package:alphax/sse.dart` provides an incremental SSE parser over an existing
AlphaX HTTP response stream. It surfaces data, event, ID, and retry fields;
reconnection and `Last-Event-ID` policy remain caller-owned.

`package:alphax/websocket.dart` provides a separate transport-neutral connector
and session lifecycle for ordered text and binary messages, subprotocols, and
close information. WebSocket connections do not automatically reconnect,
replay, or expose universal provider-specific controls.

## Ecosystem compatibility

- Direct AlphaX, the native/Web façades, HTTP contracts, SSE, WebSocket, and
  the direct typed REST generator are `FIRST_CLASS` AlphaX capabilities.
- Dio, Retrofit through Dio, `package:http`, Chopper, GraphQL HTTP, and the
  validated injectable OpenAPI Dio/HTTP paths are
  `SUPPORTED_VIA_ADAPTER`.
- `json_serializable`, Freezed, and Protobuf are
  `COMPATIBLE_CALLER_LAYER` integrations. Protobuf is used as serialization;
  it is not gRPC.
- The direct OpenAPI template and GraphQL WebSocket/subscription caller bridge
  are `PROOF_ONLY`.
- gRPC is `DEFERRED_POST_1_0`.

## Typed REST generation

`alphax_generator` is development-time tooling for direct typed REST clients.
Generated code calls `AlphaXClient` directly, borrows its lifecycle, and keeps
model serialization caller-owned. It does not require Dio or `package:http` at
runtime. The OpenAPI integration remains a bounded template proof, not a full
OpenAPI SDK generator.

## Testing and transforms

`alphax_test` provides deterministic fakes and conformance helpers for tests.
`alphax_transform` is optional and performs explicit one-shot native isolate
transforms; it does not add a worker pool or automatic buffering threshold.

## Supported platforms

| Platform | Stable boundary |
| --- | --- |
| Android | Cronet/HttpEngine provider; H1/H2/H3 are provider and network dependent |
| iOS | URLSession; H1/H2/H3 are provider and network dependent |
| macOS | URLSession; H1/H2/H3 are provider and network dependent |
| Linux | Dart IO H1 fallback |
| Windows | Dart IO H1 fallback; `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE` |
| Web | Browser Fetch/WebSocket; TLS, CORS, proxy, origin, and protocol behavior remain browser-owned |

## Known boundaries

Protocol capabilities and buffering differ by provider. Browser WebSocket
headers, TLS, CORS, proxy, origin, and connection behavior are browser-owned.
The direct OpenAPI integration is proof-only; GraphQL WebSocket is a
caller-bridge proof. Protobuf interoperability does not imply gRPC support.
SSE and WebSocket reconnection, replay, and backoff are not automatic.
Provider-specific header, ping/pong, frame, message-size, and queue limits
remain provider concerns.

## Migrating from rc.5

If an application already uses `1.0.0-rc.5`, update the coordinated package
constraints to `1.0.0` after stable publication. No API or source migration is
required.
