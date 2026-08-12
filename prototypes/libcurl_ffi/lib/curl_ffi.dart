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
typedef _RequestFreeNative = Void Function(Pointer<Void>);
typedef _RequestFreeDart = void Function(Pointer<Void>);
typedef _FreeBufferNative = Void Function(Pointer<Uint8>);
typedef _FreeBufferDart = void Function(Pointer<Uint8>);

/// Dart wrapper around the libcurl prototype C ABI.
final class CurlFfiClient implements BenchmarkTransport {
  /// Loads the shared library at [path].
  CurlFfiClient.fromPath(String path) : _library = DynamicLibrary.open(path) {
    _get = _library.lookupFunction<_GetNative, _GetDart>('ax_curl_get');
    _version = _library.lookupFunction<_VersionNative, _VersionDart>('ax_curl_version');
    _requestStart = _library.lookupFunction<_RequestStartNative, _RequestStartDart>(
      'ax_curl_request_start',
    );
    _requestCancel = _library.lookupFunction<_RequestCancelNative, _RequestCancelDart>(
      'ax_curl_request_cancel',
    );
    _requestFree = _library.lookupFunction<_RequestFreeNative, _RequestFreeDart>(
      'ax_curl_request_free',
    );
    _freeBuffer = _library.lookupFunction<_FreeBufferNative, _FreeBufferDart>(
      'ax_curl_free_buffer',
    );
    _startCallback = NativeCallable<_StreamStartNative>.listener(_handleStart);
    _chunkCallback = NativeCallable<_StreamChunkNative>.listener(_handleChunk);
    _completeCallback = NativeCallable<_StreamCompleteNative>.listener(_handleComplete);
  }

  final DynamicLibrary _library;
  late final _GetDart _get;
  late final _VersionDart _version;
  late final _RequestStartDart _requestStart;
  late final _RequestCancelDart _requestCancel;
  late final _RequestFreeDart _requestFree;
  late final _FreeBufferDart _freeBuffer;
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
      elapsed: result.elapsed,
      timeToFirstByte: result.timeToFirstByte,
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
      elapsed: result.elapsed,
      timeToFirstByte: result.timeToFirstByte,
    );
  }

  @override
  Future<BenchmarkTransferResult> uploadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final bytesToTransfer = await File(filePath).length();
    final operation = _createOperation(
      uri: uri,
      requestKind: _requestUploadFile,
      filePath: filePath,
      options: options,
    );
    final completed = await _consumeTransfer(operation);
    return BenchmarkTransferResult(
      statusCode: completed.statusCode,
      headers: completed.headers,
      bytesTransferred: bytesToTransfer,
      elapsed: completed.elapsed,
      filePath: filePath,
      timeToFirstByte: completed.timeToFirstByte,
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
    return BenchmarkTransferResult(
      statusCode: completed.statusCode,
      headers: completed.headers,
      bytesTransferred: completed.bytesTransferred,
      elapsed: completed.elapsed,
      filePath: filePath,
      timeToFirstByte: completed.timeToFirstByte,
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
    if (options.timeout != null) {
      final timedStream = controller.stream.timeout(
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
      operation.stream = controller.stream;
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
    operation.handle = handle;
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
        operation.controller.add(BenchmarkStreamStarted(statusCode: statusCode, headers: headers));
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
    operation.completed = true;
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
          ),
        );
      }
    }
    if (!operation.controller.isClosed) {
      unawaited(operation.controller.close());
    }
    final nativeHandle = operation.handle;
    _operations.remove(userData.address);
    calloc.free(userData);
    operation.userData = nullptr;
    operation.handle = nullptr;
    if (!operation.done.isCompleted) {
      operation.done.complete();
    }
    if (nativeHandle != nullptr) {
      // The completion callback runs on the native worker thread. Defer the
      // join/free until the callback has returned to avoid joining ourselves.
      scheduleMicrotask(() => _requestFree(nativeHandle));
    }
  }

  static List<int> _copyNativeBuffer(Pointer<Uint8> pointer, int length) {
    if (pointer == nullptr || length == 0) {
      return const <int>[];
    }
    return List<int>.from(pointer.asTypedList(length));
  }

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
  static CurlFfiClient fromEnvironment() {
    final path = Platform.environment['ALPHAX_CURL_LIBRARY'];
    if (path == null || path.isEmpty) {
      throw StateError('Set ALPHAX_CURL_LIBRARY to the libcurl prototype library path');
    }
    return CurlFfiClient.fromPath(path);
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
  }) : body = List<int>.unmodifiable(body),
       stopwatch = Stopwatch()..start();

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
