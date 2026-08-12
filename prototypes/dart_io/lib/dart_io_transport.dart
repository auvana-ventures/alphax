import 'dart:async';
import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';

/// Benchmark transport backed by Dart's `dart:io` `HttpClient`.
final class DartIoTransport implements BenchmarkTransport {
  /// Creates a Dart baseline transport.
  DartIoTransport({int? maxConnectionsPerHost}) : _client = HttpClient() {
    final maxConnections = maxConnectionsPerHost;
    if (maxConnections != null) {
      _client.maxConnectionsPerHost = maxConnections;
    }
  }

  final HttpClient _client;

  @override
  String get name => 'dart_io';

  @override
  Future<BenchmarkResponse> getBytes(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) {
    HttpClientRequest? request;
    final operation = _getBytes(uri, options, onRequest: (value) => request = value);
    return _raceWithCancellation(operation, options, () => request?.abort());
  }

  @override
  Stream<BenchmarkStreamEvent> getStreaming(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) {
    final stream = _getStreaming(uri, options);
    final timeout = options.timeout;
    if (timeout == null) {
      return stream;
    }
    return stream.timeout(
      timeout,
      onTimeout: (sink) {
        sink.addError(const BenchmarkTimeoutException());
        sink.close();
      },
    );
  }

  @override
  Future<BenchmarkResponse> postBytes(
    Uri uri,
    List<int> body, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) {
    HttpClientRequest? request;
    final operation = _postBytes(uri, body, options, onRequest: (value) => request = value);
    return _raceWithCancellation(operation, options, () => request?.abort());
  }

