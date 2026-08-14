import 'dart:convert';

import 'alpha_x_body.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';

/// Immutable HTTP response returned by an AlphaX transport.
final class AlphaXResponse {
  /// Creates a response from a body abstraction or compatibility byte list.
  AlphaXResponse({
    required int statusCode,
    this.headers = const AlphaXHeaders.empty(),
    AlphaXResponseBody? body,
    List<int>? bodyBytes,
    AlphaXProtocol protocol = AlphaXProtocol.unknown,
    AlphaXProtocol? negotiatedProtocol,
    this.requestedProtocol,
    this.protocolFallback,
    this.metrics = const AlphaXRequestMetrics(),
    Iterable<AlphaXRedirectInfo> redirects = const <AlphaXRedirectInfo>[],
  }) : statusCode = _validateStatus(statusCode),
       body = body ?? AlphaXResponseBody.bytes(bodyBytes ?? const <int>[]),
       negotiatedProtocol = negotiatedProtocol ?? protocol,
       redirects = List<AlphaXRedirectInfo>.unmodifiable(redirects);

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final AlphaXHeaders headers;

  /// Response body, buffered or single-consumption streamed.
  final AlphaXResponseBody body;

  /// Protocol actually negotiated.
  final AlphaXProtocol negotiatedProtocol;

  /// Compatibility/convenience name for the negotiated protocol.
  AlphaXProtocol get protocol => negotiatedProtocol;

  /// Protocol preference originally supplied by the caller, when retained.
  final AlphaXProtocolPreference? requestedProtocol;

  /// Explicit fallback information, when a preference was not negotiated.
  final AlphaXProtocolFallback? protocolFallback;

  /// Transport-neutral request metrics.
  final AlphaXRequestMetrics metrics;

  /// Redirect hops observed during response resolution.
  final List<AlphaXRedirectInfo> redirects;

  /// Buffered body bytes, or `null` when the response is streamed.
  List<int>? get bufferedBodyBytes => body.bufferedBytes;

  /// Compatibility body-byte accessor. Reading a streamed body requires
  /// [readAsBytes] instead.
  List<int> get bodyBytes =>
      body.bufferedBytes ?? (throw StateError('The response body is streamed; use readAsBytes()'));

  /// Whether the response status is successful.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  /// Whether the response is a redirect.
  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  /// Compatibility synchronous UTF-8 accessor for buffered responses.
  String get text => utf8.decode(bodyBytes);

  /// Response body stream.
  Stream<List<int>> get stream => body.stream;

  /// Reads the complete response body.
  Future<List<int>> readAsBytes() => body.readAsBytes();

  /// Reads the response as text.
  Future<String> readAsString({Encoding encoding = utf8}) => body.readAsString(encoding: encoding);

  /// Reads and decodes a JSON response.
  Future<Object?> readAsJson({Encoding encoding = utf8}) => body.readAsJson(encoding: encoding);

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
