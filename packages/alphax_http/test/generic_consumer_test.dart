import 'package:alphax/alphax.dart';
import 'package:alphax_http/alphax_http.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('an arbitrary injected http.Client consumer needs no AlphaX knowledge', () async {
    final alpha = AlphaXClient(
      transport: FakeAlphaXTransport(
        response: AlphaXResponse(statusCode: 200, bodyBytes: <int>[111, 107]),
      ),
    );
    final httpClient = AlphaXHttpClient(alpha);
    final sdk = _GenericSdk(httpClient);

    expect(await sdk.fetchText(Uri.parse('https://example.test/health')), 'ok');

    httpClient.close();
    await alpha.close();
  });
}

final class _GenericSdk {
  _GenericSdk(this.client);

  final http.Client client;

  Future<String> fetchText(Uri uri) async => (await client.get(uri)).body;
}
