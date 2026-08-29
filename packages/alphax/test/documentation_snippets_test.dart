import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  test('portable policy and custom transport documentation stays constructible', () async {
    final client = AlphaXClient(
      transport: const _DocumentationTransport(),
      middleware: <AlphaXMiddleware>[
        AlphaXAuthenticationMiddleware(accessToken: _accessToken),
        AlphaXCookieMiddleware(AlphaXCookieJar()),
        AlphaXRetryMiddleware(
          policy: AlphaXRetryPolicy(initialDelay: Duration.zero),
        ),
        AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        AlphaXResilienceMiddleware(),
      ],
    );

    try {
      final response = await client.get(
        Uri.https('example.com', '/documentation'),
        timeout: const AlphaXTimeouts(
          connect: Duration(seconds: 1),
          request: Duration(seconds: 2),
          read: Duration(seconds: 3),
          overall: Duration(seconds: 4),
        ),
        protocolPreference: AlphaXProtocolPreference.http3,
        onDownloadProgress: (_) {},
      );

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'documentation');
    } finally {
      await client.close();
    }
  });

  test('protocol requirement and capability inspection use core types', () {
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: Uri.https('example.com', '/required'),
      protocolPreference: AlphaXProtocolPreference.http3,
      protocolRequirement: AlphaXProtocolRequirement.http3,
    );
    const capabilities = AlphaXCapabilities(
      http11: AlphaXSupport.supported,
      http3: AlphaXSupport.unknown,
    );

    expect(request.protocolRequirement, AlphaXProtocolRequirement.http3);
    expect(capabilities.supportFor(AlphaXCapability.http3), AlphaXSupport.unknown);
  });
}

Future<String?> _accessToken() async => 'documentation-token';

final class _DocumentationTransport extends AlphaXTransport {
  const _DocumentationTransport();

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
    negotiatedProtocolReporting: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async => AlphaXResponse(
    statusCode: 200,
    bodyBytes: <int>[100, 111, 99, 117, 109, 101, 110, 116, 97, 116, 105, 111, 110],
    protocol: AlphaXProtocol.http11,
  );

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => const Stream<AlphaXEvent>.empty();

  @override
  Future<void> close() async {}
}
