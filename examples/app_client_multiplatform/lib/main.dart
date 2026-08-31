import 'dart:developer' as developer;

import 'client_factory.dart';

/// Uses one application-facing call shape on native and browser targets.
Future<void> main() async {
  final client = await createPlatformClient(baseUrl: 'https://api.example.com');
  try {
    final response = await client.get('/users');
    developer.log('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
