import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:test/test.dart';

void main() {
  late _WebSocketFixture fixture;
  late AlphaXWebSocketConnector connector;

  setUp(() async {
    fixture = await _WebSocketFixture.start();
    connector = createAlphaXWebSocketConnector();
  });

  tearDown(() => fixture.close());

  test('reports the maintained native provider capabilities', () {
    expect(connector.capabilities.binaryMessages, AlphaXSupport.supported);
    expect(connector.capabilities.subprotocolNegotiation, AlphaXSupport.supported);
    expect(connector.capabilities.negotiatedSubprotocolReporting, AlphaXSupport.supported);
    expect(connector.capabilities.customHeaders, AlphaXSupport.unsupported);
    expect(connector.capabilities.manualPingPong, AlphaXSupport.unsupported);
    expect(connector.capabilities.receivePauseResume, AlphaXSupport.unsupported);
  });

  test('connects, negotiates, and preserves ordered text and binary messages', () async {
    final session = await connector.connect(
      fixture.uri('/echo'),
      protocols: <String>['other.protocol', 'alpha.v1'],
    );
    addTearDown(session.close);

    expect(session.state, AlphaXWebSocketState.open);
    expect(session.negotiatedSubprotocol, 'alpha.v1');

    final received = session.messages.take(4).toList();
    await session.send(const AlphaXWebSocketMessage.text('one'));
    await session.send(AlphaXWebSocketMessage.binary(<int>[0, 1, 255]));
    await session.send(const AlphaXWebSocketMessage.text('two'));
    await session.send(AlphaXWebSocketMessage.binary(<int>[9, 8]));

    expect(await received, <AlphaXWebSocketMessage>[
      const AlphaXWebSocketMessage.text('one'),
      AlphaXWebSocketMessage.binary(<int>[0, 1, 255]),
      const AlphaXWebSocketMessage.text('two'),
      AlphaXWebSocketMessage.binary(<int>[9, 8]),
    ]);
  });

  test('peer close ends messages and preserves close code and reason', () async {
    final session = await connector.connect(fixture.uri('/peer-close'));
    final messagesDone = session.messages.toList();

    expect(
      await session.done,
      const AlphaXWebSocketCloseInfo(
        origin: AlphaXWebSocketCloseOrigin.peer,
        code: 1001,
        reason: 'server shutdown',
      ),
    );
    expect(await messagesDone, isEmpty);
    expect(session.state, AlphaXWebSocketState.closed);
  });

  test('abrupt provider termination is terminal without a fabricated normal close', () async {
    final session = await connector.connect(fixture.uri('/abrupt'));

    await expectLater(
      session.messages.drain<void>(),
      throwsA(isA<AlphaXWebSocketException>()),
    );
    final info = await session.done;

    expect(info.origin, AlphaXWebSocketCloseOrigin.error);
    expect(info.reason, anyOf(isNull, isEmpty));
    expect(info.code, anyOf(isNull, 1006));
  });

  test('local close is idempotent and prevents later sends', () async {
    final session = await connector.connect(fixture.uri('/echo'));

    final firstClose = session.close(code: 1000, reason: 'finished');
    expect(identical(firstClose, session.close(code: 1000, reason: 'finished')), isTrue);
    await firstClose;

    expect(session.state, AlphaXWebSocketState.closed);
    expect(
      await session.done,
      const AlphaXWebSocketCloseInfo(
        origin: AlphaXWebSocketCloseOrigin.local,
        code: 1000,
        reason: 'finished',
      ),
    );
    await expectLater(
      session.send(const AlphaXWebSocketMessage.text('late')),
      throwsA(isA<AlphaXWebSocketClosedException>()),
    );
  });

  test('rejects invalid local close values before provider dispatch', () async {
    final session = await connector.connect(fixture.uri('/echo'));
    addTearDown(session.close);

    expect(() => session.close(code: 1001), throwsA(isA<ArgumentError>()));
    expect(
      () => session.close(reason: 'reason without code'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => session.close(code: 1000, reason: 'x' * 124),
      throwsA(isA<ArgumentError>()),
    );
    expect(session.state, AlphaXWebSocketState.open);
  });

  test('normalizes connection setup failures', () async {
    await expectLater(
      connector.connect(fixture.uri('/reject')),
      throwsA(
        allOf(
          isA<AlphaXWebSocketException>(),
          isNot(isA<AlphaXWebSocketClosedException>()),
        ),
      ),
    );
  });

  test('cancellation before connect fails without opening a session', () async {
    final token = AlphaXCancellationToken()..cancel('before connect');

    await expectLater(
      connector.connect(fixture.uri('/echo'), cancellationToken: token),
      throwsA(isA<AlphaXCancellationException>()),
    );
  });

  test('cancellation during connect closes the late provider connection', () async {
    final token = AlphaXCancellationToken();
    final connecting = connector.connect(
      fixture.uri('/delayed'),
      cancellationToken: token,
      connectTimeout: const Duration(seconds: 2),
    );
    await fixture.delayedConnectionStarted.future;
    token.cancel('during connect');

    await expectLater(connecting, throwsA(isA<AlphaXCancellationException>()));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });

  test('connect timeout fails without returning a partial session', () async {
    final connecting = connector.connect(
      fixture.uri('/delayed'),
      connectTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(connecting, throwsA(isA<AlphaXTimeoutException>()));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });

  test('cancellation after open maps to local close', () async {
    final token = AlphaXCancellationToken();
    final session = await connector.connect(
      fixture.uri('/echo'),
      cancellationToken: token,
    );

    token.cancel('active session cancelled');

    expect(
      await session.done,
      const AlphaXWebSocketCloseInfo(origin: AlphaXWebSocketCloseOrigin.local),
    );
    expect(session.state, AlphaXWebSocketState.closed);
  });

  test('pausing the receive stream preserves order without losing messages', () async {
    final session = await connector.connect(fixture.uri('/burst'));
    final received = <AlphaXWebSocketMessage>[];
    final paused = Completer<void>();
    final complete = Completer<void>();
    late StreamSubscription<AlphaXWebSocketMessage> subscription;

    subscription = session.messages.listen(
      (message) {
        received.add(message);
        if (received.length == 1) {
          subscription.pause();
          paused.complete();
        }
        if (received.length == 20 && !complete.isCompleted) {
          complete.complete();
        }
      },
      onError: complete.completeError,
      onDone: () {
        if (!complete.isCompleted) {
          complete.complete();
        }
      },
    );
    addTearDown(subscription.cancel);

    await paused.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(received, <AlphaXWebSocketMessage>[const AlphaXWebSocketMessage.text('burst-0')]);

    subscription.resume();
    await complete.future;
    expect(received, hasLength(20));
    expect(
      received,
      List<AlphaXWebSocketMessage>.generate(
        20,
        (index) => AlphaXWebSocketMessage.text('burst-$index'),
      ),
    );
    await session.close();
  });
}

final class _WebSocketFixture {
  _WebSocketFixture._(this._server) : delayedConnectionStarted = Completer<void>();

  final HttpServer _server;
  final Completer<void> delayedConnectionStarted;

  static Future<_WebSocketFixture> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _WebSocketFixture._(server);
    server.listen((request) => unawaited(fixture._handle(request)));
    return fixture;
  }

  Uri uri(String path) => Uri.parse('ws://127.0.0.1:${_server.port}$path');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/abrupt') {
      final key = request.headers.value('sec-websocket-key');
      if (key == null) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final response = request.response
        ..statusCode = HttpStatus.switchingProtocols
        ..headers.add(HttpHeaders.connectionHeader, HttpHeaders.upgradeHeader)
        ..headers.add(HttpHeaders.upgradeHeader, 'websocket')
        ..headers.add('Sec-WebSocket-Accept', _webSocketAccept(key))
        ..contentLength = 0;
      final socket = await response.detachSocket();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      socket.destroy();
      return;
    }

    if (request.uri.path == '/reject') {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.text;
      await request.response.close();
      return;
    }

    if (request.uri.path == '/delayed') {
      delayedConnectionStarted.complete();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    final socket = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: (protocols) {
        if (request.uri.path == '/echo' || request.uri.path == '/delayed') {
          return protocols.contains('alpha.v1') ? 'alpha.v1' : null;
        }
        return null;
      },
    );

    if (request.uri.path == '/peer-close') {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await socket.close(1001, 'server shutdown');
      return;
    }

    if (request.uri.path == '/burst') {
      for (var index = 0; index < 20; index++) {
        socket.add('burst-$index');
      }
      return;
    }

    socket.listen(
      (message) {
        if (message is String) {
          socket.add(message);
        } else if (message is List<int>) {
          socket.add(message);
        }
      },
      onError: (_) {},
      onDone: () {},
    );
  }
}

