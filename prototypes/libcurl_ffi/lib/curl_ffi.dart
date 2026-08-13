import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:ffi/ffi.dart';

/// Native libcurl result layout.
final class NativeAxCurlResult extends Struct {
  /// HTTP status code.
  @Int64()
  external int statusCode;

  /// Number of response bytes.
  @Uint64()
  external int bytesReceived;

  /// DNS lookup duration in milliseconds.
  @Double()
  external double nameLookupMs;

  /// Connection duration in milliseconds.
  @Double()
  external double connectMs;

  /// TLS duration in milliseconds.
  @Double()
  external double tlsMs;

  /// Time to first byte in milliseconds.
  @Double()
  external double timeToFirstByteMs;

  /// Total duration in milliseconds.
  @Double()
  external double totalMs;

  /// libcurl result code.
  @Int32()
  external int curlCode;

  /// libcurl HTTP version code.
  @Int32()
  external int httpVersion;

  @Uint64()
  external int requestCreatedNs;

  @Uint64()
  external int bodyPreparationStartNs;

  @Uint64()
  external int bodyPreparationEndNs;

  @Uint64()
  external int easyHandleConfiguredNs;

  @Uint64()
  external int multiAddHandleNs;

  @Uint64()
  external int firstUploadCallbackNs;

  @Uint64()
  external int firstUploadByteNs;

  @Uint64()
  external int lastUploadByteNs;

  @Uint64()
  external int serverBodyReadUs;

  @Uint64()
  external int responseHeadersNs;

  @Uint64()
  external int responseBodyCompleteNs;

  @Uint64()
  external int curlDoneNs;

  @Uint64()
  external int nativeCompletionNotificationNs;

  @Uint64()
  external int nativeCleanupNs;

  @Uint64()
  external int eventLoopWaitCount;

  @Uint64()
  external int eventLoopWaitNs;

  @Uint64()
  external int eventLoopMaxWaitNs;

  @Uint64()
  external int uploadCallbackCount;

  @Uint64()
  external int uploadBytesRead;

  @Uint64()
  external int uploadBytesSubmitted;

  @Uint64()
  external int responseCallbackCount;

  @Uint64()
  external int responseBytesDelivered;

  @Uint64()
  external int streamChunkSize;

  @Uint64()
  external int streamWindowChunks;

  @Uint64()
  external int streamMaxInFlightChunks;

  @Uint64()
  external int streamMaxBufferedBytes;

  @Uint64()
  external int streamChunkNotifications;

  @Uint64()
  external int streamCreditExhaustedCount;

  @Uint64()
  external int streamPauseCount;

  @Uint64()
  external int streamResumeCount;

  @Uint64()
  external int streamPauseWaitNs;

  @Uint64()
  external int streamResumeLatencyNs;

  @Uint64()
  external int streamAckCount;

  @Uint64()
  external int streamAckedBytes;

  @Uint64()
  external int streamInFlightChunksAtCompletion;

  @Uint64()
  external int streamBufferedBytesAtCompletion;

  @Uint64()
  external int streamQueueCapacityBytes;
}

typedef _GetNative = Int32 Function(Pointer<Utf8>, Pointer<NativeAxCurlResult>);
typedef _GetDart = int Function(Pointer<Utf8>, Pointer<NativeAxCurlResult>);
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _StreamStartNative =
    Void Function(
      Int64,
      Pointer<Uint8>,
      Uint64,
      Pointer<Void>,
    );
typedef _StreamChunkNative = Void Function(Pointer<Uint8>, Uint64, Pointer<Void>);
typedef _StreamCompleteNative =
    Void Function(
      Pointer<NativeAxCurlResult>,
      Int32,
      Pointer<Void>,
    );

typedef _RequestStartNative =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Int32,
      Pointer<Uint8>,
      Uint64,
      Pointer<Utf8>,
      Int32,
      Pointer<NativeFunction<_StreamStartNative>>,
      Pointer<NativeFunction<_StreamChunkNative>>,
      Pointer<NativeFunction<_StreamCompleteNative>>,
      Pointer<Void>,
    );
typedef _RequestStartDart =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Utf8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<NativeFunction<_StreamStartNative>>,
      Pointer<NativeFunction<_StreamChunkNative>>,
      Pointer<NativeFunction<_StreamCompleteNative>>,
      Pointer<Void>,
    );
