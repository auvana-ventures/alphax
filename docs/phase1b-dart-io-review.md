# AlphaX Phase 1B Dart IO transport review

Status: Phase 1B implementation complete; this report records the reviewed
Dart IO fallback and stops before Phase 1C.

## 1. Implemented functionality

`packages/alphax_native` now exports `DartIoTransport`. It owns one reusable
`dart:io` `HttpClient`, keeps Dart IO types private to the adapter, and
implements the Phase 1A `AlphaXTransport` contract for the HTTP/1.1 fallback.

Implemented behavior includes:

- GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS;
- empty, bytes, text, JSON, stream, file, and multipart request bodies;
- lazy response bodies plus progressive `sendStreaming` events;
- pause/resume through the Dart response subscription;
- redirect follow/manual/reject policies, limits, and non-replayable-body
  protection;
- stream/file upload and download through Dart-managed I/O;
- upload/download progress, cancellation, timeout mapping, normalized errors,
  and deterministic close;
- secure default TLS verification with no trust-all callback;
- reusable `HttpClient` connection state.

The adapter does not implement native direct-file paths, H2/H3, configurable
proxy policy, certificate pinning, mTLS, connection migration, or background
transfer.

## 2. Conformance results

The shared `alphax_test` conformance suite runs against a deterministic local
HTTP server through a lazy fixture URI provider. Its five tests pass for
`DartIoTransport`. The adapter-specific integration suite adds 18 tests, for 23
passing tests across the real-client boundary.

The conformance helper gained lazy URI resolution only so future adapters can
run the same contract tests against their own local fixture; no Dart IO
assumption was added to the shared assertions.

## 3. Request-body behavior

Known-length bodies set `Content-Length`; unknown-length streams are passed to
`HttpClientRequest.addStream` without full-body buffering. The request source is
opened once, and `AlphaXStreamBody` retains its single-consumption behavior.
Multipart parts are emitted sequentially. Upload progress counts chunks as they
are accepted by the Dart request stream. The adapter disables `HttpClient`
automatic decompression so wire-byte accounting remains meaningful.

## 4. Streaming behavior

Response data is wrapped in a single-consumption AlphaX response body. The
managed stream copies each delivered chunk, forwards pause/resume to the
underlying `HttpClientResponse` subscription, and emits normalized terminal
errors. `sendStreaming` emits response-start, chunk, and completion events in
that order. No complete response is buffered before the first chunk is made
available.

The Dart IO path relies on the Dart stream subscription to apply demand
backpressure; it does not add an arbitrary unbounded queue. Native bounded
credit-window work remains a responsibility of future Cronet/URLSession
adapters.

## 5. File-transfer behavior

The fallback paths are:

```text
network -> HttpClientResponse -> Dart Stream -> AlphaXFileSink
AlphaXFileSource -> Dart Stream -> HttpClientRequest
```

Upload drains the response body after request completion so reusable client
connections are not left occupied. Download flushes each accepted chunk before
consuming the next event, which keeps a slow Dart file sink in the stream's
backpressure path. The integration test validates exact byte counts,
deterministic response bytes, and an upload FNV-1a hash. Native direct file
transfer is explicitly reported unsupported.

## 6. Cancellation behavior

Cancellation is checked before dispatch, raced against request setup and
request-body upload, attached to active response streams, and honored during
file transfer through the same stream lifecycle. Cancellation is distinct from
transport failure and remains idempotent. Closing the transport aborts tracked
operations and causes active response consumers to receive a normalized client
closed error.

## 7. Timeout mappings

| AlphaX timeout | Dart IO mapping | Result |
| --- | --- | --- |
| `connect` | Timer around `HttpClient.openUrl`, including provider DNS/socket/TLS setup | `AlphaXTimeoutException(connect)` |
| `request` | Deadline spanning open, upload stream, and request close until response headers | `AlphaXTimeoutException(request)` |
| `read` | Inactivity timer reset for each response chunk | `AlphaXTimeoutException(read)` |
| `overall` | Deadline over response streaming and file transfer; setup observes remaining time | `AlphaXTimeoutException(overall)` |

`HttpClient` does not expose separate DNS, TCP, or TLS phase durations, so
those metrics remain unavailable. For lazy `send`, the response body is owned by
the caller after headers are returned; the overall body timer is armed when that
stream is first consumed. `sendStreaming` and file transfers consume
immediately and enforce the end-to-end timer continuously. This lazy-body
boundary is documented for maintainer review rather than hidden.

