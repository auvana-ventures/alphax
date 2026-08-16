import 'dart:async';
import 'dart:typed_data';

import 'package:alphax/alphax.dart';
import 'package:dio/dio.dart';

/// A Dio [HttpClientAdapter] backed by an already configured [AlphaXClient].
///
/// The adapter owns no transport policy of its own. TLS, trust anchors, SPKI
/// pins, proxy policy, middleware, and the selected native or Dart transport
/// remain configured on [client]. Dio request streams are passed to AlphaX as
/// single-use bodies, and Dio's response transformer owns response buffering
/// or streaming after [fetch] returns.
final class AlphaXDioAdapter implements HttpClientAdapter {
  /// Creates an adapter for [client].
  ///
  /// When [closeClient] is true, [close] also closes the supplied AlphaX
  /// client. Set it to false when the client is shared by another owner.
  AlphaXDioAdapter(
    this.client, {
    this.closeClient = true,
  });

  /// Extra key for the typed actual [AlphaXProtocol] value.
  static const protocolExtraKey = 'alphax.protocol';

  /// Extra key for the typed [AlphaXProtocolFallback] value, when known.
  static const protocolFallbackExtraKey = 'alphax.protocolFallback';

  /// Extra key for the current [AlphaXRequestMetrics] snapshot.
  static const metricsExtraKey = 'alphax.metrics';

  /// Extra key for the completion-time metrics future.
  static const completionMetricsExtraKey = 'alphax.completionMetrics';

  /// Extra key for the completion-time fallback future.
  static const completionProtocolFallbackExtraKey = 'alphax.completionProtocolFallback';

  /// Extra key for a typed [AlphaXProtocolPreference] request preference.
  static const protocolPreferenceExtraKey = 'alphax.protocolPreference';

  /// Extra key for a typed [AlphaXProtocolRequirement] request requirement.
  static const protocolRequirementExtraKey = 'alphax.protocolRequirement';

  /// AlphaX client used for every Dio operation.
  final AlphaXClient client;

  /// Whether closing this adapter also closes [client].
  final bool closeClient;

