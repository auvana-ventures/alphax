# AlphaX 1.0 public API inventory

Generated from the exports in `packages/alphax/lib/alphax.dart` and reviewed
against the Phase 1A contract during Phase 1F release hardening. This inventory
describes the transport-neutral contracts and does not make platform-wide
release claims; adapter evidence is recorded in the Phase 1B, Phase 1C, Phase
1D, and Phase 1E review reports.

**Review status: FROZEN FOR 1.0.0-RC.1.** The core transport-neutral
API has no accidental native exports. Protocol requirements, TLS/proxy policy,
normalized policy errors, completion-time protocol semantics, and the opt-in
policy modules are part of the frozen public boundary. Focused provider/device
validation remains tracked in `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`. Task 18
deliberately adds the optional `AlphaXDioAdapter` to the separate
`alphax_dio` package, and task 24 deliberately adds the pure-Dart policy
contracts. These boundaries are now included in the RC inventory. Any later
API change is a potential 1.0 breaking change.

## Client and transport

| Symbol | Responsibility |
| --- | --- |
| `AlphaXClient` | Ordered middleware, request convenience methods, streaming, file transfer, capability access, and deterministic close. |
| `AlphaXTransport` | `send`, `sendStreaming`, file upload/download hooks, capabilities, and close. |
| `AlphaXMiddleware` | Async buffered, streamed, file-upload, and file-download chain foundation. |
| `AlphaXNext`, `AlphaXStreamNext`, `AlphaXUploadNext`, `AlphaXDownloadNext` | Transport-neutral middleware next-handler types. |

## Request and response

| Symbol | Responsibility |
| --- | --- |
| `HttpMethod` | GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS wire tokens. |
| `AlphaXRequest` | Immutable URI, headers, body, timeout, cancellation, protocol preference and requirement, redirect policy, priority, and progress callbacks. |
| `AlphaXResponse` | Status, headers, body, best-known protocol, completion metrics/fallback futures, fallback metadata, redirects, and metrics. |
| `AlphaXEvent` | Sealed streaming event root. |
| `AlphaXResponseStarted` | Response status, headers, best-known protocol, fallback, and redirects. |
| `AlphaXResponseChunk` | One bounded response byte chunk. |
| `AlphaXResponseCompleted` | Terminal byte count, final metrics, requested protocol, and fallback metadata. |
| `AlphaXHeaders` | Immutable case-insensitive multi-value headers. |
| `AlphaXPriority` | Transport-neutral scheduling hint. |

## Body model

| Symbol | Responsibility |
| --- | --- |
| `AlphaXBody` / `AlphaXRequestBody` | Request-body source contract and compatibility alias. |
| `AlphaXEmptyBody` | Replayable empty body. |
| `AlphaXBytesBody` | Replayable immutable bytes. |
| `AlphaXTextBody` | Replayable encoded text. |
| `AlphaXJsonBody` | Replayable UTF-8 `dart:convert` JSON. |
| `AlphaXStreamBody` | Single-use or explicitly replayable caller stream. |
| `AlphaXFileBody` | File-source body with optional upload progress. |
| `AlphaXMultipartBody` | Sequential multipart/form-data stream. |
| `AlphaXMultipartPart` | Multipart part contract. |
| `AlphaXMultipartField` | Text form field. |
| `AlphaXMultipartFile` | File-backed form field. |
| `AlphaXResponseBody` | Buffered or single-consumption response body with bytes/text/JSON helpers. |

## Protocol, capabilities, and metrics

