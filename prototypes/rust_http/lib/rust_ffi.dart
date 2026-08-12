import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:ffi/ffi.dart';

/// Native Rust result layout.
final class NativeAxRustResult extends Struct {
  /// HTTP status code.
  @Int64()
  external int statusCode;

  /// Number of response bytes.
  @Uint64()
  external int bytesReceived;

  /// Total elapsed milliseconds.
  @Double()
  external double totalMs;

  /// Time to first byte in milliseconds.
  @Double()
  external double timeToFirstByteMs;

  /// Prototype error code.
  @Int32()
  external int errorCode;
}

typedef _RustGetNative = Int32 Function(Pointer<Utf8>, Pointer<NativeAxRustResult>);
typedef _RustGetDart = int Function(Pointer<Utf8>, Pointer<NativeAxRustResult>);
typedef _VersionNative = Uint32 Function();
typedef _VersionDart = int Function();

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
      Pointer<NativeAxRustResult>,
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
typedef _FreeBufferNative = Void Function(Pointer<Uint8>, Uint64);
typedef _FreeBufferDart = void Function(Pointer<Uint8>, int);
typedef _FreeResultNative = Void Function(Pointer<NativeAxRustResult>);
typedef _FreeResultDart = void Function(Pointer<NativeAxRustResult>);

/// Dart wrapper around the Rust prototype C ABI.
final class RustFfiClient implements BenchmarkTransport {
  /// Loads the library from [path].
  RustFfiClient.fromPath(String path) : _library = DynamicLibrary.open(path) {
    _get = _library.lookupFunction<_RustGetNative, _RustGetDart>('ax_rust_get');
    _version = _library.lookupFunction<_VersionNative, _VersionDart>('ax_rust_ffi_version');
    _requestStart = _library.lookupFunction<_RequestStartNative, _RequestStartDart>(
      'ax_rust_request_start',
    );
    _requestCancel = _library.lookupFunction<_RequestCancelNative, _RequestCancelDart>(
      'ax_rust_request_cancel',
    );
    _requestFree = _library.lookupFunction<_RequestFreeNative, _RequestFreeDart>(
      'ax_rust_request_free',
    );
    _freeBuffer = _library.lookupFunction<_FreeBufferNative, _FreeBufferDart>(
      'ax_rust_free_buffer',
    );
    _freeResult = _library.lookupFunction<_FreeResultNative, _FreeResultDart>(
      'ax_rust_free_result',
    );
    _startCallback = NativeCallable<_StreamStartNative>.listener(_handleStart);
    _chunkCallback = NativeCallable<_StreamChunkNative>.listener(_handleChunk);
    _completeCallback = NativeCallable<_StreamCompleteNative>.listener(_handleComplete);
  }

  final DynamicLibrary _library;
  late final _RustGetDart _get;
  late final _VersionDart _version;
  late final _RequestStartDart _requestStart;
  late final _RequestCancelDart _requestCancel;
  late final _RequestFreeDart _requestFree;
  late final _FreeBufferDart _freeBuffer;
  late final _FreeResultDart _freeResult;
  late final NativeCallable<_StreamStartNative> _startCallback;
  late final NativeCallable<_StreamChunkNative> _chunkCallback;
  late final NativeCallable<_StreamCompleteNative> _completeCallback;
  final Map<int, _RustOperation> _operations = <int, _RustOperation>{};
  bool _closed = false;

  @override
  String get name => 'rust_reqwest_ffi';

  /// ABI version exported by the native library.
  int get abiVersion => _version();

  /// Performs one blocking GET through the legacy Rust C ABI.
  RustFfiResult get(Uri url) {
    return using((arena) {
      final urlPointer = url.toString().toNativeUtf8(allocator: arena);
      final resultPointer = arena<NativeAxRustResult>();
      final code = _get(urlPointer, resultPointer);
      if (code != 0) {
        throw StateError('Rust prototype request failed with code $code');
      }
      final result = resultPointer.ref;
      return RustFfiResult(
        statusCode: result.statusCode,
        bytesReceived: result.bytesReceived,
        totalMs: result.totalMs,
        timeToFirstByteMs: result.timeToFirstByteMs,
        errorCode: result.errorCode,
      );
    });
  }

