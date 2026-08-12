import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:dio/dio.dart';

/// Dio's normal/default Dart IO adapter used as an ecosystem reference.
///
/// This is not an AlphaX candidate and is included only when the benchmark
/// runner is invoked with `--include-references`.
final class DioReferenceTransport implements BenchmarkTransport {
  DioReferenceTransport() : _dio = Dio();

  final Dio _dio;

  @override
  String get name => 'dio_reference';

  @override
  Future<BenchmarkResponse> getBytes(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final cancelToken = CancelToken();
    _wireCancellation(cancelToken, options);
    final stopwatch = Stopwatch()..start();
    final response = await _await(
      _dio.get<List<int>>(
        uri.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: options.followRedirects,
        ),
      ),
      options,
      cancelToken,
    );
    stopwatch.stop();
    final body = List<int>.from(response.data ?? const <int>[]);
    return BenchmarkResponse(
      statusCode: response.statusCode ?? 0,
      headers: _headers(response.headers),
      bodyBytes: body,
      elapsed: stopwatch.elapsed,
      timeToFirstByte: null,
      diagnostics: <String, Object?>{
        'dio_version': '5.11.0',
        'transport_reference': 'Dio default adapter',
      },
    );
  }

  @override
  Stream<BenchmarkStreamEvent> getStreaming(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async* {
    final cancelToken = CancelToken();
    _wireCancellation(cancelToken, options);
    final stopwatch = Stopwatch()..start();
    final response = await _await(
      _dio.get<ResponseBody>(
        uri.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: options.followRedirects,
        ),
      ),
      options,
      cancelToken,
    );
    final body = response.data;
    if (body == null) {
      throw StateError('Dio returned no streaming response body');
    }
    final headers = _headers(response.headers);
    final timeToFirstByte = stopwatch.elapsed;
    var bytes = 0;
    var chunks = 0;
    yield BenchmarkStreamStarted(
      statusCode: response.statusCode ?? 0,
      headers: headers,
      diagnostics: const <String, Object?>{
        'transport_reference': 'Dio default adapter',
      },
    );
    try {
      await for (final chunk in body.stream) {
        _throwIfCancelled(options);
        final owned = List<int>.from(chunk);
        bytes += owned.length;
        chunks++;
        yield BenchmarkStreamChunk(owned);
      }
    } on DioException catch (error) {
      _rethrow(error, options);
    } finally {
      cancelToken.cancel('stream closed');
    }
    stopwatch.stop();
    yield BenchmarkStreamCompleted(
      statusCode: response.statusCode ?? 0,
      headers: headers,
      bytesTransferred: bytes,
      elapsed: stopwatch.elapsed,
      timeToFirstByte: timeToFirstByte,
      diagnostics: <String, Object?>{
        'transport_reference': 'Dio default adapter',
        'stream_metrics': <String, Object?>{
          'producer_chunk_count': chunks,
          'producer_bytes': bytes,
          'consumer_chunk_count': chunks,
          'consumer_bytes': bytes,
          'queue_policy': 'Dio default adapter response stream',
          'pause_supported': true,
          'native_measurements': 'unavailable',
        },
      },
    );
  }

  @override
  Future<BenchmarkResponse> postBytes(
    Uri uri,
    List<int> body, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final cancelToken = CancelToken();
    _wireCancellation(cancelToken, options);
    final stopwatch = Stopwatch()..start();
    final response = await _await(
      _dio.post<List<int>>(
        uri.toString(),
        data: Uint8List.fromList(body),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: options.followRedirects,
          headers: <String, Object>{
            Headers.contentTypeHeader: 'application/octet-stream',
            Headers.contentLengthHeader: body.length,
          },
        ),
      ),
      options,
      cancelToken,
    );
    stopwatch.stop();
    return BenchmarkResponse(
      statusCode: response.statusCode ?? 0,
      headers: _headers(response.headers),
      bodyBytes: List<int>.from(response.data ?? const <int>[]),
      elapsed: stopwatch.elapsed,
      timeToFirstByte: null,
      diagnostics: const <String, Object?>{
        'transport_reference': 'Dio default adapter',
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
    final file = File(filePath);
    final preparation = Stopwatch()..start();
    final length = await file.length();
    preparation.stop();
    final cancelToken = CancelToken();
    _wireCancellation(cancelToken, options);
    final response = await _await(
      _dio.post<List<int>>(
        uri.toString(),
        data: file.openRead(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: options.followRedirects,
          headers: <String, Object>{
            Headers.contentLengthHeader: length,
            Headers.contentTypeHeader: 'application/octet-stream',
          },
        ),
      ),
      options,
      cancelToken,
    );
    stopwatch.stop();
    return BenchmarkTransferResult(
      statusCode: response.statusCode ?? 0,
      headers: _headers(response.headers),
      bytesTransferred: length,
      elapsed: stopwatch.elapsed,
      filePath: filePath,
      timeToFirstByte: null,
      diagnostics: <String, Object?>{
        'transport_reference': 'Dio default adapter',
        'dart_file_preparation_us': preparation.elapsed.inMicroseconds,
      },
    );
  }

  @override
  Future<BenchmarkTransferResult> downloadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) async {
    final cancelToken = CancelToken();
    _wireCancellation(cancelToken, options);
    final stopwatch = Stopwatch()..start();
    final response = await _await(
      _dio.downloadUri(
        uri,
        filePath,
        cancelToken: cancelToken,
        options: Options(followRedirects: options.followRedirects),
      ),
      options,
      cancelToken,
    );
    stopwatch.stop();
    return BenchmarkTransferResult(
      statusCode: response.statusCode ?? 0,
      headers: _headers(response.headers),
      bytesTransferred: await File(filePath).length(),
      elapsed: stopwatch.elapsed,
      filePath: filePath,
      diagnostics: const <String, Object?>{
        'transport_reference': 'Dio default adapter',
      },
    );
  }

  @override
  Future<void> close() async {
    _dio.close(force: true);
  }

  void _wireCancellation(CancelToken token, BenchmarkRequestOptions options) {
    final cancellation = options.cancellation;
    if (cancellation != null) {
      unawaited(cancellation.whenCancelled.then((_) => token.cancel('cancelled')));
    }
  }

  Future<T> _await<T>(
    Future<T> operation,
    BenchmarkRequestOptions options,
    CancelToken token,
  ) async {
    var timeout = false;
    final races = <Future<T>>[operation];
    final cancellation = options.cancellation;
    if (cancellation != null) {
      races.add(
        cancellation.whenCancelled.then<T>((_) {
          token.cancel('cancelled');
          throw const BenchmarkCancelledException();
        }),
      );
    }
    if (options.timeout != null) {
      races.add(
        Future<T>.delayed(options.timeout!, () {
          timeout = true;
          token.cancel('timeout');
          throw const BenchmarkTimeoutException();
        }),
      );
    }
    try {
      return await Future.any<T>(races);
    } on DioException catch (error) {
      _rethrow(error, options, timedOut: timeout);
    }
    throw StateError('Dio operation ended without a result');
  }

  static void _rethrow(
    DioException error,
    BenchmarkRequestOptions options, {
    bool timedOut = false,
  }) {
    if (timedOut || options.timeout != null && error.type == DioExceptionType.receiveTimeout) {
      throw const BenchmarkTimeoutException();
    }
    if (options.cancellation?.isCancelled ?? false) {
      throw const BenchmarkCancelledException();
    }
    throw error;
  }

  static void _throwIfCancelled(BenchmarkRequestOptions options) {
    if (options.cancellation?.isCancelled ?? false) {
      throw const BenchmarkCancelledException();
    }
  }

  static Map<String, List<String>> _headers(Headers headers) => <String, List<String>>{
    for (final entry in headers.map.entries) entry.key: List<String>.of(entry.value),
  };
}
