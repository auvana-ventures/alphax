# Changelog

## 1.0.0-rc.1 - 2026-08-17

- Stabilized the transport-independent Dart API for requests, responses,
  headers, bodies, streams, files, middleware, cancellation, timeouts,
  redirects, metrics, capabilities, and normalized errors.
- Added Android Cronet/HttpEngine, Apple URLSession, and Dart IO fallback
  transport boundaries without changing the accepted architecture.
- Documented H1/H2/H3 support on Android, iOS, and macOS through supported
  native providers, Linux and Windows H1-only Dart IO fallback, and the
  separate `alphax_web` browser Fetch adapter with truthful browser limits.
- Added truthful negotiated-protocol and fallback reporting, plus fail-closed
  protocol requirements.
- Retained bounded streaming/backpressure, native-capable file transfers,
  cancellation, timeout, redirect, TLS policy/pinning, proxy policy, and
  testing/conformance utilities.
- Added the optional `alphax_dio` Dio 5.x `HttpClientAdapter` boundary backed by
  an injected `AlphaXClient`, with focused request, response, cancellation,
  progress, and protocol metadata compatibility.
- Added migration, security, platform-capability, and RC review documentation.
- Added the asynchronous `AlphaXCookieStore` seam with atomic `updateCookies`,
  queued in-memory cookie behavior, and caller-owned persistence.
- Replaced URI-only caching with a private variant-aware cache contract covering
  method/URI/Vary keys, conservative freshness metadata, validators, 304
  merging, credential isolation, Set-Cookie exclusion, bounded storage, and
  mutation invalidation.
- Added HTTP-date `Retry-After` parsing while retaining bounded replay-safe
  retry defaults.

### Known limitations

- H3 is provider-, server-, proxy-, and network-dependent; a preference may
  fall back, while a requirement fails closed.
- Linux and Windows use H1-only Dart IO fallback. Web is available through the
  separate `alphax_web` Fetch adapter; browser protocol metadata and native
  security/network controls remain browser-owned.
- mTLS, uniform Android custom trust anchors, Dart IO SPKI pinning, and
  explicit HTTPS-proxy endpoint parity are not implemented uniformly.
- CocoaPods is the Apple packaging path; Swift Package Manager is deferred.
- `alphax_dio` is a focused adapter boundary, not full Dio API compatibility;
  `alphax_web` is a separate browser adapter and does not provide native
  protocol, TLS, proxy, or file-control parity.

No unsupported performance claim is made, and no package is published by this
change.
