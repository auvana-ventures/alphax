import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

/// Sends one request through the Dart IO fallback transport.
Future<void> main() async {
  final client = AlphaXClient(transport: DartIoTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    final metrics = await response.completionMetrics;
    print('${response.statusCode}: ${await response.readAsString()}');
    print('negotiated protocol: ${metrics.negotiatedProtocol.name}');
  } finally {
    await client.close();
  }
}
