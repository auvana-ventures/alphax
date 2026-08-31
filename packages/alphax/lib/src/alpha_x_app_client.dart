import 'alpha_x_body.dart';
import 'alpha_x_cancellation.dart';
import 'alpha_x_client.dart';
import 'alpha_x_errors.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_method.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';
import 'alpha_x_timeout.dart';

const Object _alphaXDataNotSupplied = _AlphaXDataNotSupplied();

final class _AlphaXDataNotSupplied {
  const _AlphaXDataNotSupplied();
}

/// A small application-facing layer over [AlphaXClient].
///
/// The facade resolves relative string targets against one validated HTTP(S)
/// base URL, converts simple maps to AlphaX headers, and turns supplied [data]
/// into an [AlphaXBody.json] body. It delegates request execution, middleware,
/// policies, streaming, and response semantics to the wrapped client.
///
/// [baseUrl] must be an absolute HTTP(S) URL without a fragment or URL
/// user-information component. It resolves relative targets as a directory;
/// absolute targets bypass it. The base URL is not an authentication boundary:
/// configured middleware still sees every resolved request, so use only
/// trusted absolute targets with a credentialed client.
///
/// Use [AlphaXAppClient.owned] when this facade is responsible for the
/// underlying client, or [AlphaXAppClient.borrowed] when another owner must
/// keep it alive. A facade does not create a transport or a global singleton.
final class AlphaXAppClient {
  /// Creates a facade that closes [client] when [close] is called.
  AlphaXAppClient.owned(
    AlphaXClient client, {
    required String baseUrl,
    Duration? timeout,
  }) : this._(
         client,
         baseUrl: baseUrl,
         timeout: timeout,
         ownsClient: true,
       );

  /// Creates a facade that borrows [client] without closing it.
  ///
  /// Calling [close] still makes this facade reject later requests, but it
  /// leaves the supplied [client] and its transport available to its owner.
  AlphaXAppClient.borrowed(
    AlphaXClient client, {
    required String baseUrl,
    Duration? timeout,
  }) : this._(
         client,
         baseUrl: baseUrl,
         timeout: timeout,
         ownsClient: false,
       );

  AlphaXAppClient._(
    this._client, {
    required String baseUrl,
    required bool ownsClient,
    Duration? timeout,
  }) : _baseUrl = _parseBaseUrl(baseUrl),
       _defaultTimeout = _validateTimeout(timeout),
       _ownsClient = ownsClient;

  final AlphaXClient _client;
  final Uri _baseUrl;
  final Duration? _defaultTimeout;
  final bool _ownsClient;

  bool _closed = false;
  Future<void>? _closeFuture;

