import 'dart:async';
import 'dart:io';

import 'package:alphax/alphax.dart';

/// Dart IO fallback transport backed by one reusable [HttpClient].
///
/// The public constructor and inherited API expose only AlphaX types. Dart IO
/// request, response, socket, and TLS objects remain private to this adapter.
/// The adapter intentionally reports HTTP/1.1 as its only known protocol
/// capability; it does not claim HTTP/2 or HTTP/3 support.
final class DartIoTransport extends AlphaXTransport {
  /// Creates a Dart IO fallback transport with secure platform defaults.
  DartIoTransport({
    AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
    AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
  }) : tlsPolicy = tlsPolicy,
       proxyPolicy = proxyPolicy,
       _client = _createClient(tlsPolicy, proxyPolicy) {
    // Preserve wire bytes. Automatic decompression would make content-length,
    // progress, and file-transfer accounting describe a different payload.
    _client.autoUncompress = false;
  }

  final HttpClient _client;
  @override
  final AlphaXTlsPolicy tlsPolicy;
  @override
  final AlphaXProxyPolicy proxyPolicy;
  final Set<_DartIoOperation> _operations = <_DartIoOperation>{};
  bool _closed = false;
  Future<void>? _closeFuture;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    transportName: 'dart:io HttpClient',
    http10: AlphaXSupport.unsupported,
    http11: AlphaXSupport.supported,
    http2: AlphaXSupport.unsupported,
    http3: AlphaXSupport.unsupported,
    streamingUpload: AlphaXSupport.supported,
    streamingDownload: AlphaXSupport.supported,
    nativeFileUpload: AlphaXSupport.unsupported,
    nativeFileDownload: AlphaXSupport.unsupported,
    uploadProgress: AlphaXSupport.supported,
    downloadProgress: AlphaXSupport.supported,
    proxyConfiguration: AlphaXSupport.supported,
    tlsDefaultTrust: AlphaXSupport.supported,
    customTrustAnchors: AlphaXSupport.supported,
    certificatePinning: AlphaXSupport.unsupported,
    mutualTls: AlphaXSupport.unsupported,
    systemProxy: AlphaXSupport.supported,
    directConnectionPolicy: AlphaXSupport.supported,
    explicitHttpProxy: AlphaXSupport.supported,
    explicitHttpsProxy: AlphaXSupport.unsupported,
    proxyAuthentication: AlphaXSupport.supported,
    protocolRequirement: AlphaXSupport.unsupported,
    connectionMigration: AlphaXSupport.unsupported,
    backgroundTransfer: AlphaXSupport.unsupported,
    negotiatedProtocolReporting: AlphaXSupport.unsupported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    _ensureUsable(request);
    final operation = _DartIoOperation(this, request);
    _operations.add(operation);
    try {
      return await _send(operation);
    } catch (error, stackTrace) {
      operation.abort();
      operation.finish();
      throw _normalize(error, stackTrace, _DartIoFailureStage.request);
    }
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    try {
      _ensureUsable(request);
      final operation = _DartIoOperation(this, request);
      _operations.add(operation);
      var completed = false;
      try {
        final response = await _send(operation);
        yield AlphaXResponseStarted(
          statusCode: response.statusCode,
          headers: response.headers,
          protocol: response.protocol,
          requestedProtocol: response.requestedProtocol,
          requiredProtocol: response.requiredProtocol,
          protocolFallback: response.protocolFallback,
          redirects: response.redirects,
        );
        await for (final chunk in response.stream) {
          yield AlphaXResponseChunk(chunk);
        }
        completed = true;
        yield AlphaXResponseCompleted(
          metrics: operation.completedMetrics(),
          bytesReceived: operation.downloadedBytes,
          requestedProtocol: response.requestedProtocol,
          requiredProtocol: response.requiredProtocol,
          protocolFallback: response.protocolFallback,
        );
      } finally {
        if (!completed) {
          operation.abort();
        }
        operation.finish();
      }
    } catch (error, stackTrace) {
      throw _normalize(error, stackTrace, _DartIoFailureStage.response);
    }
  }

  @override
  Future<AlphaXTransferResult> download(
    AlphaXRequest request,
    AlphaXFileTarget target,
  ) async {
    AlphaXFileSink? sink;
    try {
      request.cancellationToken?.throwIfCancelled();
      AlphaXResponseStarted? started;
      AlphaXResponseCompleted? completed;
      var bytesTransferred = 0;

      await for (final event in sendStreaming(request)) {
        switch (event) {
          case AlphaXResponseStarted():
            started = event;
            sink = await target.openWrite();
          case AlphaXResponseChunk(:final bytes):
            final activeSink = sink;
            if (activeSink == null) {
              throw const AlphaXProtocolException(
                'A response chunk arrived before response metadata',
              );
            }
            activeSink.add(bytes);
            // Flush each chunk so a slow file target participates in the
            // response stream's backpressure instead of accumulating the
            // complete download in an IOSink buffer.
            await activeSink.flush();
            bytesTransferred += bytes.length;
          case AlphaXResponseCompleted():
            completed = event;
        }
      }

      final responseStarted = started;
      final responseCompleted = completed;
      final activeSink = sink;
      if (responseStarted == null || responseCompleted == null || activeSink == null) {
        throw const AlphaXProtocolException(
          'A streaming transport must emit start, body, and completion events',
        );
      }
      await activeSink.flush();
      await activeSink.close();
      return AlphaXTransferResult(
        statusCode: responseStarted.statusCode,
        headers: responseStarted.headers,
        protocol: responseStarted.protocol,
        requestedProtocol: responseStarted.requestedProtocol,
        requiredProtocol: responseStarted.requiredProtocol,
        protocolFallback: responseStarted.protocolFallback,
        metrics: responseCompleted.metrics,
        redirects: responseStarted.redirects,
        bytesTransferred: bytesTransferred,
        totalBytes: _contentLength(responseStarted.headers),
      );
    } catch (error, stackTrace) {
      await sink?.abort();
      throw _normalize(error, stackTrace, _DartIoFailureStage.response);
    }
  }

  @override
  Future<AlphaXTransferResult> upload(
    AlphaXRequest request,
    AlphaXFileSource source,
  ) async {
    var uploadedBytes = 0;
    final body = AlphaXFileBody(
      source,
      onProgress: (progress) {
        uploadedBytes = progress.bytesTransferred;
        request.onUploadProgress?.call(progress);
      },
    );
    try {
      final response = await send(request.copyWith(body: body));
      // File upload callers receive transfer metadata, not a response body.
      // Drain the body so the reusable HttpClient can release/reuse the socket
      // without buffering the server response in memory.
      await response.stream.drain<void>();
      return AlphaXTransferResult(
        statusCode: response.statusCode,
        headers: response.headers,
        protocol: response.protocol,
        requestedProtocol: response.requestedProtocol,
        requiredProtocol: response.requiredProtocol,
        protocolFallback: response.protocolFallback,
        metrics: response.metrics.copyWith(uploadedBytes: uploadedBytes),
        redirects: response.redirects,
        bytesTransferred: uploadedBytes,
        totalBytes: source.length,
      );
    } catch (error, stackTrace) {
      throw _normalize(error, stackTrace, _DartIoFailureStage.requestBody);
    }
  }

  @override
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    _closed = true;
    _closeFuture = _closeOwnedResources();
    return _closeFuture!;
  }

  Future<void> _closeOwnedResources() async {
    final operations = _operations.toList(growable: false);
    for (final operation in operations) {
      operation.abort(const AlphaXClientClosedException('Dart IO transport is closed'));
    }
    _client.close(force: true);
    if (operations.isNotEmpty) {
      await Future.wait<void>(operations.map((operation) => operation.done));
    }
  }

  Future<AlphaXResponse> _send(_DartIoOperation operation) async {
    final request = operation.alphaRequest;
    final clientRequest = await _openRequest(operation);
    _configureRequest(clientRequest, request);
    await _writeRequestBody(operation, clientRequest);
    final response = await _closeRequest(operation, clientRequest);
    final redirects = _redirects(request, response);
    _validateRedirectResult(request, response, redirects);

    operation.response = response;
    return AlphaXResponse(
      statusCode: response.statusCode,
      headers: _readHeaders(response.headers),
      body: AlphaXResponseBody.stream(
        _responseStream(operation, response),
        contentLength: response.contentLength < 0 ? null : response.contentLength,
      ),
      negotiatedProtocol: AlphaXProtocol.unknown,
      requestedProtocol: request.protocolPreference,
      requiredProtocol: request.protocolRequirement,
      metrics: operation.headersMetrics(redirects.length),
      completionMetrics: operation.completionMetrics,
      redirects: redirects,
    );
  }

  Future<HttpClientRequest> _openRequest(_DartIoOperation operation) async {
    final request = operation.alphaRequest;
    final source = _client.openUrl(request.method.value, request.uri);
    final clientRequest = await _awaitStage(
      source,
      operation,
      timeout: _earliestTimeout(operation, connect: true),
      timeoutKind: _earliestTimeoutKind(operation, connect: true),
      onLateValue: (lateRequest) => lateRequest.abort(),
    );
    if (_closed) {
      clientRequest.abort();
      throw const AlphaXClientClosedException('Dart IO transport is closed');
    }
    operation.clientRequest = clientRequest;
    return clientRequest;
  }

  void _configureRequest(HttpClientRequest clientRequest, AlphaXRequest request) {
    final body = request.body;
    final hasSensitiveHeaders = _hasSensitiveHeaders(request.headers);
    clientRequest.followRedirects =
        request.redirectPolicy.mode == AlphaXRedirectMode.follow &&
        body.isReplayable &&
        !hasSensitiveHeaders;
    clientRequest.maxRedirects = request.redirectPolicy.maxRedirects;

    var explicitContentLength = false;
    for (final name in request.headers.names) {
      final values = request.headers.values(name);
      if (name == 'content-length') {
        if (values.length != 1) {
          throw const AlphaXRequestBodyException(
            'Content-Length must contain exactly one value',
          );
        }
        final value = int.tryParse(values.single);
        if (value == null || value < 0) {
          throw AlphaXRequestBodyException('Invalid Content-Length: ${values.single}');
        }
        clientRequest.contentLength = value;
        explicitContentLength = true;
        continue;
      }
      for (final value in values) {
        clientRequest.headers.add(name, value);
      }
    }

    if (!explicitContentLength && body.contentLength != null) {
      clientRequest.contentLength = body.contentLength!;
    }
    if (!request.headers.contains('content-type') && body.contentType != null) {
      clientRequest.headers.set('content-type', body.contentType!);
    }
  }

  Future<void> _writeRequestBody(
    _DartIoOperation operation,
    HttpClientRequest clientRequest,
  ) async {
    final body = operation.alphaRequest.body;
    if (body is AlphaXEmptyBody) {
      return;
    }
    late final Stream<List<int>> source;
    try {
      source = body.openStream();
    } catch (error, stackTrace) {
      throw AlphaXRequestBodyException(
        'The request body could not be opened',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final counted = _countUpload(operation, body, source);
    try {
      await _awaitStage(
        clientRequest.addStream(counted),
        operation,
        timeout: _earliestTimeout(operation),
        timeoutKind: _earliestTimeoutKind(operation),
      );
    } catch (error, stackTrace) {
      if (error is AlphaXException) {
        rethrow;
      }
      throw AlphaXRequestBodyException(
        'The request body could not be sent',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Stream<List<int>> _countUpload(
    _DartIoOperation operation,
    AlphaXBody body,
    Stream<List<int>> source,
  ) async* {
    final bodyReportsProgress = body is AlphaXFileBody && body.onProgress != null;
    try {
      await for (final chunk in source) {
        operation.alphaRequest.cancellationToken?.throwIfCancelled();
        operation.uploadedBytes += chunk.length;
        if (!bodyReportsProgress) {
          operation.alphaRequest.onUploadProgress?.call(
            AlphaXProgress(
              direction: AlphaXTransferDirection.upload,
              bytesTransferred: operation.uploadedBytes,
              totalBytes: body.contentLength,
              isComplete:
                  body.contentLength != null && operation.uploadedBytes >= body.contentLength!,
            ),
          );
        }
        yield List<int>.unmodifiable(chunk);
      }
    } catch (error, stackTrace) {
      if (error is AlphaXException) {
        rethrow;
      }
      throw AlphaXRequestBodyException(
        'The request body stream failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<HttpClientResponse> _closeRequest(
    _DartIoOperation operation,
    HttpClientRequest clientRequest,
  ) async {
    try {
      return await _awaitStage(
        clientRequest.close(),
        operation,
        timeout: _earliestTimeout(operation),
        timeoutKind: _earliestTimeoutKind(operation),
      );
    } catch (error, stackTrace) {
      if (error is AlphaXException) {
        rethrow;
      }
      throw _normalize(error, stackTrace, _DartIoFailureStage.request);
    }
  }

  Stream<List<int>> _responseStream(
    _DartIoOperation operation,
    HttpClientResponse response,
  ) {
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    Timer? readTimer;
    Timer? overallTimer;
    var terminated = false;

    void cancelTimers() {
      readTimer?.cancel();
      overallTimer?.cancel();
    }

    void finish() {
      cancelTimers();
      operation.finish();
    }

    void fail(Object error, [StackTrace? stackTrace]) {
      if (terminated) {
        return;
      }
      terminated = true;
      cancelTimers();
      final normalized = _normalize(
        error,
        stackTrace ?? StackTrace.current,
        _DartIoFailureStage.response,
      );
      operation.completeMetricsError(
        normalized,
        normalized.stackTrace ?? StackTrace.current,
      );
      controller.addError(normalized, normalized.stackTrace ?? StackTrace.current);
      unawaited(controller.close());
      finish();
    }

    void complete() {
      if (terminated) {
        return;
      }
      terminated = true;
      cancelTimers();
      operation.completeMetrics(operation.completedMetrics());
      unawaited(controller.close());
      finish();
    }

    void armReadTimer() {
      readTimer?.cancel();
      final timeout = operation.alphaRequest.timeouts.read;
      if (timeout != null) {
        readTimer = Timer(timeout, () {
          fail(
            AlphaXTimeoutException(
              'Response body read inactivity exceeded $timeout',
              timeoutKind: AlphaXTimeoutKind.read,
            ),
          );
          operation.abort();
        });
      }
    }

    void armOverallTimer() {
      final timeout = operation.alphaRequest.timeouts.overall;
      if (timeout == null) {
        return;
      }
      final remaining = timeout - operation.stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        fail(
          AlphaXTimeoutException(
            'Overall request timeout elapsed',
            timeoutKind: AlphaXTimeoutKind.overall,
          ),
        );
        return;
      }
      overallTimer = Timer(remaining, () {
        fail(
          AlphaXTimeoutException(
            'Overall request timeout elapsed',
            timeoutKind: AlphaXTimeoutKind.overall,
          ),
        );
        operation.abort();
      });
    }

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        if (operation.alphaRequest.cancellationToken?.isCancelled ?? false) {
          fail(_cancellation(operation.alphaRequest.cancellationToken));
          return;
        }
        final token = operation.alphaRequest.cancellationToken;
        if (token != null) {
          unawaited(
            token.whenCancelled.then((_) {
              if (!terminated) {
                fail(_cancellation(token));
                operation.abort();
              }
            }),
          );
        }
        armOverallTimer();
        if (terminated) {
          return;
        }
        armReadTimer();
        subscription = response.listen(
          (chunk) {
            if (terminated) {
              return;
            }
            operation.downloadedBytes += chunk.length;
            operation.alphaRequest.onDownloadProgress?.call(
              AlphaXProgress(
                direction: AlphaXTransferDirection.download,
                bytesTransferred: operation.downloadedBytes,
                totalBytes: response.contentLength < 0 ? null : response.contentLength,
                isComplete:
                    response.contentLength >= 0 &&
                    operation.downloadedBytes >= response.contentLength,
              ),
            );
            armReadTimer();
            controller.add(List<int>.unmodifiable(chunk));
          },
          onError: (Object error, StackTrace stackTrace) => fail(error, stackTrace),
          onDone: () {
            operation.alphaRequest.onDownloadProgress?.call(
              AlphaXProgress(
                direction: AlphaXTransferDirection.download,
                bytesTransferred: operation.downloadedBytes,
                totalBytes: response.contentLength < 0 ? null : response.contentLength,
                isComplete: true,
              ),
            );
            complete();
          },
          cancelOnError: false,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await subscription?.cancel();
        if (!terminated) {
          terminated = true;
          cancelTimers();
          final cancellation = const AlphaXCancellationException(
            'The response stream subscription was cancelled',
          );
          operation.completeMetricsError(cancellation, StackTrace.current);
          operation.abort();
          finish();
        }
      },
    );
    operation.onAbort = (reason) {
      fail(reason ?? const AlphaXClientClosedException('Dart IO operation aborted'));
    };
    return controller.stream;
  }

  List<AlphaXRedirectInfo> _redirects(
    AlphaXRequest request,
    HttpClientResponse response,
  ) {
    var from = request.uri;
    final redirects = <AlphaXRedirectInfo>[];
    for (final redirect in response.redirects) {
      final to = from.resolve(redirect.location.toString());
      redirects.add(
        AlphaXRedirectInfo(
          statusCode: redirect.statusCode,
          from: from,
          to: to,
          method: redirect.method,
        ),
      );
      from = to;
    }
    return redirects;
  }

  void _validateRedirectResult(
    AlphaXRequest request,
    HttpClientResponse response,
    List<AlphaXRedirectInfo> redirects,
  ) {
    if (request.redirectPolicy.mode == AlphaXRedirectMode.reject &&
        _isRedirectStatus(response.statusCode)) {
      unawaited(response.drain<void>());
      throw AlphaXRedirectException(
        'Redirect received while redirects are rejected (${response.statusCode})',
      );
    }
    if (request.redirectPolicy.mode == AlphaXRedirectMode.follow &&
        (request.headers.names.any(_isSensitiveHeader) || !request.body.isReplayable) &&
        _isRedirectStatus(response.statusCode)) {
      unawaited(response.drain<void>());
      throw const AlphaXRedirectException(
        'A redirect cannot be followed safely because the request has a single-use body '
        'or sensitive credentials',
      );
    }
  }

  static bool _hasSensitiveHeaders(AlphaXHeaders headers) => headers.names.any(_isSensitiveHeader);

  static bool _isSensitiveHeader(String name) => switch (name.toLowerCase()) {
    'authorization' || 'proxy-authorization' || 'cookie' => true,
    _ => false,
  };

  static bool _isRedirectStatus(int statusCode) => statusCode >= 300 && statusCode < 400;

  Future<T> _awaitStage<T>(
    Future<T> source,
    _DartIoOperation operation, {
    required Duration? timeout,
    required AlphaXTimeoutKind timeoutKind,
    void Function(T value)? onLateValue,
  }) {
    final completer = Completer<T>();
    var settled = false;
    Timer? timer;

    void completeError(Object error, StackTrace stackTrace) {
      if (settled) {
        return;
      }
      settled = true;
      timer?.cancel();
      completer.completeError(error, stackTrace);
    }

    source.then(
      (value) {
        if (settled) {
          onLateValue?.call(value);
          return;
        }
        settled = true;
        timer?.cancel();
        completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        completeError(error, stackTrace);
      },
    );

    final token = operation.alphaRequest.cancellationToken;
    if (token != null) {
      unawaited(
        token.whenCancelled.then((_) {
          if (!settled) {
            completeError(_cancellation(token), StackTrace.current);
            operation.abort();
          }
        }),
      );
    }
    if (timeout != null) {
      timer = Timer(timeout, () {
        completeError(
          AlphaXTimeoutException(
            'The ${timeoutKind.name} timeout elapsed',
            timeoutKind: timeoutKind,
          ),
          StackTrace.current,
        );
        operation.abort();
      });
    }
    return completer.future;
  }

  Duration? _earliestTimeout(_DartIoOperation operation, {bool connect = false}) {
    final timeouts = operation.alphaRequest.timeouts;
    final values = <Duration>[];
    if (connect && timeouts.connect != null) {
      values.add(timeouts.connect!);
    }
    if (timeouts.request != null) {
      final remaining = timeouts.request! - operation.requestStopwatch.elapsed;
      values.add(remaining <= Duration.zero ? const Duration(microseconds: 1) : remaining);
    }
    if (timeouts.overall != null) {
      final remaining = timeouts.overall! - operation.stopwatch.elapsed;
      values.add(remaining <= Duration.zero ? const Duration(microseconds: 1) : remaining);
    }
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((left, right) => left <= right ? left : right);
  }

  AlphaXTimeoutKind _earliestTimeoutKind(_DartIoOperation operation, {bool connect = false}) {
    final timeouts = operation.alphaRequest.timeouts;
    final candidates = <MapEntry<AlphaXTimeoutKind, Duration>>[];
    if (connect && timeouts.connect != null) {
      candidates.add(
        MapEntry<AlphaXTimeoutKind, Duration>(
          AlphaXTimeoutKind.connect,
          timeouts.connect!,
        ),
      );
    }
    if (timeouts.request != null) {
      final remaining = timeouts.request! - operation.requestStopwatch.elapsed;
      candidates.add(
        MapEntry<AlphaXTimeoutKind, Duration>(
          AlphaXTimeoutKind.request,
          remaining <= Duration.zero ? const Duration(microseconds: 1) : remaining,
        ),
      );
    }
    if (timeouts.overall != null) {
      final remaining = timeouts.overall! - operation.stopwatch.elapsed;
      candidates.add(
        MapEntry<AlphaXTimeoutKind, Duration>(
          AlphaXTimeoutKind.overall,
          remaining <= Duration.zero ? const Duration(microseconds: 1) : remaining,
        ),
      );
    }
    if (candidates.isEmpty) {
      return AlphaXTimeoutKind.request;
    }
    candidates.sort((left, right) => left.value.compareTo(right.value));
    return candidates.first.key;
  }

  void _ensureUsable(AlphaXRequest request) {
    if (_closed) {
      throw const AlphaXClientClosedException('Dart IO transport is closed');
    }
    request.cancellationToken?.throwIfCancelled();
    if (request.protocolRequirement != null) {
      final requirement = request.protocolRequirement!;
      if (!capabilities.supportsProtocol(requirement.protocol)) {
        throw AlphaXProtocolRequirementException(
          requiredProtocol: requirement,
          actualProtocol: AlphaXProtocol.unknown,
          message: 'Dart IO cannot satisfy a ${requirement.name} protocol requirement',
        );
      }
      // HttpClient does not expose authoritative negotiated-protocol metadata.
      // Unknown is never allowed to satisfy a concrete requirement.
      throw AlphaXProtocolRequirementException(
        requiredProtocol: requirement,
        actualProtocol: AlphaXProtocol.unknown,
        message:
            'Dart IO cannot prove the negotiated protocol for a ${requirement.name} requirement',
      );
    }
    // A preference permits fallback. Dart IO cannot prove H2/H3, so the
    // request proceeds with its normal HTTP/1.1 path and leaves the actual
    // protocol unknown rather than claiming that the preference was met.
    if (tlsPolicy.pins.isNotEmpty) {
      throw AlphaXUnsupportedTlsPolicyException(
        'Dart IO cannot verify SPKI pins without a provider certificate callback',
        capability: AlphaXCapability.certificatePinning,
      );
    }
    if (tlsPolicy.clientIdentity != null) {
      throw AlphaXUnsupportedTlsPolicyException(
        'Dart IO requires a platform client identity for mutual TLS',
        capability: AlphaXCapability.mutualTls,
      );
    }
    if (proxyPolicy.mode == AlphaXProxyMode.explicit &&
        proxyPolicy.scheme == AlphaXProxyScheme.https) {
      throw AlphaXUnsupportedProxyPolicyException(
        'Dart IO cannot configure an HTTPS proxy through HttpClient.findProxy',
        capability: AlphaXCapability.explicitHttpsProxy,
      );
    }
  }

  static HttpClient _createClient(AlphaXTlsPolicy tlsPolicy, AlphaXProxyPolicy proxyPolicy) {
    SecurityContext? context;
    if (tlsPolicy.trustAnchors.isNotEmpty || !tlsPolicy.includePlatformTrust) {
      try {
        context = SecurityContext(withTrustedRoots: tlsPolicy.includePlatformTrust);
        for (final anchor in tlsPolicy.trustAnchors) {
          context.setTrustedCertificatesBytes(anchor.derBytes);
        }
      } catch (error, stackTrace) {
        throw AlphaXUnsupportedTlsPolicyException(
          'Dart IO could not load the configured trust anchors',
          capability: AlphaXCapability.customTrustAnchors,
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }
    final client = HttpClient(context: context);
    switch (proxyPolicy.mode) {
      case AlphaXProxyMode.system:
        break;
      case AlphaXProxyMode.direct:
        client.findProxy = (_) => 'DIRECT';
      case AlphaXProxyMode.explicit:
        client.findProxy = (_) => 'PROXY ${proxyPolicy.host}:${proxyPolicy.port}';
        final credentials = proxyPolicy.credentials;
        if (credentials != null) {
          client.authenticateProxy = (host, port, scheme, realm) async {
            client.addProxyCredentials(
              host,
              port,
              realm ?? '',
              HttpClientBasicCredentials(credentials.username, credentials.password),
            );
            return true;
          };
        }
    }
    return client;
  }

  void _remove(_DartIoOperation operation) {
    _operations.remove(operation);
  }

  static AlphaXHeaders _readHeaders(HttpHeaders headers) {
    final entries = <MapEntry<String, String>>[];
    headers.forEach((name, values) {
      for (final value in values) {
        entries.add(MapEntry<String, String>(name, value));
      }
    });
    return AlphaXHeaders.fromEntries(entries);
  }

  static int? _contentLength(AlphaXHeaders headers) {
    final value = headers['content-length'];
    return value == null ? null : int.tryParse(value);
  }

  static AlphaXCancellationException _cancellation(AlphaXCancellationToken? token) =>
      AlphaXCancellationException(
        token?.cancellationReason?.toString() ?? 'The operation was cancelled',
        reason: token?.cancellationReason,
      );

  static AlphaXException _normalize(
    Object error,
    StackTrace stackTrace,
    _DartIoFailureStage stage,
  ) {
    if (error is AlphaXException) {
      return error;
    }
    if (error is HandshakeException || error is CertificateException) {
      return AlphaXTlsException(
        'TLS negotiation or certificate verification failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is SocketException) {
      final message = error.message.toLowerCase();
      final isDns =
          message.contains('failed host lookup') ||
          message.contains('nodename nor servname') ||
          message.contains('name or service not known');
      if (isDns) {
        return AlphaXDnsException(
          'DNS resolution failed',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      return AlphaXConnectionException(
        'The network connection failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is TimeoutException) {
      return AlphaXTimeoutException(
        'The network operation timed out',
        timeoutKind: AlphaXTimeoutKind.request,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is RedirectException) {
      return AlphaXRedirectException(
        'The redirect policy could not be completed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (stage == _DartIoFailureStage.requestBody) {
      return AlphaXRequestBodyException(
        'The request body operation failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (stage == _DartIoFailureStage.response) {
      return AlphaXResponseBodyException(
        'The response body operation failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is FormatException || error is HttpException) {
      return AlphaXProtocolException(
        'The peer returned an invalid HTTP response',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AlphaXTransportException(
      'The Dart IO transport failed',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

enum _DartIoFailureStage { request, requestBody, response }

final class _DartIoOperation {
  _DartIoOperation(this.owner, this.alphaRequest)
    : stopwatch = Stopwatch()..start(),
      requestStopwatch = Stopwatch()..start() {
    // A response can be returned before its body is consumed. Observe the
    // completion future internally so cancellation/body errors do not become
    // unhandled when callers only use the body stream.
    unawaited(
      _completionMetrics.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
  }

  final DartIoTransport owner;
  final AlphaXRequest alphaRequest;
  final Stopwatch stopwatch;
  final Stopwatch requestStopwatch;
  final Completer<void> _done = Completer<void>();
  final Completer<AlphaXRequestMetrics> _completionMetrics = Completer<AlphaXRequestMetrics>();
  HttpClientRequest? clientRequest;
  HttpClientResponse? response;
  void Function(Object? reason)? onAbort;
  var uploadedBytes = 0;
  var downloadedBytes = 0;
  var _finished = false;
  var _aborted = false;

  Future<void> get done => _done.future;

  Future<AlphaXRequestMetrics> get completionMetrics => _completionMetrics.future;

  void abort([Object? reason]) {
    if (!_aborted) {
      _aborted = true;
      clientRequest?.abort(reason);
    }
    onAbort?.call(reason);
  }

  void finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    owner._remove(this);
    _done.complete();
  }

  void completeMetrics(AlphaXRequestMetrics metrics) {
    if (!_completionMetrics.isCompleted) {
      _completionMetrics.complete(metrics);
    }
  }

  void completeMetricsError(Object error, StackTrace stackTrace) {
    if (!_completionMetrics.isCompleted) {
      _completionMetrics.completeError(error, stackTrace);
    }
  }

  AlphaXRequestMetrics headersMetrics(int redirects) => AlphaXRequestMetrics(
    timeToFirstByte: stopwatch.elapsed,
    uploadedBytes: uploadedBytes,
    negotiatedProtocol: AlphaXProtocol.unknown,
    redirectCount: redirects,
  );

  AlphaXRequestMetrics completedMetrics() => AlphaXRequestMetrics(
    timeToFirstByte: stopwatch.elapsed,
    transferDuration: stopwatch.elapsed,
    totalDuration: stopwatch.elapsed,
    uploadedBytes: uploadedBytes,
    downloadedBytes: downloadedBytes,
    negotiatedProtocol: AlphaXProtocol.unknown,
  );
}
