import 'dart:async';
import 'package:alphax/alphax.dart';
import 'package:flutter/services.dart';

import 'alpha_x_local_file.dart';
import 'apple_url_session_protocol.dart';

/// Apple URLSession transport for iOS and macOS.
///
/// Foundation owns sockets, TLS, HTTP/2, and HTTP/3 negotiation. This Dart
/// facade exposes only AlphaX contracts; URLSession types remain inside the
/// platform plugin. URLSession reports the final negotiated protocol through
/// task metrics at completion. A streamed response may therefore begin with
/// `unknown` protocol metadata and receives the authoritative protocol in its
/// completion metrics.
final class AppleUrlSessionTransport extends AlphaXTransport {
  AppleUrlSessionTransport._(this._methodChannel, this._eventChannel);

  /// Creates and initializes the Apple transport.
  static Future<AppleUrlSessionTransport> create() async {
    final transport = AppleUrlSessionTransport._(
      const MethodChannel('alphax_native/transport'),
      const EventChannel('alphax_native/events'),
    );
    await transport._initialize();
    return transport;
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final Map<String, _AppleOperation> _operations = <String, _AppleOperation>{};
  AlphaXCapabilities _capabilities = const AlphaXCapabilities.unknown();
  StreamSubscription<Object?>? _eventSubscription;
  bool _closed = false;
  Future<void>? _closeFuture;
  int _nextRequestId = 0;

  @override
  AlphaXCapabilities get capabilities => _capabilities;

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    final operation = await _start(request);
    try {
      final started = await operation.started;
      return AlphaXResponse(
        statusCode: started.statusCode,
        headers: started.headers,
        body: AlphaXResponseBody.stream(
          operation.bodyStream,
          contentLength: started.contentLength,
        ),
        negotiatedProtocol: started.protocol,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: started.protocolFallback,
        metrics: started.metrics,
        completionMetrics: operation.completed.then((completed) => completed.metrics),
        redirects: started.redirects,
      );
    } catch (error, stackTrace) {
      operation.dispose();
      throw _normalize(error, stackTrace);
    }
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    final operation = await _start(request);
    try {
      final started = await operation.started;
      yield AlphaXResponseStarted(
        statusCode: started.statusCode,
        headers: started.headers,
        negotiatedProtocol: started.protocol,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: started.protocolFallback,
        redirects: started.redirects,
      );
      await for (final chunk in operation.bodyStream) {
        yield AlphaXResponseChunk(chunk);
      }
      final completed = await operation.completed;
      yield AlphaXResponseCompleted(
        metrics: completed.metrics,
        bytesReceived: completed.bytesReceived,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: appleProtocolFallback(
          started.requestedProtocol,
          completed.metrics.negotiatedProtocol,
        ),
      );
    } catch (error, stackTrace) {
      operation.dispose();
      throw _normalize(error, stackTrace);
    }
  }

  @override
  Future<AlphaXTransferResult> download(
    AlphaXRequest request,
    AlphaXFileTarget target,
  ) async {
    if (target is! AlphaXLocalFileTarget) return super.download(request, target);
    final operation = await _start(request, directDownloadPath: target.path);
    try {
      final started = await operation.started;
      final completed = await operation.completed;
      return AlphaXTransferResult(
        statusCode: started.statusCode,
        headers: started.headers,
        protocol: completed.metrics.negotiatedProtocol,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: appleProtocolFallback(
          started.requestedProtocol,
          completed.metrics.negotiatedProtocol,
        ),
        metrics: completed.metrics,
        redirects: started.redirects,
        bytesTransferred: completed.bytesReceived,
        totalBytes: started.contentLength,
      );
    } catch (error, stackTrace) {
      operation.dispose();
      throw _normalize(error, stackTrace);
    }
  }

  @override
  Future<AlphaXTransferResult> upload(
    AlphaXRequest request,
    AlphaXFileSource source,
  ) async {
    final operation = await _start(request.copyWith(body: AlphaXFileBody(source)));
    try {
      final started = await operation.started;
      await operation.bodyStream.drain<void>();
      final completed = await operation.completed;
      return AlphaXTransferResult(
        statusCode: started.statusCode,
        headers: started.headers,
        protocol: completed.metrics.negotiatedProtocol,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: appleProtocolFallback(
          started.requestedProtocol,
          completed.metrics.negotiatedProtocol,
        ),
        metrics: completed.metrics,
        redirects: started.redirects,
        bytesTransferred: completed.metrics.uploadedBytes ?? 0,
        totalBytes: source.length,
      );
    } catch (error, stackTrace) {
      operation.dispose();
      throw _normalize(error, stackTrace);
    }
  }

