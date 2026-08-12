import 'alpha_x_protocol.dart';

/// Transport-neutral timing, transfer, and diagnostic metadata for a request.
class AlphaXRequestMetrics {
  /// Creates metrics with only the capabilities supported by the transport.
  const AlphaXRequestMetrics({
    this.dnsDuration,
    this.connectDuration,
    this.tlsDuration,
    this.timeToFirstByte,
    this.transferDuration,
    this.totalDuration,
    this.uploadedBytes,
    this.downloadedBytes,
    this.protocol = AlphaXProtocol.unknown,
    this.connectionReused,
    this.remoteAddress,
    this.nativeTransport,
    this.nativeErrorCode,
    this.retryCount = 0,
  });

  /// DNS lookup duration, when reported.
  final Duration? dnsDuration;

  /// Connection establishment duration, when reported.
  final Duration? connectDuration;

  /// TLS negotiation duration, when reported.
  final Duration? tlsDuration;

  /// Time from request start until the first response byte, when reported.
  final Duration? timeToFirstByte;

  /// Response transfer duration, when reported.
  final Duration? transferDuration;

  /// Total request duration, when reported.
  final Duration? totalDuration;

  /// Number of request bytes sent, when known.
  final int? uploadedBytes;

  /// Number of response bytes received, when known.
  final int? downloadedBytes;

  /// Negotiated protocol or [AlphaXProtocol.unknown].
  final AlphaXProtocol protocol;

  /// Whether an existing connection was reused, when reported.
  final bool? connectionReused;

  /// Remote address, when safely available.
  final String? remoteAddress;

  /// Name of the implementation that produced the metrics.
  final String? nativeTransport;

  /// Optional implementation-level error code.
  final int? nativeErrorCode;

  /// Number of retries performed before completion.
  final int retryCount;
}
