# AlphaX Phase 1A public API inventory

Generated from the exports in `packages/alphax/lib/alphax.dart` and reviewed
against the Phase 1A contract. This inventory describes the transport-neutral
contracts and does not make platform-wide release claims; adapter evidence is
recorded in the Phase 1B, Phase 1C, and Phase 1D review reports.

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
| `AlphaXRequest` | Immutable URI, headers, body, timeout, cancellation, protocol preference, redirect policy, priority, and progress callbacks. |
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
| `AlphaXProtocolFallback` | Requested preference, actual protocol, and normalized reason. |
| `AlphaXProtocolFallbackReason` | Unsupported, server, proxy, network, or unknown reason. |
| `AlphaXSupport` | Supported, unsupported, or unknown capability state. |
| `AlphaXCapability` | Protocol, stream, file, progress, proxy, TLS, migration, background, and negotiation capabilities. |
| `AlphaXCapabilities` | Immutable capability discovery result. |
| `AlphaXRequestMetrics` | Optional transport-neutral timing, byte, protocol, redirect, and connection-reuse values; `AlphaXResponse.completionMetrics` is the final snapshot when available later. |
| `AlphaXTransferDirection` | Upload or download progress direction. |
| `AlphaXProgress` / `AlphaXProgressCallback` | Optional body-progress reporting. |

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
| `AlphaXErrorKind` | Normalized error categories. |
| `AlphaXException` and subclasses | DNS, connection, TLS, timeout, cancellation, protocol, redirect, body, unsupported-capability, and transport errors. |

## Compatibility and leak review

- `alphax` imports only Dart core libraries (`dart:async`, `dart:convert`, and
  related pure-Dart types); it has no Flutter SDK dependency.
- No public symbol exposes `SocketException`, `CronetException`, `NSError`,
  `NSURLSessionTask`, libcurl, Rust, FFI, file descriptors, or native handles.
- H2/H3 names in this inventory are protocol and capability representations;
  they are not global release claims. Current adapter evidence is recorded in
  the Phase 1C and Phase 1D review reports.
- `AlphaXTimeout` and `AlphaXConnectException`/`AlphaXCancelledException` are
  compatibility names retained from the Phase 0 scaffold; new code should use
  the Phase 1A names.

## Test package inventory

`alphax_test` exports `FakeAlphaXTransport`, `InMemoryAlphaXFileSource`,
`InMemoryAlphaXFileTarget`, and `defineAlphaXTransportConformanceTests`. The
fake supports predefined responses, streams, delays, failures, cancellation,
request recording, file transfer, and close behavior.
