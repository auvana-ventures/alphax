# alphax

Pure-Dart, transport-independent AlphaX 1.0 request, response, body, capability,
protocol, cancellation, metrics, file-transfer, middleware, and streaming
contracts.

The core also defines immutable protocol requirement, TLS, trust-anchor, SPKI
pin, proxy, and opaque client-identity policy models. Adapters must report
unsupported policy controls honestly; no core API accepts a trust-all callback
or exposes native networking types.

Response protocol metadata is a headers-time snapshot. A transport may report
`AlphaXProtocol.unknown` until the operation completes; callers can await
`AlphaXResponse.completionMetrics` and `completionProtocolFallback` for
authoritative final metadata when the platform exposes negotiation only at
completion. `unknown` is never an implicit HTTP/1.1 or fallback result.

This package has no Flutter SDK dependency. It does not implement Dart IO,
Cronet, or URLSession. The package is not published to pub.dev until AlphaX
naming clearance and the 1.0 release gate are complete.