const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

String _webSocketAccept(String key) => base64Encode(_sha1(utf8.encode('$key$_webSocketGuid')));

List<int> _sha1(List<int> input) {
  final bytes = <int>[...input, 0x80];
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  final bitLength = input.length * 8;
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xFF);
  }

  var h0 = 0x67452301;
  var h1 = 0xEFCDAB89;
  var h2 = 0x98BADCFE;
  var h3 = 0x10325476;
  var h4 = 0xC3D2E1F0;

  for (var offset = 0; offset < bytes.length; offset += 64) {
    final words = List<int>.filled(80, 0);
    for (var index = 0; index < 16; index++) {
      final start = offset + index * 4;
      words[index] =
          (bytes[start] << 24) |
          (bytes[start + 1] << 16) |
          (bytes[start + 2] << 8) |
          bytes[start + 3];
    }
    for (var index = 16; index < 80; index++) {
      words[index] = _rotateLeft(
        words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16],
        1,
      );
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    for (var index = 0; index < 80; index++) {
      final (f, k) = switch (index) {
        < 20 => ((b & c) | ((~b) & d), 0x5A827999),
        < 40 => (b ^ c ^ d, 0x6ED9EBA1),
        < 60 => ((b & c) | (b & d) | (c & d), 0x8F1BBCDC),
        _ => (b ^ c ^ d, 0xCA62C1D6),
      };
      final temp = (_rotateLeft(a, 5) + f + e + k + words[index]) & 0xFFFFFFFF;
      e = d;
      d = c;
      c = _rotateLeft(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
  }

  return <int>[
    ..._wordBytes(h0),
    ..._wordBytes(h1),
    ..._wordBytes(h2),
    ..._wordBytes(h3),
    ..._wordBytes(h4),
  ];
}

int _rotateLeft(int value, int bits) => ((value << bits) | (value >> (32 - bits))) & 0xFFFFFFFF;

List<int> _wordBytes(int word) => <int>[
  (word >> 24) & 0xFF,
  (word >> 16) & 0xFF,
  (word >> 8) & 0xFF,
  word & 0xFF,
];
