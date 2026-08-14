import 'alpha_x_protocol.dart';

/// Transport-neutral timing and transfer metadata for one request.
final class AlphaXRequestMetrics {
  /// Creates metrics with only values the transport can measure reliably.
  const AlphaXRequestMetrics({
    this.dnsDuration,
    this.connectDuration,
    this.tlsDuration,
    this.timeToFirstByte,
    this.transferDuration,
    this.totalDuration,
    this.uploadedBytes,
    this.downloadedBytes,
    AlphaXProtocol protocol = AlphaXProtocol.unknown,
    AlphaXProtocol? negotiatedProtocol,
    this.redirectCount = 0,
    this.connectionReused,
  }) : negotiatedProtocol = negotiatedProtocol ?? protocol;

  /// DNS lookup duration, when reported.
  final Duration? dnsDuration;

  /// TCP or equivalent connection establishment duration.
  final Duration? connectDuration;

  /// TLS handshake duration, when reported separately.
  final Duration? tlsDuration;

  /// Time from request start to the first response byte.
  final Duration? timeToFirstByte;

  /// Response transfer duration after the first byte.
  final Duration? transferDuration;

  /// End-to-end request duration through completion.
  final Duration? totalDuration;

  /// Number of request bytes sent, when known.
  final int? uploadedBytes;

  /// Number of response bytes received, when known.
  final int? downloadedBytes;

  /// Protocol actually negotiated.
  final AlphaXProtocol negotiatedProtocol;

  /// Compatibility/convenience name for the negotiated protocol.
  AlphaXProtocol get protocol => negotiatedProtocol;

  /// Number of redirect hops, when known.
  final int redirectCount;

  /// Whether an existing connection was reused, when observable.
  final bool? connectionReused;

  /// Returns a copy with selected values replaced.
  AlphaXRequestMetrics copyWith({
    Duration? dnsDuration,
    Duration? connectDuration,
    Duration? tlsDuration,
    Duration? timeToFirstByte,
    Duration? transferDuration,
    Duration? totalDuration,
    int? uploadedBytes,
    int? downloadedBytes,
    AlphaXProtocol? negotiatedProtocol,
    int? redirectCount,
    bool? connectionReused,
  }) => AlphaXRequestMetrics(
    dnsDuration: dnsDuration ?? this.dnsDuration,
    connectDuration: connectDuration ?? this.connectDuration,
    tlsDuration: tlsDuration ?? this.tlsDuration,
    timeToFirstByte: timeToFirstByte ?? this.timeToFirstByte,
    transferDuration: transferDuration ?? this.transferDuration,
    totalDuration: totalDuration ?? this.totalDuration,
    uploadedBytes: uploadedBytes ?? this.uploadedBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    negotiatedProtocol: negotiatedProtocol ?? this.negotiatedProtocol,
    redirectCount: redirectCount ?? this.redirectCount,
    connectionReused: connectionReused ?? this.connectionReused,
  );
}
