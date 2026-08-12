import 'alpha_x_headers.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_protocol.dart';

/// Base type for events emitted by a streaming AlphaX transport.
sealed class AlphaXEvent {
  /// Creates a streaming event.
  const AlphaXEvent();
}

/// Metadata emitted when response headers are available.
final class AlphaXResponseStarted extends AlphaXEvent {
  /// Creates a response-start event.
  const AlphaXResponseStarted({
    required this.statusCode,
    this.headers = const AlphaXHeaders.empty(),
    this.protocol = AlphaXProtocol.unknown,
  });

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final AlphaXHeaders headers;

  /// Negotiated protocol, when known.
  final AlphaXProtocol protocol;
}

/// A bounded response body chunk.
final class AlphaXResponseChunk extends AlphaXEvent {
  /// Creates a response chunk and copies [bytes].
  AlphaXResponseChunk(List<int> bytes) : bytes = List<int>.unmodifiable(bytes);

  /// Immutable chunk bytes.
  final List<int> bytes;
}

/// Terminal metadata for a completed streaming response.
final class AlphaXResponseCompleted extends AlphaXEvent {
  /// Creates a response-completed event.
  const AlphaXResponseCompleted({
    this.metrics = const AlphaXRequestMetrics(),
    required this.bytesReceived,
  });

  /// Final request metrics.
  final AlphaXRequestMetrics metrics;

  /// Number of body bytes delivered to the stream.
  final int bytesReceived;
}
