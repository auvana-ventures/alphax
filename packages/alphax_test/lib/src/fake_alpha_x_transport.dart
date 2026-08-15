import 'dart:async';

import 'package:alphax/alphax.dart';

/// Builds a fake response for a request.
typedef AlphaXResponseBuilder = FutureOr<AlphaXResponse> Function(AlphaXRequest request);

/// Builds a fake streaming event sequence for a request.
typedef AlphaXStreamBuilder = Stream<AlphaXEvent> Function(AlphaXRequest request);

/// Deterministic in-memory transport for ordinary application and contract tests.
final class FakeAlphaXTransport extends AlphaXTransport {
  /// Creates a fake transport with optional response, stream, delay, and failure behavior.
  FakeAlphaXTransport({
    AlphaXResponse? response,
    this.responseBuilder,
    this.streamBuilder,
    this.error,
    this.errorStackTrace,
    this.delay,
    AlphaXCapabilities? capabilities,
  }) : response = response ?? AlphaXResponse(statusCode: 200),
       _capabilities =
           capabilities ??
           const AlphaXCapabilities(
             http11: AlphaXSupport.supported,
             streamingUpload: AlphaXSupport.supported,
             streamingDownload: AlphaXSupport.supported,
           );

  /// Default response returned by [send].
  AlphaXResponse response;

  /// Optional response factory overriding [response].
  final AlphaXResponseBuilder? responseBuilder;

  /// Optional event factory overriding the default response event sequence.
  final AlphaXStreamBuilder? streamBuilder;

  /// Optional error thrown by operations.
  final Object? error;

  /// Optional stack trace paired with [error].
  final StackTrace? errorStackTrace;

  /// Optional deterministic delay before an operation produces output.
  final Duration? delay;

  final AlphaXCapabilities _capabilities;
  final List<AlphaXRequest> _requests = <AlphaXRequest>[];
  bool _closed = false;

  /// Requests received in order.
  List<AlphaXRequest> get requests => List<AlphaXRequest>.unmodifiable(_requests);

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  @override
  AlphaXCapabilities get capabilities => _capabilities;

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    _record(request);
    await _wait(request.cancellationToken);
    _throwConfiguredError();
    return await (responseBuilder?.call(request) ?? response);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    _record(request);
    await _wait(request.cancellationToken);
    _throwConfiguredError();
    final builder = streamBuilder;
    if (builder != null) {
      yield* builder(request);
      return;
    }

    yield AlphaXResponseStarted(
      statusCode: response.statusCode,
      headers: response.headers,
      protocol: response.protocol,
      requestedProtocol: response.requestedProtocol,
      protocolFallback: response.protocolFallback,
      redirects: response.redirects,
    );
    final bytes = response.bufferedBodyBytes;
    if (bytes != null && bytes.isNotEmpty) {
      yield AlphaXResponseChunk(bytes);
    } else if (bytes == null) {
      yield* response.stream.map(AlphaXResponseChunk.new);
    }
    yield AlphaXResponseCompleted(
      metrics: response.metrics,
      bytesReceived: bytes?.length ?? response.metrics.downloadedBytes ?? 0,
      requestedProtocol: response.requestedProtocol,
      protocolFallback: response.protocolFallback,
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  void _record(AlphaXRequest request) {
    if (_closed) {
      throw const AlphaXClientClosedException('FakeAlphaXTransport is closed');
    }
    _requests.add(request);
  }

  Future<void> _wait(AlphaXCancellationToken? token) async {
    token?.throwIfCancelled();
    final wait = delay;
    if (wait == null) {
      token?.throwIfCancelled();
      return;
    }
    if (token == null) {
      await Future<void>.delayed(wait);
    } else {
      await Future.any<void>(<Future<void>>[
        Future<void>.delayed(wait),
        token.whenCancelled,
      ]);
      token.throwIfCancelled();
    }
  }

  void _throwConfiguredError() {
    final configured = error;
    if (configured != null) {
      Error.throwWithStackTrace(configured, errorStackTrace ?? StackTrace.current);
    }
  }
}
