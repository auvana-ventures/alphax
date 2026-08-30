import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alphax_typed_rest_example/users_api.dart';

void main() {
  test('generated source stays on the direct AlphaX runtime seam', () {
    final source = File('lib/users_api.g.dart').readAsStringSync();
    expect(source, contains('AlphaXClient _client'));
    for (final forbidden in <String>[
      'Dio',
      'Retrofit',
      'Chopper',
      'package:http',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  test('generated clients call the supplied AlphaXClient directly', () async {
    final transport = FakeAlphaXTransport(
      response: AlphaXResponse(
        statusCode: 200,
        bodyBytes: <int>[...'{"id":7,"name":"Ada"}'.codeUnits],
      ),
    );
    final client = AlphaXClient(transport: transport);
    final api = UsersApi(client);

    final user = await api.getUser('a/b', 2, 'secret');

    expect(user.id, 7);
    expect(user.name, 'Ada');
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.method, HttpMethod.get);
    expect(
      transport.requests.single.uri.toString(),
      'https://api.example.test/users/a%2Fb?tenant=alpha&page=2',
    );
    expect(transport.requests.single.headers['authorization'], 'secret');
    expect(transport.requests.single.headers['x-client'], 'typed-example');

    await client.close();
  });

  test(
    'generated JSON body and wrapper preserve AlphaX response metadata',
    () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(
          statusCode: 201,
          bodyBytes: <int>[...'{"id":8,"name":"Grace"}'.codeUnits],
        ),
      );
      final client = AlphaXClient(transport: transport);
      final api = UsersApi(client);

      final result = await api.replaceUser('8', const CreateUser('Grace'));

      expect(result.statusCode, 201);
      expect(result.data.name, 'Grace');
      expect(transport.requests.single.method, HttpMethod.put);
      expect(
        await transport.requests.single.body.openStream().fold<List<int>>(
          <int>[],
          (all, chunk) {
            all.addAll(chunk);
            return all;
          },
        ),
        <int>[...'{"name":"Grace"}'.codeUnits],
      );

      await client.close();
    },
  );

  test(
    'generated mappings preserve options, cancellation, repeated query, and body kinds',
    () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(
          statusCode: 200,
          bodyBytes: <int>[...'{"id":12,"name":"Options"}'.codeUnits],
        ),
      );
      final client = AlphaXClient(transport: transport);
      final api = UsersApi(client);
      final token = AlphaXCancellationToken();
      final options = AlphaXRequestOptions(
        timeouts: const AlphaXTimeouts(request: Duration(seconds: 2)),
        cancellationToken: token,
        redirectPolicy: const AlphaXRedirectPolicy(
          mode: AlphaXRedirectMode.manual,
        ),
      );

      await api.getUser('one', null, 'token', options: options);
      await api.headerPrecedence();
      await api.cancellable(token);
      await api.search(<String>['first', 'second']);
      await api.sendText('hello');
      await api.sendBytes(<int>[1, 2, 3]);
      await api.sendStream(Stream<List<int>>.value(<int>[4, 5]));
      await api.sendFileBody(InMemoryAlphaXFileSource(<int>[6, 7]));

      expect(
        transport.requests[0].timeouts.request,
        const Duration(seconds: 2),
      );
      expect(
        transport.requests[0].redirectPolicy.mode,
        AlphaXRedirectMode.manual,
      );
      expect(transport.requests[0].cancellationToken, same(token));
      expect(transport.requests[1].headers['x-override'], 'method');
      expect(transport.requests[2].cancellationToken, same(token));
      expect(transport.requests[3].uri.queryParametersAll['tag'], <String>[
        'first',
        'second',
      ]);
      expect(transport.requests[4].body, isA<AlphaXTextBody>());
      expect(transport.requests[4].body.contentType, 'text/custom');
      expect(transport.requests[5].body, isA<AlphaXBytesBody>());
      expect(transport.requests[6].body, isA<AlphaXStreamBody>());
      expect(transport.requests[7].body, isA<AlphaXFileBody>());

      await client.close();
    },
  );

  test(
    'generated multipart and file operations reuse AlphaX representations',
    () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(statusCode: 200, bodyBytes: <int>[1, 2]),
      );
      final client = AlphaXClient(transport: transport);
      final api = UsersApi(client);
      final target = InMemoryAlphaXFileTarget();
      final source = InMemoryAlphaXFileSource(<int>[3, 4], name: 'upload.bin');

      final download = await api.download(target);
      final upload = await api.upload(source);
      final multipart = AlphaXMultipartBody(<AlphaXMultipartPart>[
        AlphaXMultipartField('name', 'Ada'),
        AlphaXMultipartFile(
          'file',
          source,
          filename: 'upload.bin',
          contentType: 'application/octet-stream',
        ),
      ]);
      await api.multipart(multipart);

      expect(download.bytesTransferred, 2);
      expect(target.bytes, <int>[1, 2]);
      expect(upload.bytesTransferred, 2);
      expect(transport.requests[1].body, isA<AlphaXFileBody>());
      expect(transport.requests[2].body, same(multipart));
      expect(transport.requests[2].headers['content-type'], isNull);
      expect(
        transport.requests[2].body.contentType,
        startsWith('multipart/form-data; boundary='),
      );

      await client.close();
    },
  );

  test(
    'generated cancellation stays request-scoped and fails before dispatch',
    () async {
      final transport = FakeAlphaXTransport();
      final client = AlphaXClient(transport: transport);
      final api = UsersApi(client);
      final token = AlphaXCancellationToken()..cancel('test cancellation');

      await expectLater(
        api.cancellable(token),
        throwsA(isA<AlphaXCancelledException>()),
      );
      expect(transport.requests, isEmpty);
      await client.close();
    },
  );

  test(
    'json_serializable and Freezed models remain caller-owned hooks',
    () async {
      final transport = FakeAlphaXTransport(
        responseBuilder: (request) {
          final body = request.uri.path.endsWith('json-serializable')
              ? '{"id":10,"name":"Json"}'
              : '{"id":11,"name":"Freezed"}';
          return AlphaXResponse(
            statusCode: 200,
            bodyBytes: <int>[...body.codeUnits],
          );
        },
      );
      final client = AlphaXClient(transport: transport);
      final api = UsersApi(client);

      final jsonUser = await api.getJsonSerializable();
      final freezedUser = await api.getFreezed();

      expect(jsonUser.name, 'Json');
      expect(freezedUser.name, 'Freezed');
      await client.close();
    },
  );

  test('decoder hooks support lists of typed models', () async {
    final transport = FakeAlphaXTransport(
      response: AlphaXResponse(
        statusCode: 200,
        bodyBytes: <int>[...'[{"id":13,"name":"Lin"}]'.codeUnits],
      ),
    );
    final client = AlphaXClient(transport: transport);
    final users = await UsersApi(client).listUsers();

    expect(users.single.name, 'Lin');
    await client.close();
  });
}
