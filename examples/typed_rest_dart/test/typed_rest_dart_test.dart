import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

import 'package:alphax_typed_rest_dart_example/users_api.dart';

void main() {
  test(
    'generated pure-Dart client accepts a caller-supplied transport',
    () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(
          statusCode: 200,
          bodyBytes: <int>[...'{"id":3,"name":"Lin"}'.codeUnits],
        ),
      );
      final client = AlphaXClient(transport: transport);
      final user = await UsersApi(client).getUser('3');

      expect(user.id, 3);
      expect(user.name, 'Lin');
      expect(transport.requests.single.uri.path, '/users/3');
      await client.close();
    },
  );
}
