import 'package:alphax/alphax.dart';

import 'custom_transport.dart';

/// Runs a complete pure-Dart request against the supplied transport.
Future<void> main() async {
  final client = AlphaXClient(transport: const ExampleTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/hello'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
