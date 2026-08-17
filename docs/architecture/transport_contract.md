# AlphaX Phase 1A Transport Contract

Status: Phase 1A contract implemented; Dart IO, Android Cronet, Apple URLSession,
and browser Fetch adapters implement the applicable portions. Cross-transport
release validation and 1.0 API hardening are complete for RC review; platform
capability limits remain explicit in the release gate.

`packages/alphax` is pure Dart. The public contract is the seam that Dart IO,
Android Cronet/HttpEngine, and Apple URLSession adapters must implement. It does
not expose any native task, socket, file descriptor, FFI, or platform-channel
type, and it makes no global H2/H3 claim: availability remains transport- and
provider-specific until all required platform validation is complete.

## Transport surface

```dart
abstract class AlphaXTransport {
  AlphaXCapabilities get capabilities;

  Future<AlphaXResponse> send(AlphaXRequest request);

  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request);

  Future<AlphaXTransferResult> download(
    AlphaXRequest request,
    AlphaXFileTarget target,
  );

  Future<AlphaXTransferResult> upload(
    AlphaXRequest request,
    AlphaXFileSource source,
  );

  Future<void> close();
}
```

The base class supplies bounded stream-to-file and file-to-request defaults.
Platform transports may override those methods for native file-backed transfer.
Implementations must retain one reusable client/session policy, reject new work
after close, cancel in-flight work during shutdown, and make repeated `close()`
calls harmless.

## Request and response

`AlphaXRequest` is immutable and contains:

- `HttpMethod`: GET, POST, PUT, PATCH, DELETE, HEAD, or OPTIONS;
- an absolute HTTP/HTTPS `Uri`, whose query parameters remain part of the URI;
- immutable case-insensitive, multi-value `AlphaXHeaders`;
- an `AlphaXBody` request source;
- `AlphaXTimeouts`, cancellation, redirect policy, and protocol preference;
- optional upload/download progress callbacks.

`AlphaXResponse` contains status, immutable headers, an
`AlphaXResponseBody`, a headers-time metrics snapshot, redirects, the
best-known `AlphaXProtocol`, and optional requested-protocol/fallback metadata.
The actual protocol is never derived from capabilities or from the request
preference. `completionMetrics` is a future final metrics snapshot: it may
remain pending until a streamed body or native operation completes and is the
authoritative source for negotiated protocol when the platform reports it only
at completion. `completionProtocolFallback` is the corresponding future for
final preference-mismatch metadata. `unknown` is a valid observation state, not
an implicit H1 or fallback result.

## Body ownership and replay

Request factories cover empty, bytes, text, JSON, stream, file, and multipart
bodies. Byte/text/JSON bodies are replayable and own immutable encoded bytes.
`AlphaXStreamBody` is single-consumption by default. A file source declares
whether it is replayable. Multipart bodies stream parts sequentially and are
replayable only when every part is replayable.

Response byte bodies can be read repeatedly. A streamed response body is
single-consumption: reading `stream`, `readAsBytes`, `readAsString`, or
`readAsJson` consumes the producer. A transport must propagate producer errors
and must not silently buffer a complete response merely to satisfy the API.

## Streaming lifecycle

`sendStreaming` emits:

1. `AlphaXResponseStarted` with status, headers, best-known protocol, and redirects;
2. zero or more bounded `AlphaXResponseChunk` values;
3. one `AlphaXResponseCompleted` value with final metrics, byte count, and
   completion-time fallback metadata. The completion event is authoritative
   for negotiated protocol when the start event could not prove it.

The Dart stream subscription owns consumer pause/resume and cancellation. Native
adapters must connect those signals to their bounded producer queue. The public
contract does not prescribe a credit-window implementation, but native buffering
must remain bounded and cancellation must release the body and transport
resources. A stream error is terminal and must use the normalized exception
taxonomy when it originates in the transport.

## Protocol terminology

