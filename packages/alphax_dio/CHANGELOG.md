# Changelog

## 1.0.0-rc.1 - 2026-08-16

- Added `AlphaXDioAdapter`, a focused Dio 5.x `HttpClientAdapter` backed by an
  injected `AlphaXClient`.
- Mapped Dio request streams, headers, methods, cancellation, timeouts,
  redirects, progress, response streams, and normalized AlphaX errors.
- Exposed actual and completion-time protocol/metrics metadata through typed
  adapter keys and Dio's standard HTTP-version extra.
- Added deterministic adapter lifecycle, response-stream, cancellation,
  timeout, redirect, progress, and protocol tests.

### Known limitations

- This is not full Dio source/API compatibility. Dio interceptors and standard
  request/response transformation remain Dio-owned; AlphaX owns transport and
  policy behavior.
- TLS, trust anchors, SPKI pins, proxy policy, and middleware are configured on
  the injected `AlphaXClient`; the adapter does not invent per-request native
  policy controls.
- AlphaX 1.0 supports no Web transport, so this adapter does not make Web
  support available.
- No automatic retries, cookie jar, auth orchestration, cache, or resilience
  policy is included.
