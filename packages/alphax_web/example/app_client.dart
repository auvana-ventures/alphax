import 'package:alphax_web/alphax_web.dart';

/// Shows the browser application setup with the same facade shape as native.
Future<void> main() async {
  final client = await createAlphaXAppClient(
    baseUrl: 'https://api.example.com',
  );
  try {
    final response = await client.get('/users');
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
