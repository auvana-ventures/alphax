import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

import 'package:alphax_typed_rest_web_example/users_api.dart';

void main() {
  test('generated Web client is transport-independent', () async {
    final transport = FakeAlphaXTransport(
      response: AlphaXResponse(
        statusCode: 200,
        bodyBytes: <int>[...'{"id":9,"name":"Lin"}'.codeUnits],
      ),
    );
    final client = AlphaXClient(transport: transport);
    final user = await WebUsersApi(client).getUser('9');

    expect(user.id, 9);
    expect(
      transport.requests.single.uri.toString(),
      'https://api.example.test/users/9',
    );
    await client.close();
  });
}