  /// Sends a GET request to [path].
  ///
  /// [path] may be a relative target such as `/users` or an absolute HTTP(S)
  /// URL. [queryParameters] accepts strings, numbers, booleans, and iterables
  /// of those scalar values. A supplied [timeout] overrides the client default
  /// and represents the overall AlphaX timeout only.
  Future<AlphaXResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) => _send(
    HttpMethod.get,
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
    cancellationToken: cancellationToken,
  );

  /// Sends a POST request to [path].
  ///
  /// Supplying [data] creates a replayable JSON body. Use [body] for an
  /// explicit AlphaX body such as bytes, text, a stream, or multipart; the two
  /// parameters are mutually exclusive. Passing `data: null` intentionally
  /// sends the JSON value `null`.
  Future<AlphaXResponse> post(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? data = _alphaXDataNotSupplied,
    AlphaXBody? body,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) => _send(
    HttpMethod.post,
    path,
    queryParameters: queryParameters,
    headers: headers,
    data: data,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
  );

  /// Sends a PUT request to [path].
  ///
  /// [data] and [body] follow the same rules as [post].
  Future<AlphaXResponse> put(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? data = _alphaXDataNotSupplied,
    AlphaXBody? body,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) => _send(
    HttpMethod.put,
    path,
    queryParameters: queryParameters,
    headers: headers,
    data: data,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
  );

  /// Sends a PATCH request to [path].
  ///
  /// [data] and [body] follow the same rules as [post].
  Future<AlphaXResponse> patch(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? data = _alphaXDataNotSupplied,
    AlphaXBody? body,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) => _send(
    HttpMethod.patch,
    path,
    queryParameters: queryParameters,
    headers: headers,
    data: data,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
  );

  /// Sends a DELETE request to [path].
  ///
  /// [data] and [body] follow the same rules as [post].
  Future<AlphaXResponse> delete(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? data = _alphaXDataNotSupplied,
    AlphaXBody? body,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) => _send(
    HttpMethod.delete,
    path,
    queryParameters: queryParameters,
    headers: headers,
    data: data,
    body: body,
    timeout: timeout,
    cancellationToken: cancellationToken,
  );

  /// Sends a HEAD request to [path].
  Future<AlphaXResponse> head(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) => _send(
    HttpMethod.head,
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
    cancellationToken: cancellationToken,
  );

  /// Closes this facade exactly once.
  ///
  /// An owned facade closes its underlying [AlphaXClient]. A borrowed facade
  /// only stops accepting facade requests; its caller-owned client remains
  /// open. Repeated calls return the same future.
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    _closed = true;
    return _closeFuture = _ownsClient ? _client.close() : Future<void>.value();
  }

  Future<AlphaXResponse> _send(
    HttpMethod method,
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, String>? headers,
    Object? data = _alphaXDataNotSupplied,
    AlphaXBody? body,
    Duration? timeout,
    AlphaXCancellationToken? cancellationToken,
  }) async {
    _ensureOpen();
    final request = AlphaXRequest(
      method: method,
      uri: _resolve(path, queryParameters),
      headers: AlphaXHeaders(headers ?? const <String, String>{}),
      body: _resolveBody(data, body),
      timeout: _resolveTimeout(timeout),
      cancellationToken: cancellationToken,
    );
    return _client.send(request);
  }

  void _ensureOpen() {
    if (_closed) {
      throw const AlphaXClientClosedException();
    }
  }

  AlphaXTimeouts? _resolveTimeout(Duration? timeout) {
    final effective = timeout ?? _defaultTimeout;
    return effective == null ? null : AlphaXTimeouts(overall: effective);
  }

  AlphaXBody _resolveBody(Object? data, AlphaXBody? body) {
    final hasData = !identical(data, _alphaXDataNotSupplied);
    if (hasData && body != null) {
      throw ArgumentError('Specify either data or body, not both');
    }
    return body ?? (hasData ? AlphaXBody.json(data) : const AlphaXEmptyBody());
  }

  Uri _resolve(String target, Map<String, Object?>? queryParameters) {
    late final Uri reference;
    try {
      reference = Uri.parse(target);
    } on FormatException catch (error) {
      throw ArgumentError.value(target, 'path', 'Invalid URI target: $error');
    }

    if (reference.hasFragment) {
      throw ArgumentError.value(
        target,
        'path',
        'HTTP request targets cannot contain a fragment',
      );
    }

    final isAbsolute = reference.hasScheme;
    if (isAbsolute) {
      _validateHttpUri(reference, target, 'path');
    } else if (reference.hasAuthority) {
      throw ArgumentError.value(
        target,
        'path',
        'Use a relative path or an absolute HTTP/HTTPS URL',
      );
    }

    final resolved = isAbsolute ? reference : _baseUrl.resolveUri(reference);
    final mergedQuery = <String, List<String>>{};
    if (!isAbsolute) {
      _copyQueryValues(mergedQuery, _baseUrl.queryParametersAll);
    }
    _copyQueryValues(mergedQuery, reference.queryParametersAll);
    _applyQueryParameters(mergedQuery, queryParameters);

    if (mergedQuery.isEmpty) {
      return resolved.replace(query: null);
    }
    return resolved.replace(queryParameters: _uriQueryParameters(mergedQuery));
  }

  static Uri _parseBaseUrl(String value) {
    late final Uri parsed;
    try {
      parsed = Uri.parse(value);
    } on FormatException catch (error) {
      throw ArgumentError.value(value, 'baseUrl', 'Invalid base URL: $error');
    }

    _validateHttpUri(parsed, value, 'baseUrl');
    if (parsed.hasFragment) {
      throw ArgumentError.value(
        value,
        'baseUrl',
        'A base URL cannot contain a fragment',
      );
    }

    final path = parsed.path.isEmpty || parsed.path.endsWith('/')
        ? (parsed.path.isEmpty ? '/' : parsed.path)
        : '${parsed.path}/';
    return parsed.replace(path: path);
  }

  static Duration? _validateTimeout(Duration? timeout) {
    if (timeout != null) {
      AlphaXTimeouts(overall: timeout).validate();
    }
    return timeout;
  }

  static void _validateHttpUri(Uri uri, String value, String argumentName) {
    final scheme = uri.scheme.toLowerCase();
    if (!uri.isAbsolute || (scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      throw ArgumentError.value(
        value,
        argumentName,
        'Expected an absolute HTTP or HTTPS URL with a host',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        value,
        argumentName,
        'URL user information is not supported; use an authorization header or middleware',
      );
    }
  }

  static void _copyQueryValues(
    Map<String, List<String>> target,
    Map<String, List<String>> source,
  ) {
    for (final entry in source.entries) {
      target[entry.key] = List<String>.of(entry.value);
    }
  }

  static void _applyQueryParameters(
    Map<String, List<String>> target,
    Map<String, Object?>? parameters,
  ) {
    if (parameters == null) {
      return;
    }

    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value == null) {
        target.remove(entry.key);
        continue;
      }

      if (value is Iterable<Object?>) {
        final encoded = <String>[];
        for (final item in value) {
          if (item == null) {
            throw ArgumentError.value(
              value,
              entry.key,
              'Query iterables must contain only String, num, or bool values',
            );
          }
          encoded.add(_queryScalar(entry.key, item));
        }
        if (encoded.isEmpty) {
          target.remove(entry.key);
        } else {
          target[entry.key] = encoded;
        }
        continue;
      }

      target[entry.key] = <String>[_queryScalar(entry.key, value)];
    }
  }

  static String _queryScalar(String name, Object value) {
    if (value is double && !value.isFinite) {
      throw ArgumentError.value(value, name, 'Query numbers must be finite');
    }
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    throw ArgumentError.value(
      value,
      name,
      'Query values must be String, num, bool, null, or an iterable of those types',
    );
  }

  static Map<String, dynamic> _uriQueryParameters(Map<String, List<String>> values) => {
    for (final entry in values.entries)
      entry.key: entry.value.length == 1 ? entry.value.single : entry.value,
  };
}
