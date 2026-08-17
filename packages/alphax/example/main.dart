import 'dart:convert';

import 'package:alphax/alphax.dart';

/// Runs a complete request against a tiny in-process transport.
Future<void> main() async {
  final client = AlphaXClient(transport: const ExampleTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/hello'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}

/// Shows the transport contract without adding a native dependency to
/// `alphax` itself.
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
