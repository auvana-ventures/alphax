import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:alphax_dart_io_prototype/dart_io.dart';
import 'package:test/test.dart';

Uri uriFor(Uri base, String path) => base.replace(path: path);

void main() {
  late HttpServer server;
  late DartIoTransport transport;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/slow') {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (path == '/stream') {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.binary;
        for (final chunk in <List<int>>[
          <int>[1, 2],
          <int>[3, 4],
        ]) {
          request.response.add(chunk);
          await request.response.flush();
        }
        await request.response.close();
        return;
      }
      if (path == '/upload') {
        final body = await request.fold<List<int>>(<int>[], (bytes, chunk) {
          bytes.addAll(chunk);
          return bytes;
        });
        request.response
          ..statusCode = 200
          ..headers.set('x-uploaded', '${body.length}')
          ..add(body);
        await request.response.close();
        return;
      }
      final body = path == '/post'
          ? await request.fold<List<int>>(<int>[], (bytes, chunk) {
              bytes.addAll(chunk);
              return bytes;
            })
          : <int>[7, 8, 9];
      request.response
        ..statusCode = 200
        ..headers.set('x-test', 'ok')
        ..add(body);
      await request.response.close();
    });
    transport = DartIoTransport();
  });

  tearDown(() async {
    await transport.close();
    await server.close(force: true);
  });

  test('supports buffered GET and POST bytes', () async {
    final get = await transport.getBytes(uriFor(baseUri, '/get'));
    final post = await transport.postBytes(uriFor(baseUri, '/post'), <int>[4, 5]);

    expect(get.bodyBytes, <int>[7, 8, 9]);
    expect(get.header('x-test'), 'ok');
    expect(post.bodyBytes, <int>[4, 5]);
  });

  test('emits complete stream events', () async {
    final events = await transport.getStreaming(uriFor(baseUri, '/stream')).toList();

    expect(events.whereType<BenchmarkStreamStarted>(), hasLength(1));
    expect(
      events.whereType<BenchmarkStreamChunk>().expand((event) => event.bytes),
      <int>[1, 2, 3, 4],
    );
    expect(events.whereType<BenchmarkStreamCompleted>().single.bytesTransferred, 4);
  });

  test('cancellation interrupts a delayed request', () async {
    final token = BenchmarkCancellationToken();
    final future = transport.getBytes(
      uriFor(baseUri, '/slow'),
      options: BenchmarkRequestOptions(cancellation: token),
    );
    token.cancel();

    await expectLater(future, throwsA(isA<BenchmarkCancelledException>()));
  });
}
