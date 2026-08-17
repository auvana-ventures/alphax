import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:alphax_dio/alphax_dio.dart';
import 'package:dio/dio.dart';

/// Keeps Dio's request API while routing the adapter through AlphaX.
Future<void> main() async {
  final alphaClient = AlphaXClient(transport: const ExampleTransport());
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
    ..httpClientAdapter = AlphaXDioAdapter(alphaClient);

  try {
    final response = await dio.get<String>('/health');
    print('${response.statusCode}: ${response.data}');
  } finally {
    dio.close(force: true);
  }
}

/// Provides a deterministic response so this adapter example needs no native
/// transport package or live server.
final class ExampleTransport extends AlphaXTransport {
  /// Creates the deterministic example transport.
  const ExampleTransport();

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
    negotiatedProtocolReporting: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async => AlphaXResponse(
    statusCode: 200,
    bodyBytes: utf8.encode('Dio response through AlphaX.'),
    protocol: AlphaXProtocol.http11,
  );

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => const Stream<AlphaXEvent>.empty();

  @override
  Future<void> close() async {}
}
