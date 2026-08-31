import 'package:alphax_native/alphax_native.dart';

/// Shows the ordinary native Flutter application setup.
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