typedef _RequestCancelNative = Int32 Function(Pointer<Void>);
typedef _RequestCancelDart = int Function(Pointer<Void>);
typedef _StreamAckNative = Int32 Function(Pointer<Void>, Uint64, Uint64);
typedef _StreamAckDart = int Function(Pointer<Void>, int, int);
typedef _RequestFreeNative = Void Function(Pointer<Void>);
typedef _RequestFreeDart = void Function(Pointer<Void>);
typedef _FreeBufferNative = Void Function(Pointer<Uint8>);
typedef _FreeBufferDart = void Function(Pointer<Uint8>);
typedef _ClientCreateNative = Pointer<Void> Function();
typedef _ClientCreateDart = Pointer<Void> Function();
typedef _ClientFreeNative = Void Function(Pointer<Void>);
typedef _ClientFreeDart = void Function(Pointer<Void>);
typedef _ClientSetStreamConfigNative = Int32 Function(Pointer<Void>, Uint64, Uint64);
typedef _ClientSetStreamConfigDart = int Function(Pointer<Void>, int, int);

/// Dart wrapper around the libcurl prototype C ABI.
final class CurlFfiClient implements BenchmarkTransport {
  /// Loads the shared library at [path].
  CurlFfiClient.fromPath(
    String path, {
    int streamChunkSize = 64 * 1024,
    int streamWindowChunks = 4,
  }) : _library = DynamicLibrary.open(path),
       streamChunkSize = streamChunkSize,
       streamWindowChunks = streamWindowChunks {
    _validateStreamConfig(streamChunkSize, streamWindowChunks);
    _get = _library.lookupFunction<_GetNative, _GetDart>('ax_curl_get');
    _version = _library.lookupFunction<_VersionNative, _VersionDart>('ax_curl_version');
    _requestStart = _library.lookupFunction<_RequestStartNative, _RequestStartDart>(
      'ax_curl_request_start',
    );
    _requestCancel = _library.lookupFunction<_RequestCancelNative, _RequestCancelDart>(
      'ax_curl_request_cancel',
    );
    _streamAck = _library.lookupFunction<_StreamAckNative, _StreamAckDart>('ax_curl_stream_ack');
    _requestFree = _library.lookupFunction<_RequestFreeNative, _RequestFreeDart>(
      'ax_curl_request_free',
    );
    _freeBuffer = _library.lookupFunction<_FreeBufferNative, _FreeBufferDart>(
      'ax_curl_free_buffer',
    );
    _clientCreate = _library.lookupFunction<_ClientCreateNative, _ClientCreateDart>(
      'ax_curl_client_create',
    );
    _clientFree = _library.lookupFunction<_ClientFreeNative, _ClientFreeDart>(
      'ax_curl_client_free',
    );
    _clientSetStreamConfig = _library
        .lookupFunction<_ClientSetStreamConfigNative, _ClientSetStreamConfigDart>(
          'ax_curl_client_set_stream_config',
        );
    _clientHandle = _clientCreate();
    if (_clientHandle == nullptr) {
      throw StateError('unable to create libcurl shared client state');
    }
    if (_clientSetStreamConfig(_clientHandle, streamChunkSize, streamWindowChunks) != 0) {
      _clientFree(_clientHandle);
      throw StateError('unable to configure libcurl bounded stream state');
    }
    _startCallback = NativeCallable<_StreamStartNative>.listener(_handleStart);
    _chunkCallback = NativeCallable<_StreamChunkNative>.listener(_handleChunk);
    _completeCallback = NativeCallable<_StreamCompleteNative>.listener(_handleComplete);
  }

  final DynamicLibrary _library;

  /// Experimental native response chunk size used by the benchmark harness.
  final int streamChunkSize;

  /// Experimental native response credit window used by the benchmark harness.
  final int streamWindowChunks;

