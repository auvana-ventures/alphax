# Changelog

## 1.0.0-rc.1 - 2026-08-16

- Stabilized the pure-Dart transport-independent request/response, body,
  stream, file, cancellation, timeout, redirect, middleware, capability,
  protocol, metrics, and normalized-error contracts.
- Added protocol preference/requirement, truthful fallback, TLS/trust/pinning,
  proxy, and opaque client-identity policy models.
- Added opt-in replay-aware retries, token authentication with single-flight
  challenge refresh, in-memory cookies, buffered HTTP caching, and generic
  circuit-breaker resilience middleware.
- Documented completion-time protocol metadata and intentional provider
  limitations.

No Flutter or native transport dependency is included in `alphax`.
