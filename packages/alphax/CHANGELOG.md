# Changelog

## 1.0.0-rc.5 - 2026-08-30

- Added the dedicated incremental `package:alphax/sse.dart` parser for
  bounded HTTP response streams, including standard event, ID, and retry
  semantics without automatic reconnect.
- Added the transport-neutral `package:alphax/websocket.dart` lifecycle
  contract for ordered text/binary messages, subprotocol negotiation, close
  information, and explicit cancellation without automatic reconnect.
- Added lightweight AlphaX annotations, request options, and typed response
  helpers used by the direct typed REST generator; generator tooling remains
  outside the core runtime dependency graph.

## 1.0.0-rc.4 - 2026-08-29

- Preserved file-transfer byte accounting and completion metrics while
  avoiding progress callback construction and invocation when the caller did
  not register a download or upload observer.

## 1.0.0-rc.3 - 2026-08-17

- Added a runnable package-local example showing a custom transport, request,
  response body, streaming events, and completion protocol metadata.
- Documented the in-memory cookie-jar constructor for complete API reference
  coverage.

## 1.0.0-rc.2 - 2026-08-17

- Corrected the theme-aware README logo URLs to absolute repository assets so
  pub.dev and other Markdown renderers load both SVG variants.

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
