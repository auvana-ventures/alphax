import 'package:alphax/alphax.dart';
import 'package:alphax_native/src/android_cronet_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('Android Cronet protocol mapping', () {
    test('preserves provider diagnostics and supported capabilities', () {
      final capabilities = androidCapabilitiesFromNative(<String, Object?>{
        'transportName': 'Android Cronet',
        'providerName': 'Google-Play-Services-Cronet-Provider',
        'transportVersion': '151.0.7922.29',
        'http11': 'supported',
        'http2': 'supported',
        'http3': 'supported',
        'negotiatedProtocolReporting': 'supported',
      });

      expect(
        capabilities.transportName,
        'Android Cronet (Google-Play-Services-Cronet-Provider)',
      );
      expect(capabilities.transportVersion, '151.0.7922.29');
      expect(capabilities.supports(AlphaXCapability.http3), isTrue);
      expect(
        capabilities.supports(AlphaXCapability.negotiatedProtocolReporting),
        isTrue,
      );
    });

    test('does not claim H3 for a fallback provider', () {
      final capabilities = androidCapabilitiesFromNative(<String, Object?>{
        'transportName': 'Android Cronet',
        'providerName': 'Java Cronet Fallback',
        'http11': 'supported',
        'http2': 'unsupported',
        'http3': 'unsupported',
      });

      expect(capabilities.supports(AlphaXCapability.http11), isTrue);
      expect(capabilities.supports(AlphaXCapability.http2), isFalse);
      expect(capabilities.supports(AlphaXCapability.http3), isFalse);
    });

    test('reports H3 as the actual protocol when negotiated', () {
      expect(
        androidProtocolFallback(
          AlphaXProtocolPreference.http3,
          AlphaXProtocol.http3,
        ),
        isNull,
      );
    });

    test('reports H3 to H2 fallback explicitly', () {
      final fallback = androidProtocolFallback(
        AlphaXProtocolPreference.http3,
        AlphaXProtocol.http2,
      );

      expect(fallback, isNotNull);
      expect(fallback!.requested, AlphaXProtocolPreference.http3);
      expect(fallback.negotiated, AlphaXProtocol.http2);
    });
  });
}
