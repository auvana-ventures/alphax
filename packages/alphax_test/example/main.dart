import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';

/// Runs an AlphaX request without contacting a network or test server.
Future<void> main() async {
  final transport = FakeAlphaXTransport(
    response: AlphaXResponse(
      statusCode: 200,
      bodyBytes: utf8.encode('deterministic response'),
    ),
  );
  final client = AlphaXClient(transport: transport);

  try {
    final response = await client.get(Uri.https('example.com', '/health'));
    print('${response.statusCode}: ${await response.readAsString()}');
    print('recorded requests: ${transport.requests.length}');
  } finally {
    await client.close();
  }
}