## 8. Error mappings

The adapter maps `SocketException` to DNS or connection based on the provider
message, TLS handshake/certificate failures to `AlphaXTlsException`, redirect
limit failures to `AlphaXRedirectException`, request stream failures to
`AlphaXRequestBodyException`, response stream failures to
`AlphaXResponseBodyException`, invalid HTTP data to `AlphaXProtocolException`,
timeouts to `AlphaXTimeoutException`, cancellation to
`AlphaXCancellationException`, and closed-client use to
`AlphaXClientClosedException`. Original provider exceptions and stacks remain
optional diagnostics.

## 9. Redirect behavior

The adapter uses `HttpClient` redirect handling for replayable bodies and maps
provider redirect metadata into `AlphaXRedirectInfo`. Manual mode returns the
redirect response; reject mode raises `AlphaXRedirectException`; redirect
limits are normalized instead of leaking `RedirectException`. A follow policy
with a single-use body does not allow Dart IO to replay that body and instead
raises a redirect error when a redirect is returned. Method conversion remains
the provider's documented HTTP redirect behavior and is retained where Dart IO
reports it.

## 10. Capability reporting

`DartIoTransport` reports H1, streamed upload/download, and progress as
`supported`. H2/H3, HTTP/1.0, native file paths, configurable proxy behavior,
certificate pinning, mTLS, connection migration, background transfer, and
negotiated-protocol reporting are `unsupported`. Explicit H2/H3 preferences
fail with `AlphaXUnsupportedCapabilityException`; automatic selection uses the
Dart IO fallback without claiming a protocol it cannot observe.

## 11. Metrics actually available

The adapter reports time to response headers, upload/download byte counts where
the stream has been consumed, redirect count, and an `unknown` negotiated
protocol. It does not fabricate DNS, connect, TLS, connection-reuse, or
provider-level transfer timings. Final streaming metrics include total elapsed
time and downloaded bytes. A lazy `send` response's immutable metrics are
header-time metrics until the body is consumed; the response object does not
mutate its metrics after construction.

## 12. Lifecycle and connection reuse

The transport creates one `HttpClient`, tracks active operations, rejects new
work after close, aborts owned requests during shutdown, and makes repeated
close calls safe. The local integration test observes the same client port for
sequential requests, demonstrating reuse through the shared client. Numerical
connection-reuse metrics remain unavailable because Dart IO does not expose a
reliable client-side reuse flag.

## 13. Phase 1A contract issues discovered

No breaking public contract change was required. A small non-breaking lifecycle
guard was added to `AlphaXClient` so middleware that resumes after `close()`
cannot enter the transport; the race is covered by a core regression test. The
other shared-test enhancement is lazy fixture URI resolution in `alphax_test`,
which preserves the existing assertions and lets every adapter use a
deterministic local server. The Dart IO lazy response-body timeout boundary is
recorded above; no silent public API redesign was made.

## 14. Known Dart IO limitations

- HTTP/2 and HTTP/3 are unavailable and are not claimed.
- Dart IO does not expose the negotiated protocol required by the mobile/Apple
  native strategy.
- Proxy configuration, certificate pinning, and mTLS are not exposed by this
  adapter's transport-neutral constructor.
- File operations route through Dart streams rather than native direct-file
  tasks; the current fallback flushes each file chunk but the Phase 1A sink
  interface remains synchronous.
- Provider-level DNS/connect/TLS timings and a reliable reuse metric are
  unavailable.
- Arbitrary repeated response headers may be combined by `HttpHeaders`; headers
  such as `Set-Cookie` remain repeated where Dart IO preserves them.
- Lazy `send` metrics cannot be updated after body consumption because Phase 1A
  metrics are immutable.

## 15. Risks for Cronet/URLSession implementation

Future adapters must preserve single-consumption body ownership, response event
order, cancellation/error distinction, redirect replay rules, file-transfer
result semantics, and capability honesty. They must bound callback-to-Dart
delivery while paused and identify unavailable provider timings instead of
fabricating them. Native file paths may reduce Dart byte delivery, so progress
and metrics need explicit path metadata without changing the public AlphaX API.

## Validation record

The implementation was validated with formatting, analysis, all core/fake/
conformance/placeholder tests, the deterministic Dart IO integration suite,
local TLS verification using a generated test-only self-signed certificate,
package dry-run validation, and a public API audit confirming no `dart:io` type
is required by `alphax` public APIs.

No package was published to pub.dev. Phase 1C and later phases remain outside
this task.
