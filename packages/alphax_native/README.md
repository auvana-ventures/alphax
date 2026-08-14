# alphax_native

Platform transport integration boundary for AlphaX, including the Phase 1B
Dart IO fallback.

`DartIoTransport` uses one reusable `dart:io` `HttpClient` and implements the
transport-neutral AlphaX contract for the HTTP/1.1 fallback path. It provides
progressive Dart-streamed request/response and file transfers, cancellation,
timeouts, redirects, normalized errors, and secure platform TLS defaults.

The Dart IO adapter does not claim HTTP/2, HTTP/3, configurable proxy behavior,
certificate pinning, mTLS, background transfer, or native file-backed transfer.
Its actual negotiated protocol is unavailable from the Dart IO API and is
reported as `unknown`; no H2/H3 support is inferred from capability metadata.

Cronet/HttpEngine and URLSession work remains deferred to later approved phases.
This package must not leak Cronet, URLSession, FFI, C++, libcurl, or Rust types
into `alphax`.
