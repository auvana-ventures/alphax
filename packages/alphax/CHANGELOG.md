# Changelog

## 1.0.0-rc.1 - 2026-08-17

- Stabilized the pure-Dart transport-independent request/response, body,
  stream, file, cancellation, timeout, redirect, middleware, capability,
  protocol, metrics, and normalized-error contracts.
- Added protocol preference/requirement, truthful fallback, TLS/trust/pinning,
  proxy, and opaque client-identity policy models.
- Added opt-in replay-aware retries, token authentication with single-flight
  challenge refresh, in-memory cookies, buffered HTTP caching, and generic
  circuit-breaker resilience middleware.
- Added the asynchronous `AlphaXCookieStore` abstraction with atomic
  `updateCookies`. The middleware owns cookie parsing/matching while
  `AlphaXCookieJar` remains a queued in-memory implementation; persistence
  remains caller-owned.
- Replaced the URI-only cache store with `AlphaXCacheKey`/
  `AlphaXCacheEntry` variant-aware storage. Added private-cache defaults,
  `Vary` selection, Cache-Control/Date/Age/Expires freshness, credential
  isolation, Set-Cookie exclusion, ETag/Last-Modified revalidation, 304
  metadata merging, bounded entry/byte limits, and mutation invalidation.
- Added HTTP-date `Retry-After` parsing with the existing bounded retry policy.
- Documented completion-time protocol metadata and intentional provider
  limitations.

No Flutter or native transport dependency is included in `alphax`.
