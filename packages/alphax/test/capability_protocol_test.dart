import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  test('capabilities distinguish supported, unsupported, and unknown', () {
    const capabilities = AlphaXCapabilities(
      http11: AlphaXSupport.supported,
      http2: AlphaXSupport.unsupported,
      http3: AlphaXSupport.unknown,
      streamingDownload: AlphaXSupport.supported,
    );

    expect(capabilities.supports(AlphaXCapability.http11), isTrue);
    expect(capabilities.supports(AlphaXCapability.http2), isFalse);
    expect(capabilities.supportFor(AlphaXCapability.http3), AlphaXSupport.unknown);
  });

  test('responses report actual protocol and explicit fallback separately', () {
    const fallback = AlphaXProtocolFallback(
      requested: AlphaXProtocolPreference.http3,
      negotiated: AlphaXProtocol.http2,
      reason: AlphaXProtocolFallbackReason.network,
    );
    final response = AlphaXResponse(
      statusCode: 200,
      protocol: AlphaXProtocol.http2,
      requestedProtocol: AlphaXProtocolPreference.http3,
      protocolFallback: fallback,
    );

    expect(response.protocol, AlphaXProtocol.http2);
    expect(response.requestedProtocol, AlphaXProtocolPreference.http3);
    expect(response.protocolFallback?.negotiated, AlphaXProtocol.http2);
  });

  test('method parser only accepts the required HTTP surface', () {
    expect(HttpMethod.parse('patch'), HttpMethod.patch);
    expect(HttpMethod.tryParse('CONNECT'), isNull);
    expect(HttpMethod.options.value, 'OPTIONS');
  });
}
