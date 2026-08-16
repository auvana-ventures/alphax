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
Cronet, or URLSession. The `1.0.0-rc.1` candidate is prepared for maintainer
review and is not published until naming clearance and release approval are
complete.
