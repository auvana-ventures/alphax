import 'alpha_x_headers.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';

/// Event emitted by a streaming AlphaX transport.
sealed class AlphaXEvent {
  /// Creates a streaming event.
  const AlphaXEvent();
}

/// Metadata emitted when response headers are available.
final class AlphaXResponseStarted extends AlphaXEvent {
  /// Creates a response-start event.
  AlphaXResponseStarted({
    required this.statusCode,
    this.headers = const AlphaXHeaders.empty(),
    AlphaXProtocol protocol = AlphaXProtocol.unknown,
    AlphaXProtocol? negotiatedProtocol,
    this.requestedProtocol,
    this.protocolFallback,
    Iterable<AlphaXRedirectInfo> redirects = const <AlphaXRedirectInfo>[],
  }) : negotiatedProtocol = negotiatedProtocol ?? protocol,
       redirects = List<AlphaXRedirectInfo>.unmodifiable(redirects);

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final AlphaXHeaders headers;

  /// Protocol actually negotiated.
  final AlphaXProtocol negotiatedProtocol;

  /// Compatibility/convenience name for the negotiated protocol.
  AlphaXProtocol get protocol => negotiatedProtocol;

  /// Protocol preference supplied to the request, when retained.
  final AlphaXProtocolPreference? requestedProtocol;

  /// Explicit fallback information, when applicable.
  final AlphaXProtocolFallback? protocolFallback;

  /// Redirect hops observed before the final response.
  final List<AlphaXRedirectInfo> redirects;
}

/// A bounded response body chunk.
final class AlphaXResponseChunk extends AlphaXEvent {
  /// Creates a chunk and copies the caller's list.
  AlphaXResponseChunk(List<int> bytes) : bytes = List<int>.unmodifiable(bytes);

  /// Immutable chunk bytes.
  final List<int> bytes;
}

/// Terminal metadata for a completed response stream.
final class AlphaXResponseCompleted extends AlphaXEvent {
  /// Creates a completion event.
  const AlphaXResponseCompleted({
    this.metrics = const AlphaXRequestMetrics(),
    required this.bytesReceived,
  });

  /// Final request metrics.
  final AlphaXRequestMetrics metrics;

  /// Number of body bytes delivered through chunks.
  final int bytesReceived;
}
