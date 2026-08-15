# alphax

Pure-Dart, transport-independent AlphaX 1.0 request, response, body, capability,
protocol, cancellation, metrics, file-transfer, middleware, and streaming
contracts.

Response protocol metadata is a headers-time snapshot. A transport may report
`AlphaXProtocol.unknown` until the operation completes; callers can await
`AlphaXResponse.completionMetrics` and `completionProtocolFallback` for
authoritative final metadata when the platform exposes negotiation only at
completion. `unknown` is never an implicit HTTP/1.1 or fallback result.

This package has no Flutter SDK dependency. Phase 1A is experimental API
stabilization; it does not implement Dart IO, Cronet, or URLSession. The package
is not published to pub.dev until AlphaX naming clearance and the 1.0 release gate
are complete.