  @override
  Future<BenchmarkTransferResult> uploadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) {
    HttpClientRequest? request;
    final operation = _uploadFile(
      uri,
      filePath,
      options,
      onRequest: (value) => request = value,
    );
    return _raceWithCancellation(operation, options, () => request?.abort());
  }

  @override
  Future<BenchmarkTransferResult> downloadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  }) {
    HttpClientRequest? request;
    final operation = _downloadFile(
      uri,
      filePath,
      options,
      onRequest: (value) => request = value,
    );
    return _raceWithCancellation(operation, options, () => request?.abort());
  }

  @override
  Future<void> close() async {
    _client.close(force: true);
  }

  Future<BenchmarkResponse> _getBytes(
    Uri uri,
    BenchmarkRequestOptions options, {
    required void Function(HttpClientRequest request) onRequest,
  }) async {
    _throwIfCancelled(options);
    final stopwatch = Stopwatch()..start();
    final request = await _open('GET', uri, options);
    onRequest(request);
    final response = await request.close();
    final timeToFirstByte = stopwatch.elapsed;
    final body = <int>[];
    await for (final chunk in response) {
      _throwIfCancelled(options);
      body.addAll(chunk);
    }
    stopwatch.stop();
    return BenchmarkResponse(
      statusCode: response.statusCode,
      headers: _headers(response.headers),
      bodyBytes: body,
      elapsed: stopwatch.elapsed,
      timeToFirstByte: timeToFirstByte,
    );
  }

  Stream<BenchmarkStreamEvent> _getStreaming(Uri uri, BenchmarkRequestOptions options) async* {
    _throwIfCancelled(options);
    final stopwatch = Stopwatch()..start();
    HttpClientRequest? request;
    try {
      request = await _open('GET', uri, options);
      final activeRequest = request;
      final cancellation = options.cancellation;
      if (cancellation != null) {
        unawaited(cancellation.whenCancelled.then((_) => activeRequest.abort()));
      }
      final response = await activeRequest.close();
      final headers = _headers(response.headers);
      final timeToFirstByte = stopwatch.elapsed;
      var bytes = 0;
      yield BenchmarkStreamStarted(statusCode: response.statusCode, headers: headers);
      await for (final chunk in response) {
        _throwIfCancelled(options);
        bytes += chunk.length;
        yield BenchmarkStreamChunk(chunk);
      }
      stopwatch.stop();
      yield BenchmarkStreamCompleted(
        statusCode: response.statusCode,
        headers: headers,
        bytesTransferred: bytes,
        elapsed: stopwatch.elapsed,
        timeToFirstByte: timeToFirstByte,
      );
    } finally {
      request?.abort();
    }
  }

  Future<BenchmarkResponse> _postBytes(
    Uri uri,
    List<int> body,
    BenchmarkRequestOptions options, {
    required void Function(HttpClientRequest request) onRequest,
  }) async {
    _throwIfCancelled(options);
    final stopwatch = Stopwatch()..start();
    final request = await _open('POST', uri, options);
    onRequest(request);
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close();
    final timeToFirstByte = stopwatch.elapsed;
    final responseBody = <int>[];
    await for (final chunk in response) {
      _throwIfCancelled(options);
      responseBody.addAll(chunk);
    }
    stopwatch.stop();
    return BenchmarkResponse(
      statusCode: response.statusCode,
      headers: _headers(response.headers),
      bodyBytes: responseBody,
      elapsed: stopwatch.elapsed,
      timeToFirstByte: timeToFirstByte,
    );
  }

  Future<BenchmarkTransferResult> _uploadFile(
    Uri uri,
    String filePath,
    BenchmarkRequestOptions options, {
    required void Function(HttpClientRequest request) onRequest,
  }) async {
    _throwIfCancelled(options);
    final stopwatch = Stopwatch()..start();
    final file = File(filePath);
    final length = await file.length();
    final request = await _open('POST', uri, options);
    onRequest(request);
    request.contentLength = length;
    await request.addStream(file.openRead());
    final response = await request.close();
    final timeToFirstByte = stopwatch.elapsed;
    await response.drain<void>();
    stopwatch.stop();
    return BenchmarkTransferResult(
      statusCode: response.statusCode,
      headers: _headers(response.headers),
      bytesTransferred: length,
      elapsed: stopwatch.elapsed,
      filePath: filePath,
      timeToFirstByte: timeToFirstByte,
    );
  }

  Future<BenchmarkTransferResult> _downloadFile(
    Uri uri,
    String filePath,
    BenchmarkRequestOptions options, {
    required void Function(HttpClientRequest request) onRequest,
  }) async {
    _throwIfCancelled(options);
    final stopwatch = Stopwatch()..start();
    final request = await _open('GET', uri, options);
    onRequest(request);
    final response = await request.close();
    final timeToFirstByte = stopwatch.elapsed;
    final sink = File(filePath).openWrite();
    var bytes = 0;
    try {
      await for (final chunk in response) {
        _throwIfCancelled(options);
        sink.add(chunk);
        bytes += chunk.length;
      }
    } finally {
      await sink.close();
    }
    stopwatch.stop();
    return BenchmarkTransferResult(
      statusCode: response.statusCode,
      headers: _headers(response.headers),
      bytesTransferred: bytes,
      elapsed: stopwatch.elapsed,
      filePath: filePath,
      timeToFirstByte: timeToFirstByte,
    );
  }

  Future<HttpClientRequest> _open(
    String method,
    Uri uri,
    BenchmarkRequestOptions options,
  ) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = options.followRedirects;
    request.maxRedirects = 10;
    return request;
  }

  Future<T> _raceWithCancellation<T>(
    Future<T> operation,
    BenchmarkRequestOptions options,
    void Function() cancel,
  ) {
    final timeout = options.timeout;
    final timed = timeout == null
        ? operation
        : operation.timeout(
            timeout,
            onTimeout: () {
              cancel();
              throw const BenchmarkTimeoutException();
            },
          );
    final token = options.cancellation;
    if (token == null) {
      return timed;
    }
    final cancellation = token.whenCancelled.then<T>((_) {
      cancel();
      throw const BenchmarkCancelledException();
    });
    return Future.any<T>(<Future<T>>[timed, cancellation]);
  }

  static void _throwIfCancelled(BenchmarkRequestOptions options) {
    if (options.cancellation?.isCancelled ?? false) {
      throw const BenchmarkCancelledException();
    }
  }

  static Map<String, List<String>> _headers(HttpHeaders headers) {
    final values = <String, List<String>>{};
    headers.forEach((name, headerValues) {
      values[name] = headerValues.toList(growable: false);
    });
    return values;
  }
}