  @override
  Future<BenchmarkResponse> getBytes(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final operation = _createOperation(uri: uri, requestKind: _getRequest, options: options);
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
      throw StateError('Rust request completed without a terminal event');
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
  }) => _createOperation(uri: uri, requestKind: _getRequest, options: options).stream;

  @override
  Future<BenchmarkResponse> postBytes(
    Uri uri,
    List<int> body, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final operation = _createOperation(
      uri: uri,
      requestKind: _postBytesRequest,
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
      throw StateError('Rust POST completed without a terminal event');
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
    final completed = await _consumeTransfer(
      _createOperation(
        uri: uri,
        requestKind: _uploadFileRequest,
        filePath: filePath,
        options: options,
      ),
    );
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
    final completed = await _consumeTransfer(
      _createOperation(
        uri: uri,
        requestKind: _downloadFileRequest,
        filePath: filePath,
        options: options,
      ),
    );
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
    final operations = List<_RustOperation>.of(_operations.values);
    for (final operation in operations) {
      _cancel(operation);
    }
    await Future.wait<void>(operations.map((operation) => operation.done.future));
    _startCallback.close();
    _chunkCallback.close();
    _completeCallback.close();
  }

  static const int _getRequest = 0;
  static const int _postBytesRequest = 1;
  static const int _uploadFileRequest = 2;
  static const int _downloadFileRequest = 3;

  Future<BenchmarkStreamCompleted> _consumeTransfer(_RustOperation operation) async {
    BenchmarkStreamCompleted? completed;
    await for (final event in operation.stream) {
      if (event case BenchmarkStreamCompleted event) {
        completed = event;
      }
    }
    final result = completed;
    if (result == null) {
      throw StateError('Rust transfer completed without a terminal event');
    }
    return result;
  }

  _RustOperation _createOperation({
    required Uri uri,
    required int requestKind,
    required BenchmarkRequestOptions options,
    List<int> body = const <int>[],
    String? filePath,
  }) {
    if (_closed) {
      throw StateError('Rust transport is closed');
    }
    final controller = StreamController<BenchmarkStreamEvent>();
    final operation = _RustOperation(
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
      operation.stream = controller.stream.timeout(
        options.timeout!,
        onTimeout: (sink) {
          operation.timedOut = true;
          operation.suppressError = true;
          _cancel(operation);
          sink.addError(const BenchmarkTimeoutException());
          sink.close();
        },
      );
    } else {
      operation.stream = controller.stream;
    }
    return operation;
  }

  void _start(_RustOperation operation) {
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
      _finishWithoutNative(operation, StateError('unable to start Rust request'));
      return;
    }
    operation.handle = handle;
    if (operation.cancelled) {
      _requestCancel(handle);
    }
  }

  void _cancel(_RustOperation operation) {
    operation.cancelled = true;
    if (operation.handle != nullptr) {
      _requestCancel(operation.handle);
    }
  }

  void _finishWithoutNative(_RustOperation operation, Object error) {
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
        _freeBuffer(pointer, length);
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
        _freeBuffer(pointer, length);
      }
    }
  }

  void _handleComplete(Pointer<NativeAxRustResult> pointer, int errorCode, Pointer<Void> userData) {
    final operation = _operations[userData.address];
    if (operation == null || operation.completed) {
      _freeResult(pointer);
      return;
    }
    final nativeResult = pointer.ref;
    final nativeHandle = operation.handle;
    operation.completed = true;
    operation.statusCode = operation.statusCode == 0
        ? nativeResult.statusCode
        : operation.statusCode;
    final error = errorCode == 0
        ? null
        : operation.timedOut
        ? const BenchmarkTimeoutException()
        : operation.cancelled
        ? const BenchmarkCancelledException()
        : StateError('Rust request failed with code $errorCode');
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
    _freeResult(pointer);
    _operations.remove(userData.address);
    calloc.free(userData);
    operation.userData = nullptr;
    operation.handle = nullptr;
    if (!operation.done.isCompleted) {
      operation.done.complete();
    }
    if (nativeHandle != nullptr) {
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
  static RustFfiClient fromEnvironment() {
    final path = Platform.environment['ALPHAX_RUST_LIBRARY'];
    if (path == null || path.isEmpty) {
      throw StateError('Set ALPHAX_RUST_LIBRARY to the Rust prototype library path');
    }
    return RustFfiClient.fromPath(path);
  }
}

final class _RustOperation {
  _RustOperation({
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

/// Result returned by [RustFfiClient]'s legacy smoke-test ABI.
final class RustFfiResult {
  /// Creates a result.
  const RustFfiResult({
    required this.statusCode,
    required this.bytesReceived,
    required this.totalMs,
    required this.timeToFirstByteMs,
    required this.errorCode,
  });

  /// HTTP status code.
  final int statusCode;

  /// Number of response bytes received.
  final int bytesReceived;

  /// Total elapsed time in milliseconds.
  final double totalMs;

  /// Time to first byte in milliseconds.
  final double timeToFirstByteMs;

  /// Native error code.
  final int errorCode;
}
