import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late DartIoTransport transport;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => unawaited(_serve(request)));
    transport = DartIoTransport();
  });

  tearDown(() async {
    await transport.close();
    await server.close(force: true);
  });

  test('parses an SSE response from a production-capable Dart IO stream', () async {
    final client = AlphaXClient(transport: transport);
    addTearDown(client.close);

    final response = await client.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://127.0.0.1:${server.port}/events'),
        headers: AlphaXHeaders({'accept': 'text/event-stream'}),
      ),
    );

    expect(response.headers['content-type'], startsWith('text/event-stream'));
    final events = await response.stream.transform(AlphaXSseParser()).toList();

    expect(events, <AlphaXSseEvent>[
      const AlphaXSseEvent(data: 'native\n🌍'),
      const AlphaXSseEvent(data: 'complete', event: 'update', id: '7', retry: 500),
    ]);
  });

  test('cancels a live native SSE response through AlphaX cancellation', () async {
    final client = AlphaXClient(transport: transport);
    addTearDown(client.close);
    final token = AlphaXCancellationToken();

    final response = await client.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://127.0.0.1:${server.port}/slow-events'),
        cancellationToken: token,
      ),
    );
    final parsed = response.stream.transform(AlphaXSseParser());
    final events = <AlphaXSseEvent>[];
    final completion = parsed.listen(events.add).asFuture<void>();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    token.cancel('native SSE test cancelled');

    await expectLater(completion, throwsA(isA<AlphaXCancellationException>()));
    expect(events, isEmpty);
  });

  test('rejects a pre-cancelled SSE request before transport dispatch', () async {
    final client = AlphaXClient(transport: transport);
    addTearDown(client.close);
    final token = AlphaXCancellationToken()..cancel('cancelled before dispatch');

    await expectLater(
      client.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://127.0.0.1:${server.port}/events'),
          cancellationToken: token,
        ),
      ),
      throwsA(isA<AlphaXCancellationException>()),
    );
  });
}

Future<void> _serve(HttpRequest request) async {
  final response = request.response;
  response.headers
    ..set(HttpHeaders.contentTypeHeader, 'text/event-stream; charset=utf-8')
    ..set(HttpHeaders.cacheControlHeader, 'no-cache');

  if (request.uri.path == '/events') {
    final payload = utf8.encode(
      '\uFEFF: keep-alive\r\n'
      'data: native\r\n'
      'data: 🌍\r\n'
      '\r\n'
      'event: update\n'
      'id: 7\n'
      'retry: 500\n'
      'data: complete\n'
      '\n',
    );
    for (final chunk in _chunks(payload, 3)) {
      response.add(chunk);
      await response.flush();
    }
    await response.close();
    return;
  }

  if (request.uri.path == '/slow-events') {
    response.add(<int>[...utf8.encode('data: partial '), 0xF0]);
    await response.flush();
    await Future<void>.delayed(const Duration(seconds: 1));
    response.add(utf8.encode('\n\ndata: late\n\n'));
  }
  await response.close();
}

Iterable<List<int>> _chunks(List<int> bytes, int chunkSize) sync* {
  for (var offset = 0; offset < bytes.length; offset += chunkSize) {
    final end = (offset + chunkSize).clamp(0, bytes.length);
    yield bytes.sublist(offset, end);
  }
}
