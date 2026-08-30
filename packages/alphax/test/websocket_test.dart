import 'dart:async';

import 'package:alphax/websocket.dart';
import 'package:test/test.dart';

void main() {
  test('binary messages copy input and output buffers', () {
    final source = <int>[1, 2, 3];
    final message = AlphaXWebSocketMessage.binary(source);
    source[0] = 9;

    final bytes = (message as AlphaXWebSocketBinaryMessage).bytes;
    bytes[1] = 8;

    expect(message, AlphaXWebSocketMessage.binary(<int>[1, 2, 3]));
    expect(message.bytes, orderedEquals(<int>[1, 2, 3]));
  });

  test('close information preserves nullable provider facts', () {
    const info = AlphaXWebSocketCloseInfo(
      origin: AlphaXWebSocketCloseOrigin.error,
    );

    expect(info.code, isNull);
    expect(info.reason, isNull);
    expect(info, const AlphaXWebSocketCloseInfo(origin: AlphaXWebSocketCloseOrigin.error));
  });

  test('a custom connector can implement the portable lifecycle contract', () async {
    final connector = _FakeConnector();
    final session = await connector.connect(
      Uri.parse('ws://example.test/socket'),
      protocols: <String>['alpha.v1'],
    );

    expect(session.state, AlphaXWebSocketState.open);
    expect(session.negotiatedSubprotocol, 'alpha.v1');

    final received = session.messages.first;
    await session.send(const AlphaXWebSocketMessage.text('outbound'));
    connector.session.addIncoming(const AlphaXWebSocketMessage.text('inbound'));

    expect(await received, const AlphaXWebSocketMessage.text('inbound'));
    expect(connector.session.sent, <AlphaXWebSocketMessage>[
      const AlphaXWebSocketMessage.text('outbound'),
    ]);

    final firstClose = session.close(code: 1000, reason: 'finished');
    expect(identical(firstClose, session.close()), isTrue);
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
}

final class _FakeConnector implements AlphaXWebSocketConnector {
  _FakeConnector();

  final session = _FakeSession();

  @override
  AlphaXWebSocketCapabilities get capabilities => const AlphaXWebSocketCapabilities(
    transportName: 'test fake',
    binaryMessages: AlphaXSupport.supported,
    subprotocolNegotiation: AlphaXSupport.supported,
    negotiatedSubprotocolReporting: AlphaXSupport.supported,
    customHeaders: AlphaXSupport.unsupported,
    manualPingPong: AlphaXSupport.unsupported,
    receivePauseResume: AlphaXSupport.unknown,
  );

  @override
  Future<AlphaXWebSocketSession> connect(
    Uri uri, {
    Iterable<String> protocols = const <String>[],
    AlphaXCancellationToken? cancellationToken,
    Duration? connectTimeout,
  }) async {
    cancellationToken?.throwIfCancelled();
    final requestedProtocols = protocols.toList();
    session.protocol = requestedProtocols.isEmpty ? null : requestedProtocols.first;
    return session;
  }
}

final class _FakeSession implements AlphaXWebSocketSession {
  final _incoming = StreamController<AlphaXWebSocketMessage>();
  final sent = <AlphaXWebSocketMessage>[];
  final _done = Completer<AlphaXWebSocketCloseInfo>();
  AlphaXWebSocketState _state = AlphaXWebSocketState.open;
  Future<void>? _closeFuture;
  String? protocol;

  @override
  AlphaXWebSocketState get state => _state;

  @override
  String? get negotiatedSubprotocol => protocol;

  @override
  Stream<AlphaXWebSocketMessage> get messages => _incoming.stream;

  @override
  Future<AlphaXWebSocketCloseInfo> get done => _done.future;

  @override
  Future<void> send(AlphaXWebSocketMessage message) async {
    if (_state != AlphaXWebSocketState.open) {
      throw const AlphaXWebSocketClosedException();
    }
    sent.add(message);
  }

  @override
  Future<void> close({int? code, String? reason}) {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    if (_state == AlphaXWebSocketState.closed) {
      return Future<void>.value();
    }
    _state = AlphaXWebSocketState.closing;
    return _closeFuture = _close(code, reason);
  }

  Future<void> _close(int? code, String? reason) async {
    _state = AlphaXWebSocketState.closed;
    await _incoming.close();
    _done.complete(
      AlphaXWebSocketCloseInfo(
        origin: AlphaXWebSocketCloseOrigin.local,
        code: code,
        reason: reason,
      ),
    );
  }

  void addIncoming(AlphaXWebSocketMessage message) {
    if (_state == AlphaXWebSocketState.open) {
      _incoming.add(message);
    }
  }
}
