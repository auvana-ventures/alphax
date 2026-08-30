import 'dart:convert';
import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alphax_typed_rest_example/local_fixture_api.dart';

void main() {
  test(
    'generated client reaches a local API through DartIoTransport',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 45871);
      server.listen((request) async {
        final path = request.uri.path;
        if (path.startsWith('/echo/')) {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('echo:${request.uri.pathSegments.last}');
        } else if (path == '/json') {
          final body = await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(body);
        } else if (path == '/methods/put' || path == '/methods/patch') {
          final body = await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..write('${request.method.toLowerCase()}:$body');
        } else if (path == '/methods/delete') {
          request.response.statusCode = HttpStatus.noContent;
        } else if (path == '/health') {
          request.response.statusCode = HttpStatus.noContent;
        } else if (path == '/empty') {
          request.response.statusCode = HttpStatus.noContent;
        } else if (path == '/status') {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('bad request');
        } else if (path == '/slow') {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          request.response
            ..statusCode = HttpStatus.ok
            ..write('slow');
        } else if (path == '/stream') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text;
          request.response.write('one');
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          request.response.write('two');
        } else if (path == '/multipart') {
          final bytes = await request.fold<List<int>>(<int>[], (all, chunk) {
            all.addAll(chunk);
            return all;
          });
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write('${request.headers.contentType?.mimeType}:${bytes.length}');
        }
        await request.response.close();
      });

      final client = AlphaXClient(transport: DartIoTransport());
      try {
        final api = LocalFixtureApi(client);
        expect(await api.echo('a/b'), 'echo:a/b');
        expect(
          await api.postJson(<String, dynamic>{'name': 'local'}),
          <String, dynamic>{
            'name': 'local',
          },
        );
        expect(
          await api.put(<String, dynamic>{'name': 'put'}),
          'put:{"name":"put"}',
        );
        expect(
          await api.patch(<String, dynamic>{'name': 'patch'}),
          'patch:{"name":"patch"}',
        );
        await api.remove();
        expect((await api.head()).statusCode, HttpStatus.noContent);
        expect(await api.empty(), isNull);

        final error = await api.status();
        expect(error.statusCode, HttpStatus.badRequest);
        expect(error.data, 'bad request');

        final streamed = await api.stream().fold<List<int>>(<int>[], (
          all,
          chunk,
        ) {
          all.addAll(chunk);
          return all;
        });
        expect(utf8.decode(streamed), 'onetwo');

        final multipart = AlphaXMultipartBody(<AlphaXMultipartPart>[
          AlphaXMultipartField('name', 'local'),
          AlphaXMultipartFile(
            'file',
            InMemoryAlphaXFileSource(<int>[1, 2, 3], name: 'fixture.bin'),
            filename: 'fixture.bin',
            contentType: 'application/octet-stream',
          ),
        ]);
        final multipartResponse = await api.multipart(multipart);
        expect(
          await multipartResponse.readAsString(),
          'multipart/form-data:${multipart.contentLength}',
        );

        final concurrent = await Future.wait<String>(<Future<String>>[
          api.echo('one'),
          api.echo('two'),
          api.echo('three'),
        ]);
        expect(concurrent, <String>['echo:one', 'echo:two', 'echo:three']);

        final timeoutOptions = AlphaXRequestOptions(
          timeouts: const AlphaXTimeouts(request: Duration(milliseconds: 25)),
        );
        await expectLater(
          api.slow(options: timeoutOptions),
          throwsA(isA<AlphaXTimeoutException>()),
        );

        final cancellation = AlphaXCancellationToken();
        final cancellationFuture = api.slow(
          options: AlphaXRequestOptions(cancellationToken: cancellation),
        );
        await Future<void>.delayed(const Duration(milliseconds: 25));
        cancellation.cancel('fixture cancellation');
        await expectLater(
          cancellationFuture,
          throwsA(isA<AlphaXCancellationException>()),
        );
      } finally {
        await client.close();
        await server.close(force: true);
      }
    },
  );
}
