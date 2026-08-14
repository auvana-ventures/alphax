import 'dart:async';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:flutter/services.dart';

import 'android_cronet_protocol.dart';

/// Android transport backed by one provider-selected Cronet/HttpEngine engine.
///
/// Call [create] before using the transport. Initialization is asynchronous so
/// provider capabilities are known before the first request is accepted. The
/// public API exposes only AlphaX contracts; Cronet and platform-channel types
/// remain implementation details of this package.
final class AndroidCronetTransport extends AlphaXTransport {
  AndroidCronetTransport._(this._methodChannel, this._eventChannel);

  /// Creates and initializes the Android transport.
  static Future<AndroidCronetTransport> create() async {
    final transport = AndroidCronetTransport._(
      const MethodChannel('alphax_native/transport'),
      const EventChannel('alphax_native/events'),
    );
    await transport._initialize();
    return transport;
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final Map<String, _AndroidOperation> _operations = <String, _AndroidOperation>{};
  AlphaXCapabilities _capabilities = const AlphaXCapabilities.unknown();
  StreamSubscription<Object?>? _eventSubscription;
  bool _closed = false;
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
    if (target is! AlphaXLocalFileTarget) {
      return super.download(request, target);
    }
    final operation = await _start(request, directDownloadPath: target.path);
    try {
      final started = await operation.started;
      final completed = await operation.completed;
      return AlphaXTransferResult(
        statusCode: started.statusCode,
        headers: started.headers,
        protocol: completed.metrics.negotiatedProtocol,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: started.protocolFallback,
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
    final operation = await _start(
      request.copyWith(body: AlphaXFileBody(source)),
    );
    try {
      final started = await operation.started;
      await operation.bodyStream.drain<void>();
      final completed = await operation.completed;
      return AlphaXTransferResult(
        statusCode: started.statusCode,
        headers: started.headers,
        protocol: completed.metrics.negotiatedProtocol,
        requestedProtocol: started.requestedProtocol,
        protocolFallback: started.protocolFallback,
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
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final operations = _operations.values.toList(growable: false);
    for (final operation in operations) {
      unawaited(operation.cancel('AlphaX Android transport is closed'));
      operation.handleError(
        const AlphaXClientClosedException('Android transport is closed'),
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
      _capabilities = androidCapabilitiesFromNative(result);
    } catch (error, stackTrace) {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _methodChannel.setMethodCallHandler(null);
      throw _normalize(error, stackTrace);
    }
  }

  Future<_AndroidOperation> _start(
    AlphaXRequest request, {
    String? directDownloadPath,
  }) async {
    _ensureUsable(request);
    final requestId = 'alphax-${_nextRequestId++}';
    final operation = _AndroidOperation(
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
      unawaited(
        token.whenCancelled.then((_) => operation.cancel('The request was cancelled')),
      );
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
        final maxBytes = (arguments['maxBytes'] as num?)?.toInt() ?? 0;
        return operation.nextUpload(maxBytes);
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
    'headers': _headersArguments(request),
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

  Map<String, List<String>> _headersArguments(AlphaXRequest request) {
    final headers = <String, List<String>>{
      for (final name in request.headers.names) name: request.headers.values(name),
    };
    final contentType = request.body.contentType;
    if (!request.headers.contains('content-type') && contentType != null) {
      headers['content-type'] = <String>[contentType];
    }
    return headers;
  }

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
    if (_closed) {
      throw const AlphaXClientClosedException('Android transport is closed');
    }
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
        'Android Cronet provider does not support ${request.protocolPreference.name}',
        capability: capability,
      );
    }
  }

  AlphaXException _normalize(Object error, StackTrace stackTrace) {
    if (error is AlphaXException) return error;
    if (error is PlatformException) {
      return switch (error.code) {
        'provider_unavailable' => AlphaXUnsupportedCapabilityException(
          error.message ?? 'No H2/H3-capable Android provider is available',
          capability: AlphaXCapability.http3,
          cause: error,
          stackTrace: stackTrace,
        ),
        'cancellation' => AlphaXCancellationException(
          error.message ?? 'The Android request was cancelled',
          cause: error,
          stackTrace: stackTrace,
        ),
        'timeout' => AlphaXTimeoutException(
          error.message ?? 'The Android request timed out',
          timeoutKind: AlphaXTimeoutKind.request,
          cause: error,
          stackTrace: stackTrace,
        ),
        'request_body' => AlphaXRequestBodyException(
          error.message ?? 'The Android request body failed',
          cause: error,
          stackTrace: stackTrace,
        ),
        'response_body' => AlphaXResponseBodyException(
          error.message ?? 'The Android response body failed',
          cause: error,
          stackTrace: stackTrace,
        ),
        'redirect' => AlphaXRedirectException(
          error.message ?? 'The Android redirect policy failed',
          cause: error,
          stackTrace: stackTrace,
        ),
        _ => AlphaXTransportException(
          error.message ?? 'The Android transport failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      };
    }
    if (error is MissingPluginException) {
      return AlphaXUnsupportedCapabilityException(
        'The Android Cronet plugin is unavailable in this application',
        capability: AlphaXCapability.http3,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AlphaXTransportException(
      'The Android transport failed',
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

final class _AndroidOperation {
  _AndroidOperation({
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
    _upload = _UploadCursor(body);
    // Some request paths (notably cancellation before headers) never await
    // the completion future. Keep its error branch observed while preserving
    // the original error for download/upload callers that do await it.
    unawaited(
      _completed.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
  }

  final String requestId;
  final AlphaXRequest request;
  final AlphaXBody body;
  final void Function() onFinished;
  final Future<void> Function(int credits) grantCredits;
  final Future<void> Function(String reason) cancelNative;
  late final StreamController<List<int>> _bodyController;
  late final _UploadCursor _upload;
  final Completer<_AndroidStarted> _started = Completer<_AndroidStarted>();
  final Completer<_AndroidCompleted> _completed = Completer<_AndroidCompleted>();
  bool _paused = false;
  bool _terminal = false;
  bool _creditsGranted = false;
  AlphaXException? _pendingBodyError;
  StackTrace? _pendingBodyErrorStack;

  Future<_AndroidStarted> get started => _started.future;
  Future<_AndroidCompleted> get completed => _completed.future;
  Stream<List<int>> get bodyStream => _bodyController.stream;

  void handleEvent(Map<String, Object?> event) {
    switch (event['type']?.toString()) {
      case 'started':
        final started = _startedFrom(event);
        if (!_started.isCompleted) {
          _started.complete(started);
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
        final completed = _completedFrom(event);
        _terminal = true;
        if (!_completed.isCompleted) _completed.complete(completed);
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
      // A response can fail between headers and the consumer attaching its
      // listener. Preserve that error for the eventual listener instead of
      // creating an unhandled stream error.
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
        handleError(
          AlphaXCancellationException(
            reason,
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
      return;
    }
    if (!_terminal) {
      handleError(AlphaXCancellationException(reason));
    }
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
        // A credit notification can race with the native completion event.
        // Once terminal, the request has already released its native handle.
        if (error is PlatformException && error.code == 'unknown_request') {
          return;
        }
        if (!_terminal) {
          handleError(
            AlphaXTransportException(
              'Android stream credit delivery failed',
              cause: error,
              stackTrace: stackTrace,
            ),
          );
        }
      }
    }());
  }

  void _handleProgress(Map<String, Object?> event) {
    final direction = event['direction']?.toString();
    final bytes = (event['bytesTransferred'] as num?)?.toInt() ?? 0;
    final total = (event['totalBytes'] as num?)?.toInt();
    final progress = AlphaXProgress(
      direction: direction == 'upload'
          ? AlphaXTransferDirection.upload
          : AlphaXTransferDirection.download,
      bytesTransferred: bytes,
      totalBytes: total,
      isComplete: event['isComplete'] == true,
    );
    if (progress.direction == AlphaXTransferDirection.upload) {
      request.onUploadProgress?.call(progress);
      if (body case AlphaXFileBody(:final onProgress?)) onProgress(progress);
    } else {
      request.onDownloadProgress?.call(progress);
    }
  }

  _AndroidStarted _startedFrom(Map<String, Object?> event) {
    final protocol = _protocol(event['protocol']);
    final requested = _preference(event['requestedProtocol']);
    return _AndroidStarted(
      statusCode: (event['statusCode'] as num?)?.toInt() ?? 0,
      headers: _headers(event['headers']),
      protocol: protocol,
      requestedProtocol: requested,
      protocolFallback: androidProtocolFallback(requested, protocol),
      redirects: _redirects(event['redirects']),
      contentLength: (event['contentLength'] as num?)?.toInt(),
      metrics: AlphaXRequestMetrics(
        negotiatedProtocol: protocol,
        redirectCount: _redirects(event['redirects']).length,
      ),
    );
  }

  _AndroidCompleted _completedFrom(Map<String, Object?> event) {
    final metrics = _metrics(event['metrics']);
    return _AndroidCompleted(
      metrics: metrics,
      bytesReceived: (event['bytesReceived'] as num?)?.toInt() ?? metrics.downloadedBytes ?? 0,
    );
  }

  AlphaXException _errorFrom(Map<String, Object?> event) {
    final message = event['message']?.toString() ?? 'The Android request failed';
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
    final map = AndroidCronetTransport._map(raw);
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
    final values = AndroidCronetTransport._map(raw);
    final protocol = _protocol(values['protocol']);
    Duration? duration(String name) {
      final millis = (values[name] as num?)?.toInt();
      return millis == null ? null : Duration(milliseconds: millis);
    }

    return AlphaXRequestMetrics(
      timeToFirstByte: duration('timeToFirstByteMs'),
      transferDuration: duration('transferDurationMs'),
      totalDuration: duration('totalDurationMs'),
      uploadedBytes: (values['uploadedBytes'] as num?)?.toInt(),
      downloadedBytes: (values['downloadedBytes'] as num?)?.toInt(),
      negotiatedProtocol: protocol,
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

final class _AndroidStarted {
  const _AndroidStarted({
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

final class _AndroidCompleted {
  const _AndroidCompleted({required this.metrics, required this.bytesReceived});

  final AlphaXRequestMetrics metrics;
  final int bytesReceived;
}

final class _UploadCursor {
  _UploadCursor(this.body);

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

/// A replayable local file source that can be consumed by Dart IO or native
/// Android file upload without exposing a file descriptor in the AlphaX API.
final class AlphaXLocalFileSource implements AlphaXFileSource {
  /// Creates a local file source from [path].
  AlphaXLocalFileSource(this.path, {this.isReplayable = true});

  /// Local path retained for native file-backed adapters.
  final String path;

  @override
  final bool isReplayable;

  @override
  String get name => path;

  @override
  int get length => File(path).lengthSync();

  @override
  Stream<List<int>> openRead() => File(path).openRead();
}

/// A local file destination that can be handled directly by native Android.
final class AlphaXLocalFileTarget implements AlphaXFileTarget {
  /// Creates a local file target from [path].
  AlphaXLocalFileTarget(this.path);

  /// Local path retained for native file-backed adapters.
  final String path;

  @override
  String get name => path;

  @override
  Future<AlphaXFileSink> openWrite() async => _LocalFileSink(File(path).openWrite());
}

final class _LocalFileSink implements AlphaXFileSink {
  _LocalFileSink(this._sink);

  final IOSink _sink;

  @override
  void add(List<int> bytes) => _sink.add(bytes);

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() => _sink.close();

  @override
  Future<void> abort() async {
    await _sink.flush();
    await _sink.close();
  }
}