`AlphaXProtocolPreference` is caller intent (`auto`, H1, H2, or H3 preference).
`AlphaXProtocolRequirement` is fail-closed intent: the exact protocol must be
observed at completion, and `unknown` never satisfies it. `AlphaXProtocol` is
the actual result (`http10`, `http11`, `http2`, `http3`, or `unknown`).
`AlphaXProtocolFallback` is present at completion when a concrete preferred
protocol was not negotiated and the transport knows the actual protocol. An
unknown response-start protocol produces no fallback metadata. A capability
such as H3 support is never reported as an actual H3 response.

`AlphaXTlsPolicy` and `AlphaXProxyPolicy` are immutable transport-neutral
configuration values. Adapters must either honor a configured control or fail
with a normalized unsupported-policy error; they must not silently fall back to
system routing, direct routing, ordinary trust, or trust-all behavior.

## Capability discovery

`AlphaXCapabilities` returns `supported`, `unsupported`, or `unknown` for H1,
H2, H3, streaming upload/download, native file paths, progress, proxy
configuration, default trust, custom trust anchors, certificate pinning, mTLS,
system proxy, direct policy, explicit HTTP proxy, explicit HTTPS proxy
endpoints, proxy authentication, protocol requirements, connection migration,
background transfer, and negotiated-protocol reporting. An explicit HTTP
proxy may service HTTPS destinations through CONNECT; that is not the same as
an HTTPS proxy endpoint. Callers may inspect capabilities before
requesting an optional behavior. If a capability is unavailable at runtime,
the transport throws `AlphaXUnsupportedCapabilityException` or its normalized
policy subtype; it does not silently emulate a materially different semantic.

## Cancellation and timeouts

`AlphaXCancellationToken.cancel` is idempotent. Cancellation is defined for
pre-start, connection/request setup, upload, response wait, response streaming,
file download, and client shutdown. A cancelled operation completes with
`AlphaXCancellationException` (the older `AlphaXCancelledException` spelling is
retained as a compatibility subclass), and resources are released.

The portable timeout categories are:

- `connect`: DNS/socket/TLS establishment;
- `request`: request dispatch, including upload, until response headers;
- `read`: inactivity between response body chunks;
- `overall`: end-to-end operation through response or file completion.

Adapters may leave a category unset when the platform cannot map it reliably.
They must document provider-specific granularity rather than fabricate a phase.

## Errors

The primary public type is `AlphaXException` and its normalized subclasses:
DNS, connection, TLS, timeout, cancellation, protocol, redirect, request-body,
response-body, unsupported-capability, and transport/internal. Native errors
such as `SocketException`, `NSError`, `CronetException`, or an FFI code may be
retained as an optional diagnostic `cause`; they are not the application-facing
category.

## File transfers and progress

Applications use `AlphaXFileSource`, `AlphaXFileTarget`, and `AlphaXFileSink`:

```dart
await client.download(uri, to: target);
await client.upload(uri, from: source);
```

The same calls may be implemented as Dart stream → file, native transport →
file, or file → native transport. No path, descriptor, URLSession task,
Cronet object, or native handle is required by the public API. Progress is
optional and capability-aware; unavailable callbacks must not be simulated with
invented byte counts.

## Middleware

Middleware is ordered as supplied, enters in list order, and unwinds in reverse
order for response or error handling. It can asynchronously mutate a request by
passing `copyWith`, short-circuit, or transform an error in `try`/`catch`.
Streaming and file operations have corresponding next handlers. Middleware must
not invoke a single-use body twice, and the chain is per operation so concurrent
requests do not share mutable request state. The core ships opt-in policy
modules for replay-aware retry, caller-owned token authentication, in-memory
cookies/cache, and a generic circuit breaker. Retry/cache/refresh behavior is
conservative for streamed and file operations because replaying partial or
non-replayable work is unsafe; persistent stores and vendor policy remain
outside the foundation.

## Metrics

`AlphaXRequestMetrics` records only values a transport can measure reliably:
DNS/connect/TLS/TTFB/transfer/total durations, uploaded/downloaded bytes,
negotiated protocol, redirect count, and connection reuse. Missing values stay
null or unknown. Transport-specific diagnostics belong outside the core model.
