import 'package:alphax/alphax.dart';
import 'package:alphax_web/alphax_web.dart';

/// Sends one browser Fetch request.
Future<void> main() async {
  final client = AlphaXClient(transport: WebFetchTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    final metrics = await response.completionMetrics;
    print('${response.statusCode}: ${await response.readAsString()}');
    print('protocol metadata: ${metrics.negotiatedProtocol.name}');
  } finally {
    await client.close();
  }
}
