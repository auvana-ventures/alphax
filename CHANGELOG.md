# Changelog

## 1.0.0-rc.1 - 2026-08-16

- Stabilized the transport-independent Dart API for requests, responses,
  headers, bodies, streams, files, middleware, cancellation, timeouts,
  redirects, metrics, capabilities, and normalized errors.
- Added Android Cronet/HttpEngine, Apple URLSession, and Dart IO fallback
  transport boundaries without changing the accepted architecture.
- Documented H1/H2/H3 support on Android, iOS, and macOS through supported
  native providers, with Linux and Windows H1-only Dart IO fallback and Web
  unsupported in 1.0.
- Added truthful negotiated-protocol and fallback reporting, plus fail-closed
  protocol requirements.
- Retained bounded streaming/backpressure, native-capable file transfers,
  cancellation, timeout, redirect, TLS policy/pinning, proxy policy, and
  testing/conformance utilities.
- Added migration, security, platform-capability, and RC review documentation.

### Known limitations

- H3 is provider-, server-, proxy-, and network-dependent; a preference may
  fall back, while a requirement fails closed.
- Linux and Windows use H1-only Dart IO fallback; Web is unsupported.
- mTLS, uniform Android custom trust anchors, Dart IO SPKI pinning, and
  explicit HTTPS-proxy endpoint parity are not implemented uniformly.
- CocoaPods is the Apple packaging path; Swift Package Manager is deferred.

No unsupported performance claim is made, and no package is published by this
change.
