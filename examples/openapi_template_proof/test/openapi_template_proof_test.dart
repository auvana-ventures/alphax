import 'dart:convert';
import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:test/test.dart';

import 'package:alphax_openapi_template_proof/fixture_models.dart';
import 'package:alphax_openapi_template_proof/users_api.dart';

void main() {
  late HttpServer server;
  late List<String> requestBodies;
  late List<String> requestIds;

  setUp(() async {
    requestBodies = <String>[];
    requestIds = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 45874);
    server.listen((request) async {
      final response = request.response;
      requestIds.add(request.headers.value('X-Request-ID') ?? '');
      final body = await utf8.decoder.bind(request).join();
      requestBodies.add(body);
      response.headers.contentType = ContentType.json;

      if (request.method == 'GET' && request.uri.path == '/users/42') {
        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode(<String, Object?>{'id': 42, 'name': 'Ada'}));
      } else if (request.method == 'GET' && request.uri.path == '/users/missing') {
        response.statusCode = HttpStatus.notFound;
      } else if (request.method == 'POST' && request.uri.path == '/users') {
        response.statusCode = HttpStatus.created;
        final input = jsonDecode(body) as Map<String, dynamic>;
        response.write(jsonEncode(<String, Object?>{'id': 43, 'name': input['name']}));
      } else {
        response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('official OpenAPI template plus alphax_generator reaches AlphaX directly', () async {
    final client = AlphaXClient(transport: DartIoTransport());
    try {
      final api = UsersApi(client);
      final user = await api.getUser('42', 'request-1', true);
      final created = await api.createUser(const CreateUser('Grace'));
      final missing = await api.getUser('missing', 'request-2', null);

      expect(user, isNotNull);
      expect(user!.id, 42);
      expect(user.name, 'Ada');
      expect(created, isNotNull);
      expect(created!.id, 43);
      expect(created.name, 'Grace');
      expect(missing, isNull);
      expect(requestIds, <String>['request-1', '', 'request-2']);
      expect(requestBodies[1], '{"name":"Grace"}');
    } finally {
      await client.close();
    }
  });

  test('the generated declaration and implementation have no framework runtime seam', () {
    for (final path in <String>['lib/users_api.dart', 'lib/users_api.g.dart']) {
      final source = File(path).readAsStringSync();
      for (final forbidden in <String>['Dio', 'Retrofit', 'Chopper', 'package:http']) {
        expect(source, isNot(contains(forbidden)), reason: path);
      }
    }
  });
}