| Symbol | Responsibility |
| --- | --- |
| `AlphaXProtocol` | Actual `unknown`, `http10`, `http11`, `http2`, or `http3` result. |
| `AlphaXProtocolPreference` | Caller preference, separate from actual negotiation. |
| `AlphaXProtocolRequirement` | Exact protocol that must be observed; unknown never satisfies it. |
| `AlphaXProtocolFallback` | Requested preference, actual protocol, and normalized reason. |
| `AlphaXProtocolFallbackReason` | Unsupported, server, proxy, network, or unknown reason. |
| `AlphaXSupport` | Supported, unsupported, or unknown capability state. |
| `AlphaXCapability` | Protocol, stream, file, progress, proxy, TLS, migration, background, and negotiation capabilities. |
| `AlphaXCapabilities` | Immutable capability discovery result. |
| `AlphaXTlsPolicy` | Verified platform trust, custom anchors, SPKI pins, and opaque client identity policy. |
| `AlphaXTrustAnchor` | Immutable DER trust-anchor value. |
| `AlphaXSpkiPin` | Host-scoped, expiring SHA-256 SPKI pin with backup-pin support. |
| `AlphaXClientIdentity` | Opaque platform-managed client identity reference. |
| `AlphaXProxyPolicy` | System, direct, and explicit HTTP/HTTPS proxy routing policy. |
| `AlphaXProxyCredentials` | Basic proxy credentials kept out of origin headers and diagnostics. |
| `AlphaXProxyScheme` / `AlphaXProxyMode` | Explicit proxy scheme and routing-mode values used by `AlphaXProxyPolicy`. |
| `AlphaXRequestMetrics` | Optional transport-neutral timing, byte, protocol, redirect, and connection-reuse values; `AlphaXResponse.completionMetrics` is the final snapshot when available later. |
| `AlphaXTransferDirection` | Upload or download progress direction. |
| `AlphaXProgress` / `AlphaXProgressCallback` | Optional body-progress reporting. |

## Opt-in policy modules

| Symbol | Responsibility |
| --- | --- |
| `AlphaXRetryPolicy` / `AlphaXRetryMiddleware` | Replay-aware, cancellation-aware retry with idempotency-safe defaults and bounded backoff for buffered operations. |
| `AlphaXRetryDelay` / `AlphaXRetryDecider` | Custom retry delay and final-decision hooks. |
| `AlphaXAccessTokenProvider` / `AlphaXAccessTokenRefresher` | Caller-owned access-token and refresh callbacks. |
| `AlphaXAuthenticationMiddleware` | Token injection plus one single-flight challenge refresh for replayable buffered requests. |
| `AlphaXCookie` / `AlphaXCookieJar` / `AlphaXCookieMiddleware` | In-memory host/path/secure/expiry cookie storage and request/response integration. |
| `AlphaXCacheStore` / `AlphaXCacheEntry` / `AlphaXMemoryCacheStore` | Bounded in-memory response cache storage. |
| `AlphaXCachePolicy` / `AlphaXCacheMiddleware` | Buffered GET/HEAD freshness, conditional revalidation, and mutation invalidation. |
| `AlphaXCircuitState` / `AlphaXResiliencePolicy` / `AlphaXResilienceMiddleware` | Generic in-memory circuit-breaker state and optional retry composition. |

## Lifecycle, files, redirects, and errors

| Symbol | Responsibility |
| --- | --- |
| `AlphaXCancellationToken` | Idempotent cancellation source and notification future. |
| `AlphaXTimeoutKind` / `AlphaXTimeouts` | Connect, request, read-inactivity, and overall timeout semantics. |
| `AlphaXRedirectMode` / `AlphaXRedirectPolicy` | Follow, manual, or reject redirect behavior. |
| `AlphaXRedirectInfo` | Immutable redirect hop metadata. |
| `AlphaXFileSource` | Incremental upload source with replayability declaration. |
| `AlphaXFileTarget` | Download destination abstraction. |
| `AlphaXFileSink` | Bounded destination write/flush/close/abort lifecycle. |
| `AlphaXTransferResult` | File-transfer status, headers, actual protocol, fallback, metrics, redirects, and byte counts. |
| `AlphaXErrorKind` | Normalized error categories, including protocol requirement, proxy, and resilience failures. |
| `AlphaXException` and subclasses | DNS, connection, TLS/certificate/pin, timeout, cancellation, protocol/requirement, redirect, proxy, body, unsupported-capability, resilience, and transport errors. |

## Compatibility and leak review

- `alphax` imports only Dart core libraries (`dart:async`, `dart:convert`, and
  related pure-Dart types); it has no Flutter SDK dependency.
- No public symbol exposes `SocketException`, `CronetException`, `NSError`,
  `NSURLSessionTask`, libcurl, Rust, FFI, file descriptors, or native handles.
- H2/H3 names in this inventory are protocol and capability representations;
  they are not global release claims. Current adapter evidence is recorded in
  the Phase 1C and Phase 1D review reports.
- `AlphaXRequestBody`, `AlphaXTimeout`, `AlphaXConnectException`,
  `AlphaXCancelledException`, and `AlphaXBodyException` are compatibility names
  retained from the Phase 0 scaffold; new code should use the Phase 1A names.

