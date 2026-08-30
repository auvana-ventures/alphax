import 'dart:convert';

import 'package:alphax/alphax.dart';

/// A deterministic transport used by the pure-Dart package example.
final class ExampleTransport extends AlphaXTransport {
  /// Creates the deterministic example transport.
  const ExampleTransport();

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
    streamingDownload: AlphaXSupport.supported,
    negotiatedProtocolReporting: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    final bytes = utf8.encode('Hello from ${request.uri.host}.');
    return AlphaXResponse(
      statusCode: 200,
      bodyBytes: bytes,
      protocol: AlphaXProtocol.http11,
      metrics: AlphaXRequestMetrics(
        negotiatedProtocol: AlphaXProtocol.http11,
        downloadedBytes: bytes.length,
      ),
    );
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    final response = await send(request);
    final bytes = response.bodyBytes;
    yield AlphaXResponseStarted(
      statusCode: response.statusCode,
      protocol: response.protocol,
    );
    yield AlphaXResponseChunk(bytes);
    yield AlphaXResponseCompleted(
      bytesReceived: bytes.length,
      metrics: response.metrics,
    );
  }

  @override
  Future<void> close() async {}
}