  @override
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;
    _closed = true;
    return _closeFuture = _closeOwnedResources();
  }

  Future<void> _closeOwnedResources() async {
    final operations = _operations.values.toList(growable: false);
    for (final operation in operations) {
      unawaited(operation.cancel('AlphaX Apple transport is closed'));
      operation.handleError(
        const AlphaXClientClosedException('Apple transport is closed'),
      );
    }
    try {
      await _methodChannel.invokeMethod<void>('close');
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _methodChannel.setMethodCallHandler(null);
      for (final operation in _operations.values.toList(growable: false)) {
        operation.dispose();
      }
      _operations.clear();
    }
  }

  Future<void> _initialize() async {
    _methodChannel.setMethodCallHandler(_handleNativeMethod);
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        for (final operation in _operations.values.toList(growable: false)) {
          operation.handleError(_normalize(error, stackTrace));
        }
      },
    );
    try {
      final result = await _methodChannel.invokeMethod<Object?>('initialize');
      _capabilities = appleCapabilitiesFromNative(result);
    } catch (error, stackTrace) {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _methodChannel.setMethodCallHandler(null);
      throw _normalize(error, stackTrace);
    }
  }

  Future<_AppleOperation> _start(
    AlphaXRequest request, {
    String? directDownloadPath,
  }) async {
    _ensureUsable(request);
    final requestId = 'alphax-apple-${_nextRequestId++}';
    final operation = _AppleOperation(
      requestId: requestId,
      request: request,
      body: request.body,
      onFinished: () => _operations.remove(requestId),
      grantCredits: (credits) => _methodChannel.invokeMethod<void>(
        'grantCredits',
        <String, Object?>{'requestId': requestId, 'credits': credits},
      ),
      cancelNative: (reason) => _methodChannel.invokeMethod<void>(
        'cancel',
        <String, Object?>{'requestId': requestId, 'reason': reason},
      ),
    );
    _operations[requestId] = operation;
    final token = request.cancellationToken;
    if (token != null) {
      unawaited(token.whenCancelled.then((_) => operation.cancel('The request was cancelled')));
    }
    try {
      await _methodChannel.invokeMethod<void>(
        'start',
        _requestArguments(request, requestId, directDownloadPath),
      );
      return operation;
    } catch (error, stackTrace) {
      _operations.remove(requestId);
      operation.dispose();
      throw _normalize(error, stackTrace);
    }
  }

  Future<Object?> _handleNativeMethod(MethodCall call) async {
    final arguments = _map(call.arguments);
    final requestId = arguments['requestId']?.toString();
    final operation = requestId == null ? null : _operations[requestId];
    switch (call.method) {
      case 'uploadDemand':
        if (operation == null) {
          throw PlatformException(code: 'unknown_request', message: 'Unknown upload request');
        }
        return operation.nextUpload((arguments['maxBytes'] as num?)?.toInt() ?? 0);
      case 'uploadReset':
        if (operation == null) {
          throw PlatformException(code: 'unknown_request', message: 'Unknown upload request');
        }
        await operation.resetUpload();
        return null;
      default:
        throw PlatformException(code: 'not_implemented', message: call.method);
    }
  }

  void _handleEvent(Object? rawEvent) {
    final event = _map(rawEvent);
    final requestId = event['requestId']?.toString();
    final operation = requestId == null ? null : _operations[requestId];
    operation?.handleEvent(event);
  }

  Map<String, Object?> _requestArguments(
    AlphaXRequest request,
    String requestId,
    String? directDownloadPath,
  ) => <String, Object?>{
    'requestId': requestId,
    'method': request.method.value,
    'uri': request.uri.toString(),
    'headers': <String, List<String>>{
      for (final name in request.headers.names) name: request.headers.values(name),
      if (!request.headers.contains('content-type') && request.body.contentType != null)
        'content-type': <String>[request.body.contentType!],
    },
    'body': _bodyArguments(request.body),
    'timeouts': <String, Object?>{
      'connectMs': request.timeouts.connect?.inMilliseconds,
      'requestMs': request.timeouts.request?.inMilliseconds,
      'readMs': request.timeouts.read?.inMilliseconds,
      'overallMs': request.timeouts.overall?.inMilliseconds,
    },
    'redirect': <String, Object?>{
      'mode': request.redirectPolicy.mode.name,
      'maxRedirects': request.redirectPolicy.maxRedirects,
    },
    'protocol': request.protocolPreference.name,
    'priority': request.priority.name,
    'directDownloadPath': directDownloadPath,
  };

  Map<String, Object?> _bodyArguments(AlphaXBody body) {
    if (body is AlphaXEmptyBody) {
      return <String, Object?>{'kind': 'empty', 'length': 0, 'replayable': true};
    }
    if (body case AlphaXBytesBody(:final bytes, :final contentType)) {
      return <String, Object?>{
        'kind': 'bytes',
        'bytes': Uint8List.fromList(bytes),
        'length': bytes.length,
        'contentType': contentType,
        'replayable': true,
      };
    }
    if (body case AlphaXTextBody(:final bytes, :final contentType)) {
      return <String, Object?>{
        'kind': 'bytes',
        'bytes': Uint8List.fromList(bytes),
        'length': bytes.length,
        'contentType': contentType,
        'replayable': true,
      };
    }
    if (body case AlphaXJsonBody(:final bytes)) {
      return <String, Object?>{
        'kind': 'bytes',
        'bytes': Uint8List.fromList(bytes),
        'length': bytes.length,
        'contentType': body.contentType,
        'replayable': true,
      };
    }
    if (body case AlphaXFileBody(:final source, :final contentType)) {
      if (source case AlphaXLocalFileSource(:final path)) {
        return <String, Object?>{
          'kind': 'file',
          'path': path,
          'length': source.length,
          'contentType': contentType,
          'replayable': source.isReplayable,
        };
      }
      return <String, Object?>{
        'kind': 'dart',
        'length': body.contentLength,
        'contentType': contentType,
        'replayable': body.isReplayable,
      };
    }
    return <String, Object?>{
      'kind': 'dart',
      'length': body.contentLength,
      'contentType': body.contentType,
      'replayable': body.isReplayable,
    };
  }

  void _ensureUsable(AlphaXRequest request) {
    if (_closed) throw const AlphaXClientClosedException('Apple transport is closed');
    request.cancellationToken?.throwIfCancelled();
    final capability = switch (request.protocolPreference) {
      AlphaXProtocolPreference.auto => null,
      AlphaXProtocolPreference.http10 => AlphaXCapability.http10,
      AlphaXProtocolPreference.http11 => AlphaXCapability.http11,
      AlphaXProtocolPreference.http2 => AlphaXCapability.http2,
      AlphaXProtocolPreference.http3 => AlphaXCapability.http3,
    };
    if (capability != null && !_capabilities.supports(capability)) {
      throw AlphaXUnsupportedCapabilityException(
        'Apple URLSession does not support ${request.protocolPreference.name}',
        capability: capability,
      );
    }
  }

  AlphaXException _normalize(Object error, StackTrace stackTrace) {
    if (error is AlphaXException) return error;
    if (error is PlatformException) {
      final message = error.message ?? 'The Apple URLSession transport failed';
      return switch (error.code) {
        'dns' => AlphaXDnsException(message, cause: error, stackTrace: stackTrace),
        'connection' => AlphaXConnectionException(message, cause: error, stackTrace: stackTrace),
        'tls' => AlphaXTlsException(message, cause: error, stackTrace: stackTrace),
        'cancellation' => AlphaXCancellationException(
          message,
          cause: error,
          stackTrace: stackTrace,
        ),
        'timeout' => AlphaXTimeoutException(
          message,
          timeoutKind: switch (error.details?.toString()) {
            'connect' => AlphaXTimeoutKind.connect,
            'read' => AlphaXTimeoutKind.read,
            'overall' => AlphaXTimeoutKind.overall,
            _ => AlphaXTimeoutKind.request,
          },
          cause: error,
          stackTrace: stackTrace,
        ),
        'protocol' => AlphaXProtocolException(message, cause: error, stackTrace: stackTrace),
        'redirect' => AlphaXRedirectException(message, cause: error, stackTrace: stackTrace),
        'request_body' => AlphaXRequestBodyException(message, cause: error, stackTrace: stackTrace),
        'response_body' => AlphaXResponseBodyException(
          message,
          cause: error,
          stackTrace: stackTrace,
        ),
        'unsupported_capability' => AlphaXUnsupportedCapabilityException(
          message,
          capability: AlphaXCapability.http3,
          cause: error,
          stackTrace: stackTrace,
        ),
        'client_closed' => AlphaXClientClosedException(message),
        _ => AlphaXTransportException(message, cause: error, stackTrace: stackTrace),
      };
    }
    if (error is MissingPluginException) {
      return AlphaXUnsupportedCapabilityException(
        'The Apple URLSession plugin is unavailable in this application',
        capability: AlphaXCapability.http3,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AlphaXTransportException(
      'The Apple URLSession transport failed',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) return <String, Object?>{};
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
}

final class _AppleOperation {
  _AppleOperation({
    required this.requestId,
    required this.request,
    required this.body,
    required this.onFinished,
    required this.grantCredits,
    required this.cancelNative,
  }) {
    _bodyController = StreamController<List<int>>(
      sync: true,
      onListen: _onListen,
      onPause: _onPause,
      onResume: _onResume,
      onCancel: _onCancel,
    );
    _upload = _AppleUploadCursor(body);
    unawaited(_completed.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
  }

  final String requestId;
  final AlphaXRequest request;
  final AlphaXBody body;
  final void Function() onFinished;
  final Future<void> Function(int credits) grantCredits;
  final Future<void> Function(String reason) cancelNative;
  late final StreamController<List<int>> _bodyController;
  late final _AppleUploadCursor _upload;
  final Completer<_AppleStarted> _started = Completer<_AppleStarted>();
  final Completer<_AppleCompleted> _completed = Completer<_AppleCompleted>();
  bool _paused = false;
  bool _terminal = false;
  bool _creditsGranted = false;
  AlphaXException? _pendingBodyError;
  StackTrace? _pendingBodyErrorStack;

  Future<_AppleStarted> get started => _started.future;
  Future<_AppleCompleted> get completed => _completed.future;
  Stream<List<int>> get bodyStream => _bodyController.stream;

  void handleEvent(Map<String, Object?> event) {
    switch (event['type']?.toString()) {
      case 'started':
        final value = _startedFrom(event);
        if (!_started.isCompleted) {
          _started.complete(value);
          if (_bodyController.hasListener) _grantInitialCredits();
        }
      case 'chunk':
        final bytes = _bytes(event['bytes']);
        if (!_terminal) {
          _bodyController.add(bytes);
          if (!_paused) _grantCreditsSafely(1);
        }
      case 'progress':
        _handleProgress(event);
      case 'completed':
        final value = _completedFrom(event);
        _terminal = true;
        if (!_completed.isCompleted) _completed.complete(value);
        unawaited(_bodyController.close());
        onFinished();
      case 'error':
        handleError(_errorFrom(event));
    }
  }

  void handleError(AlphaXException error) {
    if (_terminal && _completed.isCompleted) return;
    _terminal = true;
    final startedBeforeError = _started.isCompleted;
    if (!startedBeforeError) {
      _started.completeError(error, error.stackTrace ?? StackTrace.current);
    }
    if (!_completed.isCompleted) {
      _completed.completeError(error, error.stackTrace ?? StackTrace.current);
    }
    final errorStack = error.stackTrace ?? StackTrace.current;
    if (!startedBeforeError) {
      unawaited(_bodyController.close());
    } else if (_bodyController.hasListener) {
      _bodyController.addError(error, errorStack);
      unawaited(_bodyController.close());
    } else {
      _pendingBodyError = error;
      _pendingBodyErrorStack = errorStack;
    }
    onFinished();
  }

  Future<void> cancel(String reason) async {
    if (_terminal) return;
    try {
      await cancelNative(reason);
    } catch (error, stackTrace) {
      if (!_terminal) {
        handleError(AlphaXCancellationException(reason, cause: error, stackTrace: stackTrace));
      }
      return;
    }
    if (!_terminal) handleError(AlphaXCancellationException(reason));
  }

  Future<Object?> nextUpload(int maxBytes) async {
    try {
      return <String, Object?>{
        'bytes': await _upload.next(maxBytes),
        'done': _upload.isDone,
      };
    } catch (error, stackTrace) {
      throw PlatformException(
        code: 'request_body',
        message: 'The Dart request body failed: $error',
        details: stackTrace.toString(),
      );
    }
  }

  Future<void> resetUpload() => _upload.reset();

  void dispose() {
    if (!_bodyController.isClosed) unawaited(_bodyController.close());
    unawaited(_upload.close());
  }

  void _onListen() {
    final pendingError = _pendingBodyError;
    if (pendingError != null) {
      _pendingBodyError = null;
      final pendingStack = _pendingBodyErrorStack ?? StackTrace.current;
      _pendingBodyErrorStack = null;
      _bodyController.addError(pendingError, pendingStack);
      unawaited(_bodyController.close());
      return;
    }
    if (_started.isCompleted) _grantInitialCredits();
  }

  void _onPause() => _paused = true;

  void _onResume() {
    _paused = false;
    _grantCreditsSafely(4);
  }

  Future<void> _onCancel() async {
    if (!_terminal) await cancel('The response stream subscription was cancelled');
  }

  void _grantInitialCredits() {
    if (_creditsGranted) return;
    _creditsGranted = true;
    _grantCreditsSafely(4);
  }

  void _grantCreditsSafely(int credits) {
    unawaited(() async {
      if (_terminal) return;
      try {
        await grantCredits(credits);
      } catch (error, stackTrace) {
        if (error is PlatformException && error.code == 'unknown_request') return;
        if (!_terminal) {
          handleError(
            AlphaXTransportException(
              'Apple stream credit delivery failed',
              cause: error,
              stackTrace: stackTrace,
            ),
          );
        }
      }
    }());
  }

  void _handleProgress(Map<String, Object?> event) {
    final progress = AlphaXProgress(
      direction: event['direction']?.toString() == 'upload'
          ? AlphaXTransferDirection.upload
          : AlphaXTransferDirection.download,
      bytesTransferred: (event['bytesTransferred'] as num?)?.toInt() ?? 0,
      totalBytes: (event['totalBytes'] as num?)?.toInt(),
      isComplete: event['isComplete'] == true,
    );
    if (progress.direction == AlphaXTransferDirection.upload) {
      request.onUploadProgress?.call(progress);
      if (body case AlphaXFileBody(:final onProgress?)) onProgress(progress);
    } else {
      request.onDownloadProgress?.call(progress);
    }
  }

  _AppleStarted _startedFrom(Map<String, Object?> event) {
    final protocol = _protocol(event['protocol']);
    final requested = _preference(event['requestedProtocol']);
    final redirects = _redirects(event['redirects']);
    return _AppleStarted(
      statusCode: (event['statusCode'] as num?)?.toInt() ?? 0,
      headers: _headers(event['headers']),
      protocol: protocol,
      requestedProtocol: requested,
      protocolFallback: appleProtocolFallback(requested, protocol),
      redirects: redirects,
      contentLength: (event['contentLength'] as num?)?.toInt(),
      metrics: AlphaXRequestMetrics(
        negotiatedProtocol: protocol,
        redirectCount: redirects.length,
      ),
    );
  }

  _AppleCompleted _completedFrom(Map<String, Object?> event) {
    final metrics = _metrics(event['metrics']);
    final metricValues = AppleUrlSessionTransport._map(event['metrics']);
    return _AppleCompleted(
      metrics: metrics,
      rawProtocol: metricValues['rawProtocol']?.toString(),
      bytesReceived: (event['bytesReceived'] as num?)?.toInt() ?? metrics.downloadedBytes ?? 0,
    );
  }

  AlphaXException _errorFrom(Map<String, Object?> event) {
    final message = event['message']?.toString() ?? 'The Apple request failed';
    return switch (event['kind']?.toString()) {
      'dns' => AlphaXDnsException(message),
      'connection' => AlphaXConnectionException(message),
      'tls' => AlphaXTlsException(message),
      'timeout' => AlphaXTimeoutException(
        message,
        timeoutKind: switch (event['timeoutKind']?.toString()) {
          'connect' => AlphaXTimeoutKind.connect,
          'read' => AlphaXTimeoutKind.read,
          'overall' => AlphaXTimeoutKind.overall,
          _ => AlphaXTimeoutKind.request,
        },
      ),
      'cancellation' => AlphaXCancellationException(message),
      'protocol' => AlphaXProtocolException(message),
      'redirect' => AlphaXRedirectException(message),
      'request_body' => AlphaXRequestBodyException(message),
      'response_body' => AlphaXResponseBodyException(message),
      _ => AlphaXTransportException(message),
    };
  }

  static AlphaXHeaders _headers(Object? raw) {
    final map = AppleUrlSessionTransport._map(raw);
    final entries = <MapEntry<String, String>>[];
    for (final entry in map.entries) {
      final values = entry.value is Iterable ? entry.value as Iterable : <Object?>[entry.value];
      for (final value in values) {
        entries.add(MapEntry<String, String>(entry.key, value.toString()));
      }
    }
    return AlphaXHeaders.fromEntries(entries);
  }

  static List<AlphaXRedirectInfo> _redirects(Object? raw) {
    if (raw is! Iterable) return const <AlphaXRedirectInfo>[];
    return <AlphaXRedirectInfo>[
      for (final item in raw)
        if (item is Map)
          AlphaXRedirectInfo(
            statusCode: (item['statusCode'] as num?)?.toInt() ?? 0,
            from: Uri.parse(item['from'].toString()),
            to: Uri.parse(item['to'].toString()),
            method: item['method']?.toString(),
          ),
    ];
  }

  static AlphaXRequestMetrics _metrics(Object? raw) {
    final values = AppleUrlSessionTransport._map(raw);
    final normalizedProtocol = _protocol(values['protocol']);
    final rawProtocol = _protocol(values['rawProtocol']);
    Duration? duration(String name) {
      final millis = (values[name] as num?)?.toInt();
      return millis == null ? null : Duration(milliseconds: millis);
    }

    return AlphaXRequestMetrics(
      dnsDuration: duration('dnsDurationMs'),
      connectDuration: duration('connectDurationMs'),
      tlsDuration: duration('tlsDurationMs'),
      timeToFirstByte: duration('timeToFirstByteMs'),
      transferDuration: duration('transferDurationMs'),
      totalDuration: duration('totalDurationMs'),
      uploadedBytes: (values['uploadedBytes'] as num?)?.toInt(),
      downloadedBytes: (values['downloadedBytes'] as num?)?.toInt(),
      negotiatedProtocol: normalizedProtocol == AlphaXProtocol.unknown
          ? rawProtocol
          : normalizedProtocol,
      redirectCount: (values['redirectCount'] as num?)?.toInt() ?? 0,
      connectionReused: values['connectionReused'] as bool?,
    );
  }

  static AlphaXProtocol _protocol(Object? value) => switch (value?.toString()) {
    'http10' => AlphaXProtocol.http10,
    'http11' => AlphaXProtocol.http11,
    'http2' => AlphaXProtocol.http2,
    'http3' => AlphaXProtocol.http3,
    _ => AlphaXProtocol.unknown,
  };

  static AlphaXProtocolPreference? _preference(Object? value) => switch (value?.toString()) {
    'auto' || null => null,
    'http10' => AlphaXProtocolPreference.http10,
    'http11' => AlphaXProtocolPreference.http11,
    'http2' => AlphaXProtocolPreference.http2,
    'http3' => AlphaXProtocolPreference.http3,
    _ => null,
  };

  static Uint8List _bytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return Uint8List(0);
  }
}

final class _AppleStarted {
  const _AppleStarted({
    required this.statusCode,
    required this.headers,
    required this.protocol,
    required this.requestedProtocol,
    required this.protocolFallback,
    required this.redirects,
    required this.contentLength,
    required this.metrics,
  });

  final int statusCode;
  final AlphaXHeaders headers;
  final AlphaXProtocol protocol;
  final AlphaXProtocolPreference? requestedProtocol;
  final AlphaXProtocolFallback? protocolFallback;
  final List<AlphaXRedirectInfo> redirects;
  final int? contentLength;
  final AlphaXRequestMetrics metrics;
}

final class _AppleCompleted {
  const _AppleCompleted({
    required this.metrics,
    required this.rawProtocol,
    required this.bytesReceived,
  });

  final AlphaXRequestMetrics metrics;
  final String? rawProtocol;
  final int bytesReceived;
}

final class _AppleUploadCursor {
  _AppleUploadCursor(this.body);

  final AlphaXBody body;
  StreamIterator<List<int>>? _iterator;
  List<int> _remainder = const <int>[];
  bool isDone = false;

  Future<Uint8List> next(int maxBytes) async {
    if (maxBytes <= 0 || isDone) return Uint8List(0);
    _iterator ??= StreamIterator<List<int>>(body.openStream());
    while (_remainder.isEmpty) {
      if (!await _iterator!.moveNext()) {
        isDone = true;
        return Uint8List(0);
      }
      _remainder = _iterator!.current;
    }
    final count = maxBytes < _remainder.length ? maxBytes : _remainder.length;
    final bytes = Uint8List.fromList(_remainder.take(count).toList(growable: false));
    _remainder = _remainder.skip(count).toList(growable: false);
    return bytes;
  }

  Future<void> reset() async {
    await _iterator?.cancel();
    _iterator = null;
    _remainder = const <int>[];
    isDone = false;
  }

  Future<void> close() => _iterator?.cancel() ?? Future<void>.value();
}