  late final _GetDart _get;
  late final _VersionDart _version;
  late final _RequestStartDart _requestStart;
  late final _RequestCancelDart _requestCancel;
  late final _StreamAckDart _streamAck;
  late final _RequestFreeDart _requestFree;
  late final _FreeBufferDart _freeBuffer;
  late final _ClientCreateDart _clientCreate;
  late final _ClientFreeDart _clientFree;
  late final _ClientSetStreamConfigDart _clientSetStreamConfig;
  late final Pointer<Void> _clientHandle;
  late final NativeCallable<_StreamStartNative> _startCallback;
  late final NativeCallable<_StreamChunkNative> _chunkCallback;
  late final NativeCallable<_StreamCompleteNative> _completeCallback;
  final Map<int, _CurlOperation> _operations = <int, _CurlOperation>{};
  bool _closed = false;

  @override
  String get name => 'libcurl_ffi';

  /// Native libcurl version string.
  String get version => _version().toDartString();

  /// Performs one blocking GET through the legacy libcurl smoke-test ABI.
  CurlFfiResult get(Uri url) {
    return using((arena) {
      final urlPointer = url.toString().toNativeUtf8(allocator: arena);
      final resultPointer = arena<NativeAxCurlResult>();
      final code = _get(urlPointer, resultPointer);
      final result = resultPointer.ref;
      if (code != 0) {
        throw StateError('libcurl prototype request failed with code $code');
      }
      return CurlFfiResult(
        statusCode: result.statusCode,
        bytesReceived: result.bytesReceived,
        totalMs: result.totalMs,
        curlCode: result.curlCode,
        httpVersion: result.httpVersion,
      );
    });
  }

  @override
  Future<BenchmarkResponse> getBytes(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final operation = _createOperation(
      uri: uri,
      requestKind: _requestGet,
      options: options,
    );
    final body = <int>[];
    BenchmarkStreamCompleted? completed;
    await for (final event in operation.stream) {
      if (event case BenchmarkStreamChunk(:final bytes)) {
        body.addAll(bytes);
      } else if (event case BenchmarkStreamCompleted event) {
        completed = event;
      }
    }
    final result = completed;
    if (result == null) {
      throw StateError('libcurl request completed without a terminal event');
    }
    return BenchmarkResponse(
      statusCode: result.statusCode,
      headers: result.headers,
      bodyBytes: body,
      elapsed: operation.stopwatch.elapsed,
      timeToFirstByte: result.timeToFirstByte,
      diagnostics: {
        ...result.diagnostics,
        'dart_future_completed_us': operation.stopwatch.elapsed.inMicroseconds,
      },
    );
  }

  @override
  Stream<BenchmarkStreamEvent> getStreaming(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) => _createOperation(
    uri: uri,
    requestKind: _requestGet,
    options: options,
  ).stream;

  @override
  Future<BenchmarkResponse> postBytes(
    Uri uri,
    List<int> body, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final operation = _createOperation(
      uri: uri,
      requestKind: _requestPostBytes,
      body: body,
      options: options,
    );
    final responseBody = <int>[];
    BenchmarkStreamCompleted? completed;
    await for (final event in operation.stream) {
      if (event case BenchmarkStreamChunk(:final bytes)) {
        responseBody.addAll(bytes);
      } else if (event case BenchmarkStreamCompleted event) {
        completed = event;
      }
    }
    final result = completed;
    if (result == null) {
      throw StateError('libcurl POST completed without a terminal event');
    }
    return BenchmarkResponse(
      statusCode: result.statusCode,
      headers: result.headers,
      bodyBytes: responseBody,
      elapsed: operation.stopwatch.elapsed,
      timeToFirstByte: result.timeToFirstByte,
      diagnostics: {
        ...result.diagnostics,
        'dart_future_completed_us': operation.stopwatch.elapsed.inMicroseconds,
      },
    );
  }

