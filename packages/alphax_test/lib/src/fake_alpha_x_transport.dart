import 'package:alphax/alphax.dart';

/// Builds a fake response for a request.
typedef AlphaXResponseBuilder = AlphaXResponse Function(AlphaXRequest request);

/// Builds a fake streaming event sequence for a request.
typedef AlphaXStreamBuilder = Stream<AlphaXEvent> Function(AlphaXRequest request);

/// Deterministic transport for ordinary application and contract tests.
final class FakeAlphaXTransport implements AlphaXTransport {
  /// Creates a fake transport with optional response, stream, and error behavior.
  FakeAlphaXTransport({
    AlphaXResponse? response,
    this.responseBuilder,
    this.streamBuilder,
    this.error,
    this.delay,
  }) : response = response ?? AlphaXResponse(statusCode: 200, bodyBytes: const <int>[]);

  /// Default response returned by [send].
  AlphaXResponse response;

  /// Optional response factory overriding [response].
  final AlphaXResponseBuilder? responseBuilder;

  /// Optional stream factory used by [sendStreaming].
  final AlphaXStreamBuilder? streamBuilder;

  /// Optional error thrown by both operations.
  final Object? error;

  /// Optional deterministic delay before completing an operation.
  final Duration? delay;

  /// Requests received by this transport in order.
  final List<AlphaXRequest> requests = <AlphaXRequest>[];

  /// Whether [close] has been called.
  bool isClosed = false;

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    _record(request);
    await _wait();
    if (error != null) {
      throw error!;
    }
    return responseBuilder?.call(request) ?? response;
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    _record(request);
    await _wait();
    if (error != null) {
      throw error!;
    }
    final builder = streamBuilder;
    if (builder != null) {
      yield* builder(request);
      return;
    }

    yield AlphaXResponseStarted(
      statusCode: response.statusCode,
      headers: response.headers,
      protocol: response.protocol,
    );
    if (response.bodyBytes.isNotEmpty) {
      yield AlphaXResponseChunk(response.bodyBytes);
    }
    yield AlphaXResponseCompleted(
      metrics: response.metrics,
      bytesReceived: response.bodyBytes.length,
    );
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }

  void _record(AlphaXRequest request) {
    if (isClosed) {
      throw StateError('FakeAlphaXTransport is closed');
    }
    requests.add(request);
  }

  Future<void> _wait() async {
    final wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
  }
}
