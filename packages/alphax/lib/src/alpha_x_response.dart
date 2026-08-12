import 'dart:convert';

import 'alpha_x_headers.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_protocol.dart';

/// Immutable HTTP response returned by an AlphaX transport.
class AlphaXResponse {
  /// Creates a response with immutable body bytes and optional metadata.
  AlphaXResponse({
    required int statusCode,
    this.headers = const AlphaXHeaders.empty(),
    required List<int> bodyBytes,
    this.protocol = AlphaXProtocol.unknown,
    this.metrics = const AlphaXRequestMetrics(),
  }) : statusCode = _validateStatus(statusCode),
       bodyBytes = List<int>.unmodifiable(bodyBytes);

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final AlphaXHeaders headers;

  /// Immutable response body bytes.
  final List<int> bodyBytes;

  /// Negotiated response protocol.
  final AlphaXProtocol protocol;

  /// Transport metrics for this response.
  final AlphaXRequestMetrics metrics;

  /// Whether the response has a successful 2xx status.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  /// Whether the response has a redirect 3xx status.
  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  /// Decodes [bodyBytes] as UTF-8.
  String get text => utf8.decode(bodyBytes);

  /// Exposes the complete body as a single-chunk stream.
  Stream<List<int>> get stream => Stream<List<int>>.value(bodyBytes);

  static int _validateStatus(int statusCode) {
    if (statusCode < 100 || statusCode > 599) {
      throw ArgumentError.value(
        statusCode,
        'statusCode',
        'Status code must be between 100 and 599',
      );
    }
    return statusCode;
  }
}
