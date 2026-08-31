import 'package:alphax/alphax.dart';
import 'package:alphax/app_client.dart';

import 'custom_transport.dart';

/// Shows the application facade around a caller-supplied pure-Dart client.
Future<void> main() async {
  final raw = AlphaXClient(transport: const ExampleTransport());
  final client = AlphaXAppClient.owned(
    raw,
    baseUrl: 'https://example.com/api',
  );
  try {
    final response = await client.get(
      '/hello',
      queryParameters: <String, Object?>{'source': 'example'},
      headers: <String, String>{'x-example': 'app-client'},
    );
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