## Test package inventory

`alphax_test` exports `FakeAlphaXTransport`, `InMemoryAlphaXFileSource`,
`InMemoryAlphaXFileTarget`, `defineAlphaXTransportConformanceTests`, and the
transport/factory callback typedefs used by those helpers. The fake supports
predefined responses, streams, delays, failures, cancellation, request
recording, file transfer, and close behavior.

## 1.0.0-rc.1 freeze review

- `alphax` exports only transport-neutral request, response, body, stream,
  file, cancellation, timeout, redirect, protocol, capability, metric,
  middleware, and error contracts.
- `alphax_native` exports adapter and local-file entry points only from its
  implementation package; Cronet, URLSession, Flutter channel, and native
  handle types are not exported by `alphax`.
- `alphax_test` exports deterministic fakes and conformance helpers for tests;
  it is not a production dependency of `alphax` or `alphax_native`.
- `alphax_dio` exports the focused `AlphaXDioAdapter` only. It remains an
  optional package boundary, depends on Dio 5.x and `alphax`, and is not a
  second transport or a promise of full Dio API compatibility.
- `alphax_web` exports `WebFetchTransport` as a separate conditional browser
  adapter. It is not part of the pure `alphax` barrel and does not expose
  browser protocol metadata as H1/H2/H3.

### Frozen interface guarantees and non-guarantees

The public inventory is a contract inventory, not a claim that every package or
platform implements every protocol. The following statements are part of the
1.0 freeze:

- `AlphaXClient` receives an `AlphaXTransport`; `alphax` itself is pure Dart
  and does not include a native transport implementation. Native adapters are
  separate package responsibilities.
- `alphax` itself does not contain a browser transport. The separate
  `alphax_web` package provides browser Fetch for ordinary HTTP, but protocol
  metadata remains unknown and concrete protocol requirements fail closed.
- H3 is opportunistic, not guaranteed. The selected provider, server, proxy,
  and network path determine the actual protocol. A preference may fall back;
  a requirement fails closed unless the exact protocol is authoritatively
  observed.
- The 1.0 interface provides opt-in replay-aware retries, caller-owned token
  authentication, in-memory cookies/cache, and a generic circuit breaker. It
  does not provide persistent stores, unsafe replay, model-specific OAuth, or a
  vendor-specific resilience policy.
- AlphaX makes no universal speed, zero-copy, or “fastest client” claim. Any
  transfer or performance description must stay scoped to the adapter and
  evidence that support it.

## Dio adapter inventory

- `AlphaXDioAdapter`: Dio 5.x `HttpClientAdapter` backed by an injected
  `AlphaXClient`; maps the Dio request/response lifecycle, cancellation,
  timeouts, redirects, progress, normalized errors, and streaming.
- `protocolPreferenceExtraKey`: typed `AlphaXProtocolPreference` input through
  `RequestOptions.extra`.
- `protocolRequirementExtraKey`: typed `AlphaXProtocolRequirement` input through
  `RequestOptions.extra`.
- `protocolExtraKey` and `protocolFallbackExtraKey`: actual protocol and known
  fallback output through `Response.extra`.
- `metricsExtraKey` and completion keys: current and completion-time AlphaX
  metrics/fallback futures through `Response.extra`.

The adapter does not export or reimplement Dio's `Dio`, interceptor, transformer,
`FormData`, native transport, TLS, or proxy types. Those remain owned by the
corresponding package or the configured AlphaX client.

## Package barrel inventory

`packages/alphax_native/lib/alphax_native.dart` exports exactly:

- `DartIoTransport`;
- `AndroidCronetTransport`;
- `AppleUrlSessionTransport`;
- `AlphaXLocalFileSource`;
- `AlphaXLocalFileTarget`.

The native barrel does not export the obsolete placeholder transport. Provider
mapping helpers remain implementation files under `src/` and are not re-exported
by the package barrel. `packages/alphax_dio/lib/alphax_dio.dart` exports exactly
`AlphaXDioAdapter`. Its static keys cover typed protocol preference/requirement
inputs and actual/final protocol, fallback, metrics, and completion metadata
outputs. No package barrel exports a Cronet, URLSession, Flutter channel, native
handle, C++, Rust, or libcurl type through `alphax`.
