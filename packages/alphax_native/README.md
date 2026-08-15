# alphax_native

Platform transport integration boundary for AlphaX, including the Phase 1B
Dart IO fallback, the Phase 1C Android Cronet adapter, and the Phase 1D Apple
URLSession adapter.

`DartIoTransport` uses one reusable `dart:io` `HttpClient` and implements the
transport-neutral AlphaX contract for the HTTP/1.1 fallback path. It provides
progressive Dart-streamed request/response and file transfers, cancellation,
timeouts, redirects, normalized errors, and secure platform TLS defaults.

The Dart IO adapter does not claim HTTP/2, HTTP/3, or native file-backed
transfer. Its actual negotiated protocol is unavailable from the Dart IO API
and is reported as `unknown`; no H2/H3 support is inferred from capability
metadata. It supports platform-default/additional trust through `SecurityContext`
and system/direct/explicit HTTP proxy routing, but SPKI pinning, mTLS, and
explicit HTTPS-proxy routing fail with a normalized unsupported-policy error.

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
platform defaults and Cronet SPKI pinning is configured at engine creation;
custom trust anchors and client identities are rejected by the selected
provider. System proxy behavior is provider-managed; the selected Cronet API
does not expose a safe explicit/direct proxy mapping and reports those modes as
unsupported.

The Android plugin declares API 24 as its minimum Android API and prefers the
Google Play Services Cronet provider when available. The Apple plugin targets
iOS 15+ and macOS 12+. CocoaPods is the supported 1.0 packaging path; Swift
Package Manager integration is deferred and is not required for the release
gate.

The Android adapter completed Phase 1C physical-device validation, including
actual H3 negotiation and truthful H3 fallback reporting. The Apple adapter is
implemented for iOS 15+ and macOS 12+ using Foundation URLSession; macOS and
signed iPhone correctness evidence covers H1/H2/H3, fallback, streaming,
cancellation, TLS rejection, progress, and native file paths. This package must
not leak Cronet, URLSession, FFI, C++, libcurl, or Rust types into `alphax`.

Apple `send()` responses expose headers-time metadata. URLSession task metrics
are authoritative only when the operation completes, so callers must await
`AlphaXResponse.completionMetrics` and `completionProtocolFallback` instead of
treating an initial `unknown` protocol as H1 or fallback. `sendStreaming()`
exposes the same final metrics and fallback metadata in
`AlphaXResponseCompleted`.

Apple uses `URLSessionConfiguration.default` for system routing and configures
direct/explicit HTTP proxy policies through the CFNetwork proxy dictionary on
both iOS and macOS. An explicit HTTP proxy can service an HTTPS destination
through CONNECT; an explicit HTTPS-proxy endpoint remains unsupported and is
reported separately. URLSession owns HTTP CONNECT and proxy authentication;
AlphaX answers supported HTTP Basic proxy challenges without placing
credentials in origin headers. A proxy may prevent QUIC, in which case final
task metrics report the negotiated H2/H1 fallback.

Apple URLSession removes `Authorization`, `Proxy-Authorization`, and `Cookie`
before a cross-origin redirect is followed. Cronet rejects a sensitive
cross-origin redirect because the selected provider API does not let AlphaX
replace pending redirect headers. Same-origin redirects retain request headers
subject to platform behavior. The focused physical-device assertion remains a
release validation item.