  @override
  Future<BenchmarkTransferResult> uploadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final stopwatch = Stopwatch()..start();
    final filePreparationStopwatch = Stopwatch()..start();
    final bytesToTransfer = await File(filePath).length();
    filePreparationStopwatch.stop();
    final operation = _createOperation(
      uri: uri,
      requestKind: _requestUploadFile,
      filePath: filePath,
      options: options,
      stopwatch: stopwatch,
    );
    final completed = await _consumeTransfer(operation);
    final elapsed = stopwatch.elapsed;
    return BenchmarkTransferResult(
      statusCode: completed.statusCode,
      headers: completed.headers,
      bytesTransferred: bytesToTransfer,
      elapsed: elapsed,
      filePath: filePath,
      timeToFirstByte: completed.timeToFirstByte,
      diagnostics: {
        ...completed.diagnostics,
        'dart_file_preparation_us': filePreparationStopwatch.elapsed.inMicroseconds,
        'dart_future_completed_us': elapsed.inMicroseconds,
      },
    );
  }

  @override
  Future<BenchmarkTransferResult> downloadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final operation = _createOperation(
      uri: uri,
      requestKind: _requestDownloadFile,
      filePath: filePath,
      options: options,
    );
    final completed = await _consumeTransfer(operation);
    final elapsed = operation.stopwatch.elapsed;
    return BenchmarkTransferResult(
      statusCode: completed.statusCode,
      headers: completed.headers,
      bytesTransferred: completed.bytesTransferred,
      elapsed: elapsed,
      filePath: filePath,
      timeToFirstByte: completed.timeToFirstByte,
      diagnostics: {
        ...completed.diagnostics,
        'dart_future_completed_us': elapsed.inMicroseconds,
      },
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    final operations = List<_CurlOperation>.of(_operations.values);
    for (final operation in operations) {
      _cancel(operation);
    }
    await Future.wait<void>(operations.map((operation) => operation.done.future));
    _startCallback.close();
    _chunkCallback.close();
    _completeCallback.close();
    _clientFree(_clientHandle);
  }

  static const int _requestGet = 0;
  static const int _requestPostBytes = 1;
  static const int _requestUploadFile = 2;
  static const int _requestDownloadFile = 3;

  Future<BenchmarkStreamCompleted> _consumeTransfer(_CurlOperation operation) async {
    BenchmarkStreamCompleted? completed;
    await for (final event in operation.stream) {
      if (event case BenchmarkStreamCompleted event) {
        completed = event;
      }
    }
    final result = completed;
    if (result == null) {
      throw StateError('libcurl transfer completed without a terminal event');
    }
    return result;
  }

  _CurlOperation _createOperation({
    required Uri uri,
    required int requestKind,
    required BenchmarkRequestOptions options,
    List<int> body = const <int>[],
    String? filePath,
    Stopwatch? stopwatch,
  }) {
    if (_closed) {
      throw StateError('libcurl transport is closed');
    }
    final controller = StreamController<BenchmarkStreamEvent>();
    final operation = _CurlOperation(
      controller: controller,
      uri: uri,
      requestKind: requestKind,
      options: options,
      body: body,
      filePath: filePath,
      stopwatch: stopwatch,
    );
    controller.onListen = () => _start(operation);
    controller.onCancel = () {
      if (!operation.completed) {
        operation.suppressError = true;
        _cancel(operation);
      }
    };
    final cancellation = options.cancellation;
    if (cancellation != null) {
      unawaited(
        cancellation.whenCancelled.then((_) {
          if (!operation.completed) {
            _cancel(operation);
          }
        }),
      );
    }
    final observedStream = _observeStream(controller.stream, operation);
    if (options.timeout != null) {
      final timedStream = observedStream.timeout(
        options.timeout!,
        onTimeout: (sink) {
          operation.timedOut = true;
          operation.suppressError = true;
          _cancel(operation);
          sink.addError(const BenchmarkTimeoutException());
          sink.close();
        },
      );
      operation.stream = timedStream;
    } else {
      operation.stream = observedStream;
    }
    return operation;
  }

  void _start(_CurlOperation operation) {
    if (operation.completed || operation.handle != nullptr) {
      return;
    }
    if (operation.options.cancellation?.isCancelled ?? false) {
      operation.cancelled = true;
      _finishWithoutNative(operation, const BenchmarkCancelledException());
      return;
    }
    operation.userData = calloc<Uint8>(1).cast<Void>();
    _operations[operation.userData.address] = operation;
    final bodyPointer = calloc<Uint8>(operation.body.length);
    Pointer<Void> handle;
    try {
      handle = using((arena) {
        final urlPointer = operation.uri.toString().toNativeUtf8(allocator: arena);
        final filePointer = operation.filePath?.toNativeUtf8(allocator: arena) ?? nullptr;
        if (operation.body.isNotEmpty) {
          bodyPointer.asTypedList(operation.body.length).setAll(0, operation.body);
        }
        return _requestStart(
          _clientHandle,
          urlPointer,
          operation.requestKind,
          operation.body.isEmpty ? nullptr : bodyPointer,
          operation.body.length,
          filePointer,
          operation.options.followRedirects ? 1 : 0,
          _startCallback.nativeFunction,
          _chunkCallback.nativeFunction,
          _completeCallback.nativeFunction,
          operation.userData,
        );
      });
    } finally {
      calloc.free(bodyPointer);
    }
    if (handle == nullptr) {
      _operations.remove(operation.userData.address);
      calloc.free(operation.userData);
      operation.userData = nullptr;
      _finishWithoutNative(operation, StateError('unable to start libcurl request'));
      return;
    }
    if (operation.completed) {
      _requestFree(handle);
      return;
    }
    operation.handle = handle;
    if (operation.pendingAckChunks > 0) {
      _streamAck(
        handle,
        operation.pendingAckChunks,
        operation.pendingAckBytes,
      );
      operation.pendingAckChunks = 0;
      operation.pendingAckBytes = 0;
    }
    if (operation.cancelled) {
      _requestCancel(handle);
    }
  }

  void _cancel(_CurlOperation operation) {
    operation.cancelled = true;
    if (operation.handle != nullptr) {
      _requestCancel(operation.handle);
    }
  }

  void _finishWithoutNative(_CurlOperation operation, Object error) {
    operation.completed = true;
    if (!operation.controller.isClosed && !operation.suppressError) {
      operation.controller.addError(error);
    }
    if (!operation.controller.isClosed) {
      unawaited(operation.controller.close());
    }
    if (!operation.done.isCompleted) {
      operation.done.complete();
    }
  }

  void _handleStart(int statusCode, Pointer<Uint8> pointer, int length, Pointer<Void> userData) {
    try {
      final operation = _operations[userData.address];
      if (operation == null || operation.completed || operation.started) {
        return;
      }
      final headers = _parseHeaders(_copyNativeBuffer(pointer, length));
      operation.started = true;
      operation.statusCode = statusCode;
      operation.headers = headers;
      operation.timeToFirstByte = operation.stopwatch.elapsed;
      if (!operation.controller.isClosed && !operation.suppressError) {
        operation.controller.add(
          BenchmarkStreamStarted(statusCode: statusCode, headers: headers),
        );
      }
    } finally {
      if (pointer != nullptr) {
        _freeBuffer(pointer);
      }
    }
  }

  void _handleChunk(Pointer<Uint8> pointer, int length, Pointer<Void> userData) {
    try {
      final operation = _operations[userData.address];
      if (operation == null || operation.completed || operation.cancelled) {
        return;
      }
      final bytes = _copyNativeBuffer(pointer, length);
      operation.bytesReceived += bytes.length;
      operation.producedChunkCount++;
      operation.producedBytes += bytes.length;
      operation.pendingBytes += bytes.length;
      if (operation.pendingBytes > operation.maxPendingBytes) {
        operation.maxPendingBytes = operation.pendingBytes;
      }
      if (!operation.controller.isClosed && !operation.suppressError) {
        operation.controller.add(BenchmarkStreamChunk(bytes));
      }
    } finally {
      if (pointer != nullptr) {
        _freeBuffer(pointer);
      }
    }
  }

  void _handleComplete(Pointer<NativeAxCurlResult> pointer, int curlCode, Pointer<Void> userData) {
    final operation = _operations[userData.address];
    if (operation == null || operation.completed) {
      return;
    }
    final nativeResult = pointer.ref;
    operation.nativeCompletionPendingBytes = operation.pendingBytes;
    operation.nativeCompletionConsumedChunkCount = operation.consumedChunkCount;
    operation.nativeCompletionConsumedBytes = operation.consumedBytes;
    operation.completed = true;
    operation.diagnostics = _nativeDiagnostics(nativeResult);
    _updateStreamDiagnostics(operation);
    operation.diagnostics['dart_completion_notification_us'] =
        operation.stopwatch.elapsed.inMicroseconds;
    operation.statusCode = operation.statusCode == 0
        ? nativeResult.statusCode
        : operation.statusCode;
    final error = curlCode == 0
        ? null
        : operation.timedOut
        ? const BenchmarkTimeoutException()
        : operation.cancelled
        ? const BenchmarkCancelledException()
        : StateError('libcurl request failed with code $curlCode');
    if (!operation.started) {
      operation.started = true;
      operation.timeToFirstByte = operation.stopwatch.elapsed;
      if (!operation.controller.isClosed && error == null) {
        operation.controller.add(
          BenchmarkStreamStarted(statusCode: operation.statusCode, headers: operation.headers),
        );
      }
    }
    if (!operation.controller.isClosed && !operation.suppressError) {
      if (error != null) {
        operation.controller.addError(error);
      } else {
        operation.controller.add(
          BenchmarkStreamCompleted(
            statusCode: operation.statusCode,
            headers: operation.headers,
            bytesTransferred: nativeResult.bytesReceived,
            elapsed: operation.stopwatch.elapsed,
            timeToFirstByte: operation.timeToFirstByte,
            diagnostics: operation.diagnostics,
          ),
        );
      }
    }
    final nativeHandle = operation.handle;
    _operations.remove(userData.address);
    calloc.free(userData);
    operation.userData = nullptr;
    operation.handle = nullptr;
    if (nativeHandle != nullptr) {
      // The completion callback runs on the native worker thread. Defer the
      // join/free until the callback has returned to avoid joining ourselves.
      scheduleMicrotask(() {
        _requestFree(nativeHandle);
        operation.diagnostics['dart_handle_cleanup_returned_us'] =
            operation.stopwatch.elapsed.inMicroseconds;
        if (!operation.controller.isClosed) {
          unawaited(operation.controller.close());
        }
        if (!operation.done.isCompleted) {
          operation.done.complete();
        }
      });
    } else {
      if (!operation.controller.isClosed) {
        unawaited(operation.controller.close());
      }
      if (!operation.done.isCompleted) {
        operation.done.complete();
      }
    }
  }

  static List<int> _copyNativeBuffer(Pointer<Uint8> pointer, int length) {
    if (pointer == nullptr || length == 0) {
      return const <int>[];
    }
    return List<int>.from(pointer.asTypedList(length));
  }

  Stream<BenchmarkStreamEvent> _observeStream(
    Stream<BenchmarkStreamEvent> source,
    _CurlOperation operation,
  ) async* {
    await for (final event in source) {
      if (event case BenchmarkStreamChunk(:final bytes)) {
        operation.consumedChunkCount++;
        operation.consumedBytes += bytes.length;
        operation.pendingBytes = operation.pendingBytes > bytes.length
            ? operation.pendingBytes - bytes.length
            : 0;
        _updateStreamDiagnostics(operation);
      }
      yield event;
      if (event case BenchmarkStreamChunk(:final bytes)) {
        _acknowledgeChunk(operation, bytes.length);
      }
    }
  }

  void _acknowledgeChunk(_CurlOperation operation, int byteCount) {
    if (operation.completed) {
      return;
    }
    if (operation.handle == nullptr) {
      operation.pendingAckChunks++;
      operation.pendingAckBytes += byteCount;
      return;
    }
    _streamAck(operation.handle, 1, byteCount);
  }

  static void _updateStreamDiagnostics(_CurlOperation operation) {
    final flow = operation.diagnostics['stream_flow_control'];
    final flowMetrics = flow is Map ? Map<String, Object?>.from(flow) : null;
    operation.streamDiagnostics
      ..['producer_chunk_count'] = operation.producedChunkCount
      ..['producer_bytes'] = operation.producedBytes
      ..['consumer_chunk_count'] = operation.consumedChunkCount
      ..['consumer_bytes'] = operation.consumedBytes
      ..['max_buffered_bytes'] = flowMetrics?['max_buffered_bytes'] ?? operation.maxPendingBytes
      ..['dart_queue_max_pending_bytes'] = operation.maxPendingBytes
      ..['buffered_bytes_current'] = operation.pendingBytes
      ..['buffered_bytes_at_native_completion'] = operation.nativeCompletionPendingBytes
      ..['consumer_chunk_count_at_native_completion'] = operation.nativeCompletionConsumedChunkCount
      ..['consumer_bytes_at_native_completion'] = operation.nativeCompletionConsumedBytes
      ..['queue_capacity_bytes'] = flowMetrics?['queue_capacity_bytes']
      ..['queue_policy'] = flowMetrics == null
          ? 'Dart StreamController response subscription controls upstream reads'
          : 'native credit/ack window bounds FFI-delivered chunks'
      ..['pause_supported'] = flowMetrics != null
      ..['pause_count'] = flowMetrics?['pause_count']
      ..['resume_count'] = flowMetrics?['resume_count']
      ..['pause_latency_us'] = flowMetrics?['pause_latency_us']
      ..['resume_latency_us'] = flowMetrics?['resume_latency_us']
      ..['pause_behavior'] = flowMetrics == null
          ? 'Dart response subscription pauses while the consumer awaits each chunk'
          : 'native response delivery waits for Dart chunk acknowledgments when credits are exhausted';
    operation.diagnostics['stream_metrics'] = operation.streamDiagnostics;
  }

  static Map<String, Object?> _nativeDiagnostics(NativeAxCurlResult result) {
    int? offsetUs(int timestamp) {
      if (timestamp == 0 || result.requestCreatedNs == 0 || timestamp < result.requestCreatedNs) {
        return null;
      }
      return ((timestamp - result.requestCreatedNs) / 1000).round();
    }

    return <String, Object?>{
      'libcurl_lifecycle': <String, Object?>{
        'request_created_ns': result.requestCreatedNs,
        'body_preparation_start_us': offsetUs(result.bodyPreparationStartNs),
        'body_preparation_end_us': offsetUs(result.bodyPreparationEndNs),
        'easy_handle_configured_us': offsetUs(result.easyHandleConfiguredNs),
        'multi_add_handle_us': offsetUs(result.multiAddHandleNs),
        'first_upload_callback_us': offsetUs(result.firstUploadCallbackNs),
        'first_upload_byte_us': offsetUs(result.firstUploadByteNs),
        'last_upload_byte_us': offsetUs(result.lastUploadByteNs),
        'response_headers_us': offsetUs(result.responseHeadersNs),
        'response_body_complete_us': offsetUs(result.responseBodyCompleteNs),
        'curl_done_us': offsetUs(result.curlDoneNs),
        'native_completion_notification_us': offsetUs(result.nativeCompletionNotificationNs),
        'native_cleanup_us': offsetUs(result.nativeCleanupNs),
        'server_body_read_us': result.serverBodyReadUs == 0 ? null : result.serverBodyReadUs,
      },
      'libcurl_event_loop': <String, Object?>{
        'poll_count': result.eventLoopWaitCount,
        'poll_wait_us': result.eventLoopWaitNs ~/ 1000,
        'max_poll_wait_us': result.eventLoopMaxWaitNs ~/ 1000,
      },
      'libcurl_callbacks': <String, Object?>{
        'upload_read_callbacks': result.uploadCallbackCount,
        'upload_bytes_read': result.uploadBytesRead,
        'upload_bytes_submitted': result.uploadBytesSubmitted,
        'response_callbacks': result.responseCallbackCount,
        'response_bytes_delivered': result.responseBytesDelivered,
      },
      'stream_flow_control': <String, Object?>{
        'chunk_size_bytes': result.streamChunkSize,
        'window_chunks': result.streamWindowChunks,
        'queue_capacity_bytes': result.streamQueueCapacityBytes,
        'max_in_flight_chunks': result.streamMaxInFlightChunks,
        'max_buffered_bytes': result.streamMaxBufferedBytes,
        'ffi_notifications': result.streamChunkNotifications,
        'credit_exhausted_count': result.streamCreditExhaustedCount,
        'pause_count': result.streamPauseCount,
        'resume_count': result.streamResumeCount,
        'pause_latency_us': result.streamPauseCount == 0
            ? null
            : (result.streamPauseWaitNs / result.streamPauseCount / 1000).round(),
        'resume_latency_us': result.streamResumeCount == 0
            ? null
            : (result.streamResumeLatencyNs / result.streamResumeCount / 1000).round(),
        'ack_count': result.streamAckCount,
        'acked_bytes': result.streamAckedBytes,
        'in_flight_chunks_at_completion': result.streamInFlightChunksAtCompletion,
        'buffered_bytes_at_completion': result.streamBufferedBytesAtCompletion,
      },
      'libcurl_metrics': <String, Object?>{
        'curl_total_ms': result.totalMs,
        'curl_ttfb_ms': result.timeToFirstByteMs,
        'curl_http_version_code': result.httpVersion,
        'curl_http_version': _curlHttpVersionName(result.httpVersion),
      },
    };
  }

  static String _curlHttpVersionName(int code) => switch (code) {
    0 => 'none',
    1 => 'http/1.0',
    2 => 'http/1.1',
    3 => 'http/2',
    30 => 'http/3',
    _ => 'unknown:$code',
  };

  static Map<String, List<String>> _parseHeaders(List<int> bytes) {
    final text = String.fromCharCodes(bytes);
    final headers = <String, List<String>>{};
    for (final line in text.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('HTTP/')) {
        headers.clear();
        continue;
      }
      final separator = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final name = line.substring(0, separator).trim().toLowerCase();
      final value = line.substring(separator + 1).trim();
      headers.putIfAbsent(name, () => <String>[]).add(value);
    }
    return headers;
  }

  /// Opens the platform-default prototype library using an environment override.
  static CurlFfiClient fromEnvironment({
    int streamChunkSize = 64 * 1024,
    int streamWindowChunks = 4,
  }) {
    final path = Platform.environment['ALPHAX_CURL_LIBRARY'];
    if (path == null || path.isEmpty) {
      throw StateError('Set ALPHAX_CURL_LIBRARY to the libcurl prototype library path');
    }
    return CurlFfiClient.fromPath(
      path,
      streamChunkSize: streamChunkSize,
      streamWindowChunks: streamWindowChunks,
    );
  }

  static void _validateStreamConfig(int chunkSize, int windowChunks) {
    if (chunkSize <= 0 || windowChunks <= 0) {
      throw ArgumentError('stream chunk size and window must be positive');
    }
  }
}

