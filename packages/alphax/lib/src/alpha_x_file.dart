import 'dart:async';

import 'alpha_x_headers.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';

/// Replayable or single-use source of file bytes.
///
/// Implementations may be backed by a path, a platform file API, or another
/// source. The interface intentionally exposes no file descriptor or native
/// handle.
abstract interface class AlphaXFileSource {
  /// Optional display name of the source.
  String? get name;

  /// Source length, when known without reading it.
  int? get length;

  /// Whether [openRead] can be called again.
  bool get isReplayable;

  /// Opens the source for incremental reading.
  Stream<List<int>> openRead();
}

/// Destination for a native or Dart-managed file download.
abstract interface class AlphaXFileTarget {
  /// Optional display name of the destination.
  String? get name;

  /// Opens a destination sink. The transport closes or aborts the sink.
  Future<AlphaXFileSink> openWrite();
}

/// Incremental destination used by [AlphaXFileTarget].
abstract interface class AlphaXFileSink {
  /// Adds a byte chunk to the destination.
  void add(List<int> bytes);

  /// Flushes bytes that have been accepted by the sink.
  Future<void> flush();

  /// Completes the destination.
  Future<void> close();

  /// Aborts and releases the destination after a failed transfer.
  Future<void> abort();
}

/// Result metadata for a file-backed upload or download.
final class AlphaXTransferResult {
  /// Creates a transfer result without exposing the response body.
  AlphaXTransferResult({
    required this.statusCode,
    this.headers = const AlphaXHeaders.empty(),
    this.protocol = AlphaXProtocol.unknown,
    this.requestedProtocol,
    this.protocolFallback,
    this.metrics = const AlphaXRequestMetrics(),
    Iterable<AlphaXRedirectInfo> redirects = const <AlphaXRedirectInfo>[],
    required this.bytesTransferred,
    this.totalBytes,
  }) : redirects = List<AlphaXRedirectInfo>.unmodifiable(redirects);

  /// HTTP response status.
  final int statusCode;

  /// Response headers.
  final AlphaXHeaders headers;

  /// Protocol actually negotiated.
  final AlphaXProtocol protocol;

  /// Protocol preference supplied by the caller, when retained.
  final AlphaXProtocolPreference? requestedProtocol;

  /// Explicit fallback information, when applicable.
  final AlphaXProtocolFallback? protocolFallback;

  /// Transport-neutral transfer metrics.
  final AlphaXRequestMetrics metrics;

  /// Redirect hops observed during the transfer.
  final List<AlphaXRedirectInfo> redirects;

  /// Number of bytes transferred.
  final int bytesTransferred;

  /// Expected total bytes, when known.
  final int? totalBytes;

  /// Whether the response status is in the successful 2xx range.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}
