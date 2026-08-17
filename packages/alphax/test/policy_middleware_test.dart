import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

final class _PolicyTransport extends AlphaXTransport {
  _PolicyTransport(this.handler);

  final Future<AlphaXResponse> Function(AlphaXRequest request, int call) handler;
  final List<AlphaXRequest> requests = <AlphaXRequest>[];

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(http11: AlphaXSupport.supported);

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    requests.add(request);
    return handler(request, requests.length);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    final response = await send(request);
    yield AlphaXResponseStarted(statusCode: response.statusCode, headers: response.headers);
    final bytes = await response.body.readAsBytes();
    if (bytes.isNotEmpty) {
      yield AlphaXResponseChunk(bytes);
    }
    yield AlphaXResponseCompleted(bytesReceived: bytes.length);
  }

  @override
  Future<void> close() async {}
}

void main() {
  final uri = Uri.https('example.com', '/items');

  test('retry middleware retries safe replayable requests', () async {
    final transport = _PolicyTransport((_, call) async {
      return AlphaXResponse(statusCode: call == 1 ? 503 : 200, bodyBytes: <int>[call]);
    });
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        AlphaXRetryMiddleware(
          policy: AlphaXRetryPolicy(maxAttempts: 2, initialDelay: Duration.zero),
        ),
      ],
    );

    final response = await client.get(uri);

    expect(response.statusCode, 200);
    expect(transport.requests, hasLength(2));
  });

  test('retry middleware does not replay non-idempotent requests by default', () async {
    final transport = _PolicyTransport((_, __) async => AlphaXResponse(statusCode: 503));
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        AlphaXRetryMiddleware(
          policy: AlphaXRetryPolicy(maxAttempts: 2, initialDelay: Duration.zero),
        ),
      ],
    );

    final response = await client.post(uri, body: AlphaXBody.text('payload'));

    expect(response.statusCode, 503);
    expect(transport.requests, hasLength(1));
  });

  test('authentication middleware refreshes once after a challenge', () async {
    var token = 'old-token';
    var refreshes = 0;
    final transport = _PolicyTransport((request, _) async {
      final authorization = request.headers['authorization'];
      return AlphaXResponse(
        statusCode: authorization == 'Bearer new-token' ? 200 : 401,
      );
    });
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        AlphaXAuthenticationMiddleware(
          accessToken: () => token,
          refreshAccessToken: () {
            refreshes++;
            token = 'new-token';
            return token;
          },
        ),
      ],
    );

    final response = await client.get(uri);

    expect(response.statusCode, 200);
    expect(refreshes, 1);
    expect(transport.requests, hasLength(2));
  });

  test('authentication middleware single-flights concurrent refreshes', () async {
    var token = 'old-token';
    var refreshes = 0;
    final transport = _PolicyTransport((request, _) async {
      await Future<void>.delayed(Duration.zero);
      return AlphaXResponse(
        statusCode: request.headers['authorization'] == 'Bearer new-token' ? 200 : 401,
      );
    });
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        AlphaXAuthenticationMiddleware(
          accessToken: () => token,
          refreshAccessToken: () async {
            refreshes++;
            await Future<void>.delayed(Duration.zero);
            token = 'new-token';
            return token;
          },
        ),
      ],
    );

    final responses = await Future.wait(<Future<AlphaXResponse>>[
      client.get(uri),
      client.get(uri),
    ]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(refreshes, 1);
  });

  test('cookie middleware stores Set-Cookie and sends it on the next request', () async {
    final jar = AlphaXCookieJar();
    final transport = _PolicyTransport((request, call) async {
      if (call == 1) {
        return AlphaXResponse(
          statusCode: 200,
          headers: AlphaXHeaders.fromEntries(<MapEntry<String, String>>[
            const MapEntry<String, String>('set-cookie', 'session=abc; Path=/'),
          ]),
        );
      }
      return AlphaXResponse(statusCode: request.headers['cookie'] == 'session=abc' ? 200 : 400);
    });
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[AlphaXCookieMiddleware(jar)],
    );

    await client.get(uri);
    final response = await client.get(uri);

    expect(response.statusCode, 200);
    expect(await jar.cookieHeaderFor(uri), 'session=abc');
  });

  test('cache middleware serves a fresh buffered response without transport work', () async {
    final cache = AlphaXMemoryCacheStore();
    final transport = _PolicyTransport((_, call) async {
      return AlphaXResponse(
        statusCode: 200,
        headers: AlphaXHeaders({'cache-control': 'max-age=60'}),
        bodyBytes: <int>[call],
      );
    });
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[AlphaXCacheMiddleware(store: cache)],
    );

    final first = await client.get(uri);
    final second = await client.get(uri);

    expect(await first.readAsBytes(), <int>[1]);
    expect(await second.readAsBytes(), <int>[1]);
    expect(transport.requests, hasLength(1));
  });

  test('cache middleware never satisfies a protocol requirement from memory', () async {
    final cache = AlphaXMemoryCacheStore();
    var calls = 0;
    final transport = _PolicyTransport((request, _) async {
      calls++;
      return AlphaXResponse(
        statusCode: 200,
        protocol: AlphaXProtocol.http2,
        requiredProtocol: request.protocolRequirement,
        bodyBytes: <int>[calls],
      );
    });
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        AlphaXCacheMiddleware(store: cache),
      ],
    );

    await client.get(uri);
    final response = await client.get(
      uri,
      protocolRequirement: AlphaXProtocolRequirement.http2,
    );

    expect(response.protocol, AlphaXProtocol.http2);
    expect(transport.requests, hasLength(2));
  });

  test('resilience middleware opens a circuit after repeated failures', () async {
    final transport = _PolicyTransport((_, __) async => AlphaXResponse(statusCode: 503));
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[
        AlphaXResilienceMiddleware(
          policy: const AlphaXResiliencePolicy(
            failureThreshold: 2,
            openDuration: Duration(minutes: 1),
          ),
        ),
      ],
    );

    expect((await client.get(uri)).statusCode, 503);
    expect((await client.get(uri)).statusCode, 503);
    await expectLater(client.get(uri), throwsA(isA<AlphaXCircuitOpenException>()));
    expect(transport.requests, hasLength(2));
  });
}
