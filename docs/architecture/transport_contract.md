# Transport Contract

The Phase 0 public contract is intentionally small and transport-independent.

```dart
abstract interface class AlphaXTransport {
  Future<AlphaXResponse> send(AlphaXRequest request);

  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request);

  Future<void> close();
}
```

## Initial request surface

- Absolute HTTP/HTTPS URI.
- Standard HTTP method token, normalized to uppercase.
- Case-insensitive, multi-value headers.
- Byte or text request bodies.
- Optional total/connect/read timeout configuration.
- Optional cancellation token and priority.

## Initial response surface

- Status code.
- Case-insensitive, multi-value headers.
- Immutable response bytes and UTF-8 text convenience access.
- Negotiated protocol when known.
- Nullable request metrics; unsupported metrics remain absent.

## Streaming events

Streaming emits response-start metadata, bounded body chunks, and a completion event.
Transport failures are emitted as stream errors using the public `AlphaXException`
hierarchy. A future production contract must document pause/resume propagation and
consumer cancellation before native streaming is stabilized.

## Deliberate omissions

The Phase 0 contract does not stabilize multipart, cookies, redirects, typed model
decoding, retries, caching, WebSockets, SSE, or the complete Dio adapter.
