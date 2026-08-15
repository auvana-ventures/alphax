# alphax_native

Platform transport integration boundary for AlphaX, including the Phase 1B
Dart IO fallback, the Phase 1C Android Cronet adapter, and the Phase 1D Apple
URLSession adapter.

`DartIoTransport` uses one reusable `dart:io` `HttpClient` and implements the
transport-neutral AlphaX contract for the HTTP/1.1 fallback path. It provides
progressive Dart-streamed request/response and file transfers, cancellation,
timeouts, redirects, normalized errors, and secure platform TLS defaults.

The Dart IO adapter does not claim HTTP/2, HTTP/3, configurable proxy behavior,
certificate pinning, mTLS, background transfer, or native file-backed transfer.
Its actual negotiated protocol is unavailable from the Dart IO API and is
reported as `unknown`; no H2/H3 support is inferred from capability metadata.

`AndroidCronetTransport.create()` selects one reusable provider-backed engine.
Google Play Services Cronet is preferred when available; the Android platform
provider may be selected on supported API levels. If the host application also
supplies a Java/fallback Cronet provider, it is reported as HTTP/1.1-only. The
adapter never silently advertises HTTP/2 or HTTP/3 when the selected provider
cannot provide them. Actual negotiated protocol is reported per response and
may be lower than the requested preference.

The Android adapter keeps response delivery behind a four-credit, 64 KiB native
read window and supports native file-backed upload/download for
`AlphaXLocalFileSource` and `AlphaXLocalFileTarget`. TLS verification uses
platform defaults; proxy configuration, certificate pinning, mTLS, background
transfer, and connection-migration controls are not advertised by this
adapter.

The Android adapter completed Phase 1C physical-device validation, including
actual H3 negotiation and truthful H3 fallback reporting. The Apple adapter is
implemented for iOS 15+ and macOS 12+ using Foundation URLSession; macOS
correctness validation covers H1/H2/H3, fallback, streaming, cancellation,
TLS rejection, progress, and native file paths. Physical iPhone validation is
still required before the Phase 1E release-validation gate can make an Apple
H3 support claim. This package must not leak Cronet, URLSession, FFI, C++,
libcurl, or Rust types into `alphax`.

Apple `send()` responses expose headers-time metadata. URLSession task metrics
are authoritative only when the operation completes, so callers must await
`AlphaXResponse.completionMetrics` and `completionProtocolFallback` instead of
treating an initial `unknown` protocol as H1 or fallback. `sendStreaming()`
exposes the same final metrics and fallback metadata in
`AlphaXResponseCompleted`.

Apple uses `URLSessionConfiguration.default`, so system-managed proxy settings
are inherited. AlphaX does not expose explicit per-session proxy configuration
or proxy credentials, and the adapter reports proxy configuration as
unsupported. URLSession owns HTTP CONNECT and any platform proxy-auth flow;
the adapter cannot force or inspect those steps. A proxy may prevent QUIC, in
which case the final task metrics must report the negotiated H2/H1 fallback.
