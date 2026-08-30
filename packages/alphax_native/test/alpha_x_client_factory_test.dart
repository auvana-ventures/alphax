import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _transportChannel = MethodChannel('alphax_native/transport');
const _eventsChannel = MethodChannel('alphax_native/events');

final _initializeCalls = <MethodCall>[];
var _closeCalls = 0;
var _failInitialization = false;

bool get _usesPlatformChannel => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_transportChannel, _handleTransportCall);
    messenger.setMockMethodCallHandler(_eventsChannel, (_) async => null);
  });

  tearDownAll(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_transportChannel, null);
    messenger.setMockMethodCallHandler(_eventsChannel, null);
  });

  setUp(() {
    _initializeCalls.clear();
    _closeCalls = 0;
    _failInitialization = false;
  });

  test('facade selects one transport and preserves client configuration', () async {
    const tlsPolicy = AlphaXTlsPolicy.platformDefault();
    const proxyPolicy = AlphaXProxyPolicy.direct();
    const middleware = <AlphaXMiddleware>[_TestMiddleware()];

    final client = await createAlphaXClient(
      middleware: middleware,
      tlsPolicy: tlsPolicy,
      proxyPolicy: proxyPolicy,
    );
    try {
      expect(client.runtimeType, AlphaXClient);
      expect(client.middleware.single, same(middleware.single));
      expect(client.tlsPolicy, same(tlsPolicy));
      expect(client.proxyPolicy, same(proxyPolicy));
      if (_usesPlatformChannel) {
        expect(_initializeCalls, hasLength(1));
        final arguments = _initializeCalls.single.arguments as Map<Object?, Object?>;
        final tlsArguments = arguments['tlsPolicy'] as Map<Object?, Object?>;
        final proxyArguments = arguments['proxyPolicy'] as Map<Object?, Object?>;
        expect(tlsArguments['includePlatformTrust'], isTrue);
        expect(proxyArguments['mode'], 'direct');
      }
      if (Platform.isAndroid) {
        expect(client.transport, isA<AndroidCronetTransport>());
      } else if (Platform.isIOS || Platform.isMacOS) {
        expect(client.transport, isA<AppleUrlSessionTransport>());
      } else {
        expect(client.transport, isA<DartIoTransport>());
      }
    } finally {
      await client.close();
    }
  });

  test('client close owns the selected transport and is idempotent', () async {
    final client = await createAlphaXClient();
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
    if (_usesPlatformChannel) {
      expect(_closeCalls, 1);
    }
  });

  test('provider initialization failure fails client creation without fallback', () async {
    if (_usesPlatformChannel) {
      _failInitialization = true;
      await expectLater(
        createAlphaXClient(),
        throwsA(isA<AlphaXTransportException>()),
      );
      expect(_initializeCalls, hasLength(1));
      expect(_closeCalls, 0);
      return;
    }

    final invalidTlsPolicy = AlphaXTlsPolicy(
      trustAnchors: <AlphaXTrustAnchor>[
        AlphaXTrustAnchor.der(<int>[1, 2, 3]),
      ],
    );
    await expectLater(
      createAlphaXClient(tlsPolicy: invalidTlsPolicy),
      throwsA(isA<AlphaXUnsupportedTlsPolicyException>()),
    );
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

  test('rc.4 explicit and custom transport construction remain valid', () async {
    final explicitTransport = DartIoTransport();
    final explicitClient = AlphaXClient(transport: explicitTransport);
    final customTransport = _CustomTransport();
    final customClient = AlphaXClient(transport: customTransport);

    try {
      expect(explicitClient.transport, same(explicitTransport));
      final response = await customClient.get(Uri.https('example.com', '/'));
      expect(response.statusCode, 204);
      expect(customClient.transport, same(customTransport));
    } finally {
      await explicitClient.close();
      await customClient.close();
    }
  });
}

Future<Object?> _handleTransportCall(MethodCall call) async {
  switch (call.method) {
    case 'initialize':
      _initializeCalls.add(call);
      if (_failInitialization) {
        throw PlatformException(code: 'initialization_failed', message: 'test provider failure');
      }
      return <String, Object?>{'transportName': 'test provider'};
    case 'close':
      _closeCalls++;
      return null;
    default:
      return null;
  }
}

final class _TestMiddleware extends AlphaXMiddleware {
  const _TestMiddleware();
}

final class _CustomTransport extends AlphaXTransport {
  bool _closed = false;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities.unknown();

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    if (_closed) {
      throw const AlphaXClientClosedException();
    }
    return AlphaXResponse(statusCode: 204);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => const Stream<AlphaXEvent>.empty();

  @override
  Future<void> close() async {
    _closed = true;
  }
}
