import 'dart:async';
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
    Future<AlphaXRequestMetrics>? completionMetrics,
    Iterable<AlphaXRedirectInfo> redirects = const <AlphaXRedirectInfo>[],
  }) : statusCode = _validateStatus(statusCode),
       body = body ?? AlphaXResponseBody.bytes(bodyBytes ?? const <int>[]),
       negotiatedProtocol = negotiatedProtocol ?? protocol,
       completionMetrics = completionMetrics ?? Future<AlphaXRequestMetrics>.value(metrics),
       redirects = List<AlphaXRedirectInfo>.unmodifiable(redirects) {
    // A body may fail after the response has been returned. Observe the
    // completion future internally without consuming the error from callers
    // that choose to await it.
    unawaited(
      this.completionMetrics.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
    unawaited(
      completionProtocolFallback.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
  }

  /// HTTP status code.
  final int statusCode;

  /// Response headers.
  final AlphaXHeaders headers;

  /// Response body, buffered or single-consumption streamed.
  final AlphaXResponseBody body;

  /// Best-known protocol at the time the response snapshot was returned.
  ///
  /// This remains [AlphaXProtocol.unknown] when negotiation is authoritative
  /// only at completion; see [completionMetrics].
  final AlphaXProtocol negotiatedProtocol;

  /// Compatibility/convenience name for the negotiated protocol.
  AlphaXProtocol get protocol => negotiatedProtocol;

  /// Protocol preference originally supplied by the caller, when retained.
  final AlphaXProtocolPreference? requestedProtocol;

  /// Explicit fallback information, when a preference was not negotiated.
  final AlphaXProtocolFallback? protocolFallback;

  /// Transport-neutral metrics known when this response was returned.
  ///
  /// A transport may leave the negotiated protocol [AlphaXProtocol.unknown]
  /// here when the platform only makes it authoritative at completion.
  final AlphaXRequestMetrics metrics;

  /// Final transport-neutral metrics for this response operation.
  ///
  /// The future may remain pending until a streamed body is consumed or the
  /// native operation completes. Its negotiated protocol is authoritative when
  /// the transport can observe one; it is never inferred from a preference or
  /// capability. A body-transfer failure completes this future with the same
  /// normalized error as the body operation.
  final Future<AlphaXRequestMetrics> completionMetrics;

  /// Final fallback metadata derived from the authoritative completion
  /// protocol, when a concrete protocol preference was supplied.
  ///
  /// This remains pending with [completionMetrics] and completes with `null`
  /// when there was no preference, the preference was [AlphaXProtocolPreference.auto],
  /// the final protocol is unknown, or the preferred protocol was negotiated.
  /// An initial [protocolFallback] must not be inferred from an unknown
  /// headers-time protocol; this future is the completion-time equivalent.
  late final Future<AlphaXProtocolFallback?> completionProtocolFallback = completionMetrics.then(
    (finalMetrics) => _protocolFallbackFor(
      requestedProtocol,
      finalMetrics.negotiatedProtocol,
    ),
  );

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

AlphaXProtocolFallback? _protocolFallbackFor(
  AlphaXProtocolPreference? requested,
  AlphaXProtocol negotiated,
) {
  if (requested == null ||
      requested == AlphaXProtocolPreference.auto ||
      negotiated == AlphaXProtocol.unknown) {
    return null;
  }
  final preferred = switch (requested) {
    AlphaXProtocolPreference.auto => AlphaXProtocol.unknown,
    AlphaXProtocolPreference.http10 => AlphaXProtocol.http10,
    AlphaXProtocolPreference.http11 => AlphaXProtocol.http11,
    AlphaXProtocolPreference.http2 => AlphaXProtocol.http2,
    AlphaXProtocolPreference.http3 => AlphaXProtocol.http3,
  };
  return preferred == negotiated
      ? null
      : AlphaXProtocolFallback(requested: requested, negotiated: negotiated);
}