  final Set<AlphaXCancellationToken> _activeTokens = <AlphaXCancellationToken>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: "AlphaX Dio adapter is closed",
      );
    }

    final cancellationToken = AlphaXCancellationToken();
    _activeTokens.add(cancellationToken);
    _bindCancellation(options, cancellationToken, cancelFuture);
    var handedOffToResponse = false;

    try {
      final request = _toAlphaXRequest(options, requestStream, cancellationToken);
      final response = await client.send(request);
      final responseBody = _toDioResponseBody(
        response,
        options,
        cancellationToken,
        () => _activeTokens.remove(cancellationToken),
      );
      handedOffToResponse = true;
      return responseBody;
    } catch (error, stackTrace) {
      throw _toDioException(error, stackTrace, options);
    } finally {
      if (!handedOffToResponse) {
        _activeTokens.remove(cancellationToken);
      }
    }
  }

  @override
  void close({bool force = false}) {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final token in _activeTokens.toList()) {
      token.cancel('AlphaX Dio adapter closed');
    }
    if (closeClient) {
      unawaited(client.close());
    }
  }

  void _bindCancellation(
    RequestOptions options,
    AlphaXCancellationToken token,
    Future<void>? cancelFuture,
  ) {
    final dioCancelToken = options.cancelToken;
    if (dioCancelToken?.isCancelled ?? false) {
      token.cancel(dioCancelToken!.cancelError?.error);
    }
    unawaited(
      dioCancelToken?.whenCancel.then<void>(
            (error) => token.cancel(error.error ?? error.message),
          ) ??
          Future<void>.value(),
    );
    unawaited(
      cancelFuture?.then<void>(
            (_) => token.cancel(dioCancelToken?.cancelError?.error),
          ) ??
          Future<void>.value(),
    );
  }

  AlphaXRequest _toAlphaXRequest(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    AlphaXCancellationToken cancellationToken,
  ) {
    final method = HttpMethod.tryParse(options.method);
    if (method == null) {
      throw ArgumentError.value(options.method, 'method', 'Unsupported HTTP method');
    }

    final requirement = _typedExtra<AlphaXProtocolRequirement>(
      options.extra,
      protocolRequirementExtraKey,
    );
    final requestedPreference = _typedExtra<AlphaXProtocolPreference>(
      options.extra,
      protocolPreferenceExtraKey,
    );
    final preference =
        requestedPreference ?? requirement?.preference ?? AlphaXProtocolPreference.auto;

    final body = requestStream == null
        ? const AlphaXEmptyBody()
        : AlphaXStreamBody(
            requestStream,
            contentLength: _contentLength(options.headers),
            contentType:
                options.contentType ?? _firstHeader(options.headers, Headers.contentTypeHeader),
          );

    return AlphaXRequest(
      method: method,
      uri: options.uri,
      headers: _toAlphaXHeaders(options.headers),
      body: body,
      timeouts: AlphaXTimeouts(
        connect: options.connectTimeout,
        request: options.sendTimeout,
        read: options.receiveTimeout,
      ),
      cancellationToken: cancellationToken,
      protocolPreference: preference,
      protocolRequirement: requirement,
      redirectPolicy: AlphaXRedirectPolicy(
        mode: options.followRedirects ? AlphaXRedirectMode.follow : AlphaXRedirectMode.manual,
        maxRedirects: options.maxRedirects,
      ),
    );
  }

  ResponseBody _toDioResponseBody(
    AlphaXResponse response,
    RequestOptions options,
    AlphaXCancellationToken cancellationToken,
    void Function() release,
  ) {
    late final ResponseBody responseBody;
    responseBody = ResponseBody(
      _releaseAfterStream(
        response.stream.map<Uint8List>(
          (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
        ),
        release,
      ),
      response.statusCode,
      isRedirect: response.isRedirect || response.redirects.isNotEmpty,
      redirects: response.redirects
          .map(
            (redirect) => RedirectRecord(
              redirect.statusCode,
              redirect.method ?? options.method,
              redirect.to,
            ),
          )
          .toList(),
      headers: <String, List<String>>{
        for (final name in response.headers.names) name: response.headers.values(name),
      },
      onClose: () {
        cancellationToken.cancel('Dio closed the response body');
        release();
      },
    );

    responseBody.extra[completionMetricsExtraKey] = response.completionMetrics;
    responseBody.extra[completionProtocolFallbackExtraKey] = response.completionProtocolFallback;
    _applyMetrics(responseBody, response.metrics);
    if (response.protocolFallback != null) {
      responseBody.extra[protocolFallbackExtraKey] = response.protocolFallback;
    }

    unawaited(
      response.completionMetrics.then<void>(
        (metrics) => _applyMetrics(responseBody, metrics),
        onError: (Object _, StackTrace __) {},
      ),
    );
    unawaited(
      response.completionProtocolFallback.then<void>(
        (fallback) {
          if (fallback == null) {
            responseBody.extra.remove(protocolFallbackExtraKey);
          } else {
            responseBody.extra[protocolFallbackExtraKey] = fallback;
          }
        },
        onError: (Object _, StackTrace __) {},
      ),
    );
    return responseBody;
  }

  static Stream<Uint8List> _releaseAfterStream(
    Stream<Uint8List> stream,
    void Function() release,
  ) => stream.transform<Uint8List>(
    StreamTransformer<Uint8List, Uint8List>.fromHandlers(
      handleError: (Object error, StackTrace stackTrace, EventSink<Uint8List> sink) {
        release();
        sink.addError(error, stackTrace);
      },
      handleData: (Uint8List data, EventSink<Uint8List> sink) => sink.add(data),
      handleDone: (EventSink<Uint8List> sink) {
        release();
        sink.close();
      },
    ),
  );

  void _applyMetrics(ResponseBody responseBody, AlphaXRequestMetrics metrics) {
    responseBody.extra[protocolExtraKey] = metrics.negotiatedProtocol;
    responseBody.extra[metricsExtraKey] = metrics;
    final version = _httpVersion(metrics.negotiatedProtocol);
    if (version == null) {
      responseBody.extra.remove(HttpClientAdapter.extraKeyHttpVersion);
    } else {
      responseBody.extra[HttpClientAdapter.extraKeyHttpVersion] = version;
    }
  }

  DioException _toDioException(
    Object error,
    StackTrace stackTrace,
    RequestOptions options,
  ) {
    if (error is DioException) {
      return error;
    }

    final effectiveStackTrace = error is AlphaXException
        ? error.stackTrace ?? stackTrace
        : stackTrace;
    if (error is AlphaXCancellationException) {
      return DioException.requestCancelled(
        requestOptions: options,
        reason: error.reason ?? error.message,
        stackTrace: effectiveStackTrace,
      );
    }
    if (error is AlphaXTimeoutException) {
      final timeout = switch (error.timeoutKind) {
        AlphaXTimeoutKind.connect => options.connectTimeout,
        AlphaXTimeoutKind.request => options.sendTimeout,
        AlphaXTimeoutKind.read => options.receiveTimeout,
        AlphaXTimeoutKind.overall => null,
      };
      if (error.timeoutKind == AlphaXTimeoutKind.connect) {
        return DioException.connectionTimeout(
          requestOptions: options,
          timeout: timeout ?? Duration.zero,
          error: error,
        );
      }
      if (error.timeoutKind == AlphaXTimeoutKind.request) {
        return DioException.sendTimeout(
          requestOptions: options,
          timeout: timeout ?? Duration.zero,
        );
      }
      if (error.timeoutKind == AlphaXTimeoutKind.read) {
        return DioException.receiveTimeout(
          requestOptions: options,
          timeout: timeout ?? Duration.zero,
          error: error,
        );
      }
    }
    if (error is AlphaXException && error.kind == AlphaXErrorKind.tls) {
      return DioException.badCertificate(
        requestOptions: options,
        error: error,
      );
    }
    if (error is AlphaXException &&
        (error.kind == AlphaXErrorKind.dns || error.kind == AlphaXErrorKind.connection)) {
      return DioException.connectionError(
        requestOptions: options,
        reason: error.message,
        error: error,
      );
    }

    return DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
      error: error,
      stackTrace: effectiveStackTrace,
      message: error is AlphaXException ? error.message : 'AlphaX Dio adapter request failed',
    );
  }

  static AlphaXHeaders _toAlphaXHeaders(Map<String, dynamic> headers) {
    final entries = <MapEntry<String, String>>[];
    for (final entry in headers.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is Iterable<Object?>) {
        for (final item in value) {
          entries.add(MapEntry<String, String>(entry.key, '$item'));
        }
      } else {
        entries.add(MapEntry<String, String>(entry.key, '$value'));
      }
    }
    return AlphaXHeaders.fromEntries(entries);
  }

  static int? _contentLength(Map<String, dynamic> headers) {
    final value = _firstHeader(headers, Headers.contentLengthHeader);
    return value == null ? null : int.tryParse(value);
  }

  static String? _firstHeader(Map<String, dynamic> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != name.toLowerCase() || entry.value == null) {
        continue;
      }
      final value = entry.value;
      if (value is Iterable<Object?>) {
        return value.isEmpty ? null : '${value.first}';
      }
      return '$value';
    }
    return null;
  }

  static T? _typedExtra<T>(Map<String, dynamic> extras, String key) {
    final value = extras[key];
    if (value == null) {
      return null;
    }
    if (value is! T) {
      throw ArgumentError.value(value, 'options.extra[$key]', 'Expected $T');
    }
    return value;
  }

  static String? _httpVersion(AlphaXProtocol protocol) => switch (protocol) {
    AlphaXProtocol.http10 => '1.0',
    AlphaXProtocol.http11 => '1.1',
    AlphaXProtocol.http2 => '2.0',
    AlphaXProtocol.http3 => '3.0',
    AlphaXProtocol.unknown => null,
  };
}
