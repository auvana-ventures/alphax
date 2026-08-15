import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  final expiresAt = DateTime.now().add(const Duration(days: 30));
  final primaryPin = AlphaXSpkiPin(
    host: 'api.example.com',
    sha256SpkiBase64: base64Encode(List<int>.filled(32, 1)),
    expiresAt: expiresAt,
  );
  final backupPin = AlphaXSpkiPin(
    host: 'api.example.com',
    sha256SpkiBase64: base64Encode(List<int>.filled(32, 2)),
    expiresAt: expiresAt,
  );

  test('protocol requirements are distinct from preferences', () {
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: Uri.parse('https://api.example.com/data'),
      protocolRequirement: AlphaXProtocolRequirement.http3,
    );

    expect(request.protocolPreference, AlphaXProtocolPreference.auto);
    expect(request.protocolRequirement, AlphaXProtocolRequirement.http3);
    expect(
      AlphaXProtocolRequirement.http3.isSatisfiedBy(AlphaXProtocol.unknown),
      isFalse,
    );
    expect(
      () => AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse('https://api.example.com/data'),
        protocolPreference: AlphaXProtocolPreference.http2,
        protocolRequirement: AlphaXProtocolRequirement.http3,
      ),
      throwsArgumentError,
    );
  });

  test('completion metadata can turn an unknown snapshot into authoritative fallback', () async {
    final response = AlphaXResponse(
      statusCode: 200,
      protocol: AlphaXProtocol.unknown,
      requestedProtocol: AlphaXProtocolPreference.http3,
      completionMetrics: Future<AlphaXRequestMetrics>.value(
        const AlphaXRequestMetrics(negotiatedProtocol: AlphaXProtocol.http2),
      ),
    );

    expect(response.protocol, AlphaXProtocol.unknown);
    expect(response.protocolFallback, isNull);
    final fallback = await response.completionProtocolFallback;
    expect(fallback?.requested, AlphaXProtocolPreference.http3);
    expect(fallback?.negotiated, AlphaXProtocol.http2);
  });

  test('TLS policy is immutable and permits backup pins for one host', () {
    final policy = AlphaXTlsPolicy(
      trustAnchors: <AlphaXTrustAnchor>[
        AlphaXTrustAnchor.der(<int>[1, 2, 3]),
      ],
      pins: <AlphaXSpkiPin>[primaryPin, backupPin],
    );

    expect(policy.pins, hasLength(2));
    expect(policy.trustAnchors.single.derBytes, <int>[1, 2, 3]);
    expect(policy.isPlatformDefault, isFalse);
    expect(() => policy.pins.add(primaryPin), throwsUnsupportedError);
    expect(() => policy.trustAnchors.add(AlphaXTrustAnchor.der(<int>[4])), throwsUnsupportedError);
    expect(
      () => AlphaXTlsPolicy(pins: <AlphaXSpkiPin>[primaryPin, primaryPin]),
      throwsArgumentError,
    );
    expect(
      () => AlphaXTlsPolicy(includePlatformTrust: false),
      throwsArgumentError,
    );
  });

  test('proxy policies expose explicit route semantics without native types', () {
    const credentials = AlphaXProxyCredentials.basic(username: 'user', password: 'secret');
    final policy = AlphaXProxyPolicy.http(
      host: 'proxy.example.com',
      port: 8080,
      credentials: credentials,
    );

    expect(policy.mode, AlphaXProxyMode.explicit);
    expect(policy.scheme, AlphaXProxyScheme.http);
    expect(policy.host, 'proxy.example.com');
    expect(policy.port, 8080);
    expect(policy.credentials?.username, 'user');
    expect(const AlphaXProxyPolicy.direct().mode, AlphaXProxyMode.direct);

    final httpsPolicy = AlphaXProxyPolicy.https(
      host: 'secure-proxy.example.com',
      port: 8443,
    );
    expect(httpsPolicy.mode, AlphaXProxyMode.explicit);
    expect(httpsPolicy.scheme, AlphaXProxyScheme.https);
  });

  test('capabilities keep security controls independent', () {
    const capabilities = AlphaXCapabilities(
      tlsDefaultTrust: AlphaXSupport.supported,
      certificatePinning: AlphaXSupport.unsupported,
      systemProxy: AlphaXSupport.supported,
      directConnectionPolicy: AlphaXSupport.unsupported,
      protocolRequirement: AlphaXSupport.supported,
    );

    expect(capabilities.supports(AlphaXCapability.tlsDefaultTrust), isTrue);
    expect(capabilities.supports(AlphaXCapability.certificatePinning), isFalse);
    expect(
      capabilities.supportFor(AlphaXCapability.directConnectionPolicy),
      AlphaXSupport.unsupported,
    );
    expect(
      capabilities.supportFor(AlphaXCapability.explicitHttpsProxy),
      AlphaXSupport.unknown,
    );
    expect(capabilities.supports(AlphaXCapability.protocolRequirement), isTrue);
  });
}
