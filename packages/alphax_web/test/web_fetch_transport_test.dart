import 'package:alphax_web/alphax_web.dart';
import 'package:test/test.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

void main() {
  test('entry factory returns one AlphaXClient around WebFetchTransport', () async {
    const middleware = <AlphaXMiddleware>[_TestMiddleware()];

    final client = createAlphaXClient(
      middleware: middleware,
      withCredentials: true,
    );
    addTearDown(client.close);

    expect(client, isA<AlphaXClient>());
    expect(client.middleware, hasLength(1));
    expect(client.middleware.single, same(middleware.single));
    expect(client.transport, isA<WebFetchTransport>());
    expect((client.transport as WebFetchTransport).withCredentials, isTrue);
  });

  test('entry factory owns close and rejects requests after close', () async {
    final client = createAlphaXClient();
    final transport = client.transport;

    final firstClose = client.close();
    expect(client.close(), same(firstClose));
    await firstClose;

    expect(client.isClosed, isTrue);
    await expectLater(
      client.get(Uri.https('example.com', '/')),
      throwsA(isA<AlphaXClientClosedException>()),
    );
    await expectLater(
      transport.send(
        AlphaXRequest(method: HttpMethod.get, uri: Uri.https('example.com', '/')),
      ),
      throwsA(isA<AlphaXClientClosedException>()),
    );
  });

  test('rc.4 explicit WebFetchTransport construction remains valid', () async {
    final transport = WebFetchTransport();
    final client = AlphaXClient(transport: transport);

    expect(client.transport, same(transport));
    await client.close();
  });

  test('re-export exposes the ordinary AlphaX request surface', () {
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: Uri.https('example.com', '/items'),
      headers: AlphaXHeaders(const <String, String>{'accept': 'application/json'}),
      body: AlphaXBody.json(<String, Object>{'ok': true}),
      cancellationToken: AlphaXCancellationToken(),
      timeout: const AlphaXTimeouts(overall: Duration(seconds: 1)),
      protocolPreference: AlphaXProtocolPreference.http2,
      protocolRequirement: AlphaXProtocolRequirement.http2,
    );

    expect(request.headers['accept'], 'application/json');
    expect(request.body, isA<AlphaXBody>());
    expect(request.timeout, isA<AlphaXTimeouts>());
    expect(const AlphaXTlsPolicy.platformDefault().isPlatformDefault, isTrue);
    expect(const AlphaXProxyPolicy.system().mode, AlphaXProxyMode.system);
    expect(const AlphaXRequestMetrics(), isA<AlphaXRequestMetrics>());
    expect(const AlphaXTransportException('test'), isA<AlphaXException>());
  });

  test('reports browser protocol boundaries without guessing', () {
    final transport = WebFetchTransport();

    expect(transport.capabilities.http11, AlphaXSupport.unknown);
    expect(transport.capabilities.http2, AlphaXSupport.unknown);
    expect(transport.capabilities.http3, AlphaXSupport.unknown);
    expect(transport.capabilities.negotiatedProtocolReporting, AlphaXSupport.unsupported);
  });

  test('unsupported protocol requirements fail closed before browser dispatch', () async {
    final transport = WebFetchTransport();
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: Uri.https('example.com', '/'),
      protocolRequirement: AlphaXProtocolRequirement.http3,
    );

    if (_isWeb) {
      await expectLater(
        transport.send(request),
        throwsA(isA<AlphaXProtocolRequirementException>()),
      );
    } else {
      await expectLater(
        transport.send(request),
        throwsA(isA<AlphaXUnsupportedCapabilityException>()),
      );
    }
    await transport.close();
  });
}

final class _TestMiddleware extends AlphaXMiddleware {
  const _TestMiddleware();
}
