import 'package:alphax_web/alphax_web.dart';
import 'package:test/test.dart';

const _isBrowser = bool.fromEnvironment('dart.library.js_interop');
const _fixtureUrl = String.fromEnvironment('ALPHAX_WS_URL');

void main() {
  test('browser connector preserves text, binary, and negotiated subprotocol', () async {
    if (!_isBrowser) {
      return;
    }
    if (_fixtureUrl.isEmpty) {
      fail('ALPHAX_WS_URL must point to the local WebSocket fixture');
    }

    final connector = createAlphaXWebSocketConnector();
    expect(connector.capabilities.customHeaders, AlphaXSupport.unsupported);
    expect(connector.capabilities.manualPingPong, AlphaXSupport.unsupported);
    expect(connector.capabilities.receivePauseResume, AlphaXSupport.unsupported);

    final session = await connector.connect(
      Uri.parse('$_fixtureUrl/echo'),
      protocols: <String>['other.protocol', 'alpha.v1'],
    );
    addTearDown(session.close);

    expect(session.negotiatedSubprotocol, 'alpha.v1');
    final received = session.messages.take(2).toList();
    await session.send(const AlphaXWebSocketMessage.text('browser text'));
    await session.send(AlphaXWebSocketMessage.binary(<int>[4, 5, 6]));

    expect(await received, <AlphaXWebSocketMessage>[
      const AlphaXWebSocketMessage.text('browser text'),
      AlphaXWebSocketMessage.binary(<int>[4, 5, 6]),
    ]);
  });

  test('browser peer close remains observable through the portable session', () async {
    if (!_isBrowser) {
      return;
    }
    if (_fixtureUrl.isEmpty) {
      fail('ALPHAX_WS_URL must point to the local WebSocket fixture');
    }

    final session = await createAlphaXWebSocketConnector().connect(
      Uri.parse('$_fixtureUrl/peer-close'),
    );
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
  });

  test('browser abnormal close does not become a normal close', () async {
    if (!_isBrowser) {
      return;
    }
    if (_fixtureUrl.isEmpty) {
      fail('ALPHAX_WS_URL must point to the local WebSocket fixture');
    }

    final session = await createAlphaXWebSocketConnector().connect(
      Uri.parse('$_fixtureUrl/abrupt'),
    );
    await expectLater(
      session.messages.drain<void>(),
      throwsA(isA<AlphaXWebSocketException>()),
    );

    final info = await session.done;
    expect(info.origin, AlphaXWebSocketCloseOrigin.error);
    expect(info.code, anyOf(isNull, 1006));
  });
}
