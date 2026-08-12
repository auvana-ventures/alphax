import 'dart:async';

/// A caller-controlled cancellation token for a benchmark operation.
final class BenchmarkCancellationToken {
  /// Creates an active token.
  BenchmarkCancellationToken();

  bool _cancelled = false;
  Completer<void>? _completer;

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled;

  /// Completes when cancellation is requested.
  Future<void> get whenCancelled {
    if (_cancelled) {
      return Future<void>.value();
    }
    return (_completer ??= Completer<void>()).future;
  }

  /// Requests cancellation. Repeated calls have no effect.
  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _completer?.complete();
  }
}

/// Raised when a benchmark operation is cancelled.
final class BenchmarkCancelledException implements Exception {
  /// Creates a cancellation error.
  const BenchmarkCancelledException();

  @override
  String toString() => 'BenchmarkCancelledException';
}

/// Raised when a benchmark operation exceeds its configured timeout.
final class BenchmarkTimeoutException implements Exception {
  /// Creates a timeout error.
  const BenchmarkTimeoutException();

  @override
  String toString() => 'BenchmarkTimeoutException';
}

/// Options shared by all benchmark transport implementations.
final class BenchmarkRequestOptions {
  /// Creates shared request options.
  const BenchmarkRequestOptions({
    this.timeout,
    this.cancellation,
    this.followRedirects = true,
  });

  /// Optional whole-operation timeout.
  final Duration? timeout;

  /// Optional cancellation token.
  final BenchmarkCancellationToken? cancellation;

  /// Whether the candidate should follow redirects.
  final bool followRedirects;
}

/// Immutable response metadata and bytes returned by a benchmark transport.
final class BenchmarkResponse {
  /// Creates a benchmark response and copies its bytes and headers.
  BenchmarkResponse({
    required this.statusCode,
    required Map<String, Iterable<String>> headers,
    required List<int> bodyBytes,
    required this.elapsed,
    this.timeToFirstByte,
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) : headers = freezeBenchmarkHeaders(headers),
       bodyBytes = List<int>.unmodifiable(bodyBytes),
       diagnostics = Map<String, Object?>.unmodifiable(diagnostics);

  /// HTTP status code.
  final int statusCode;

  /// Lowercase, case-insensitive response headers.
  final Map<String, List<String>> headers;

  /// Complete response bytes.
  final List<int> bodyBytes;

  /// Total elapsed operation time.
  final Duration elapsed;

  /// Time to first response byte, when measured.
  final Duration? timeToFirstByte;

  /// Candidate-specific measurement diagnostics, when available.
  final Map<String, Object?> diagnostics;

  /// Returns all values for [name], ignoring case.
  List<String> headerValues(String name) => headers[_normalizeHeaderName(name)] ?? const <String>[];

  /// Returns the first value for [name], ignoring case.
  String? header(String name) {
    final values = headerValues(name);
    return values.isEmpty ? null : values.first;
  }
}

/// Immutable result for an upload or download operation.
final class BenchmarkTransferResult {
  /// Creates a file-transfer result.
  BenchmarkTransferResult({
    required this.statusCode,
    required Map<String, Iterable<String>> headers,
    required this.bytesTransferred,
    required this.elapsed,
    required this.filePath,
    this.timeToFirstByte,
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) : headers = freezeBenchmarkHeaders(headers),
       diagnostics = Map<String, Object?>.unmodifiable(diagnostics);

  /// HTTP status code.
  final int statusCode;

  /// Lowercase response headers.
  final Map<String, List<String>> headers;

  /// Number of bytes sent or written.
  final int bytesTransferred;

  /// Total elapsed operation time.
  final Duration elapsed;

  /// Path used for the upload or download.
  final String filePath;

  /// Time to first response byte, when measured.
  final Duration? timeToFirstByte;

  /// Candidate-specific measurement diagnostics, when available.
  final Map<String, Object?> diagnostics;
}

/// Base type for streaming benchmark events.
sealed class BenchmarkStreamEvent {
  /// Creates a streaming event.
  const BenchmarkStreamEvent();
}

/// Response metadata emitted before the first stream chunk.
final class BenchmarkStreamStarted extends BenchmarkStreamEvent {
  /// Creates a stream-start event.
  const BenchmarkStreamStarted({
    required this.statusCode,
    required this.headers,
    this.diagnostics = const <String, Object?>{},
  });

  /// HTTP status code.
  final int statusCode;

  /// Lowercase response headers.
  final Map<String, List<String>> headers;

  /// Candidate-specific measurement diagnostics, when available.
  final Map<String, Object?> diagnostics;
}

/// One owned response chunk.
final class BenchmarkStreamChunk extends BenchmarkStreamEvent {
  /// Creates a stream chunk and copies [bytes].
  BenchmarkStreamChunk(List<int> bytes) : bytes = List<int>.unmodifiable(bytes);

  /// Chunk bytes.
  final List<int> bytes;
}

/// Terminal metadata emitted after all stream chunks.
final class BenchmarkStreamCompleted extends BenchmarkStreamEvent {
  /// Creates a stream-completed event.
  const BenchmarkStreamCompleted({
    required this.statusCode,
    required this.headers,
    required this.bytesTransferred,
    required this.elapsed,
    this.timeToFirstByte,
    this.diagnostics = const <String, Object?>{},
  });

  /// HTTP status code.
  final int statusCode;

  /// Lowercase response headers.
  final Map<String, List<String>> headers;

  /// Number of bytes emitted through the stream.
  final int bytesTransferred;

  /// Total elapsed operation time.
  final Duration elapsed;

  /// Time to first response byte, when measured.
  final Duration? timeToFirstByte;

  /// Candidate-specific measurement diagnostics, when available.
  final Map<String, Object?> diagnostics;
}

/// Benchmark-only transport abstraction shared by all candidate adapters.
abstract interface class BenchmarkTransport {
  /// Candidate name used in result metadata.
  String get name;

  /// Performs a buffered GET request.
  Future<BenchmarkResponse> getBytes(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  });

  /// Performs a streaming GET request.
  Stream<BenchmarkStreamEvent> getStreaming(
    Uri uri, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  });

  /// Performs a byte POST request.
  Future<BenchmarkResponse> postBytes(
    Uri uri,
    List<int> body, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  });

  /// Uploads a file and returns transfer metadata.
  Future<BenchmarkTransferResult> uploadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  });

  /// Downloads a response directly to [filePath] where supported.
  Future<BenchmarkTransferResult> downloadFile(
    Uri uri,
    String filePath, {
    BenchmarkRequestOptions options = const BenchmarkRequestOptions(),
  });

  /// Releases candidate resources.
  Future<void> close();
}

/// Freezes headers with lowercase names and immutable value lists.
Map<String, List<String>> freezeBenchmarkHeaders(Map<String, Iterable<String>> headers) {
  final normalized = <String, List<String>>{};
  for (final entry in headers.entries) {
    final name = _normalizeHeaderName(entry.key);
    normalized.putIfAbsent(name, () => <String>[]).addAll(entry.value);
  }
  return Map<String, List<String>>.unmodifiable({
    for (final entry in normalized.entries) entry.key: List<String>.unmodifiable(entry.value),
  });
}

String _normalizeHeaderName(String name) => name.trim().toLowerCase();