final class _CurlOperation {
  _CurlOperation({
    required this.controller,
    required this.uri,
    required this.requestKind,
    required this.options,
    required List<int> body,
    required this.filePath,
    Stopwatch? stopwatch,
  }) : body = List<int>.unmodifiable(body),
       stopwatch = stopwatch ?? (Stopwatch()..start());

  final StreamController<BenchmarkStreamEvent> controller;
  final Uri uri;
  final int requestKind;
  final BenchmarkRequestOptions options;
  final List<int> body;
  final String? filePath;
  final Stopwatch stopwatch;
  final Completer<void> done = Completer<void>();
  late Stream<BenchmarkStreamEvent> stream;
  Pointer<Void> userData = nullptr;
  Pointer<Void> handle = nullptr;
  Map<String, List<String>> headers = const <String, List<String>>{};
  int statusCode = 0;
  int bytesReceived = 0;
  bool started = false;
  bool cancelled = false;
  bool timedOut = false;
  bool suppressError = false;
  bool completed = false;
  Duration? timeToFirstByte;
  Map<String, Object?> diagnostics = <String, Object?>{};
  final Map<String, Object?> streamDiagnostics = <String, Object?>{};
  int producedChunkCount = 0;
  int producedBytes = 0;
  int consumedChunkCount = 0;
  int consumedBytes = 0;
  int pendingBytes = 0;
  int maxPendingBytes = 0;
  int pendingAckChunks = 0;
  int pendingAckBytes = 0;
  int? nativeCompletionPendingBytes;
  int? nativeCompletionConsumedChunkCount;
  int? nativeCompletionConsumedBytes;
}

/// Result returned by [CurlFfiClient]'s legacy smoke-test ABI.
final class CurlFfiResult {
  /// Creates a result.
  const CurlFfiResult({
    required this.statusCode,
    required this.bytesReceived,
    required this.totalMs,
    required this.curlCode,
    required this.httpVersion,
  });

  /// HTTP status code.
  final int statusCode;

  /// Number of response bytes received.
  final int bytesReceived;

  /// Total elapsed time in milliseconds.
  final double totalMs;

  /// libcurl result code.
  final int curlCode;

  /// libcurl HTTP version code.
  final int httpVersion;
}
