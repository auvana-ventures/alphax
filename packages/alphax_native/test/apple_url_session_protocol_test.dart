import 'package:alphax/alphax.dart';
import 'package:alphax_native/src/apple_url_session_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('Apple URLSession protocol mapping', () {
    test('preserves URLSession capabilities', () {
      final capabilities = appleCapabilitiesFromNative(<String, Object?>{
        'transportName': 'Apple URLSession',
        'transportVersion': 'Foundation / OS 15.0.0',
        'http11': 'supported',
        'http2': 'supported',
        'http3': 'supported',
        'streamingUpload': 'supported',
        'nativeFileDownload': 'supported',
        'negotiatedProtocolReporting': 'supported',
      });

      expect(capabilities.transportName, 'Apple URLSession');
      expect(capabilities.supports(AlphaXCapability.http11), isTrue);
      expect(capabilities.supports(AlphaXCapability.http2), isTrue);
      expect(capabilities.supports(AlphaXCapability.http3), isTrue);
      expect(capabilities.supports(AlphaXCapability.streamingUpload), isTrue);
      expect(capabilities.supports(AlphaXCapability.nativeFileDownload), isTrue);
      expect(
        capabilities.supports(AlphaXCapability.negotiatedProtocolReporting),
        isTrue,
      );
      expect(capabilities.supports(AlphaXCapability.proxyConfiguration), isFalse);
    });

    test('does not report fallback before the final protocol is known', () {
      expect(
        appleProtocolFallback(
          AlphaXProtocolPreference.http3,
          AlphaXProtocol.unknown,
        ),
        isNull,
      );
    });

    test('reports a negotiated H3 result without fallback', () {
      expect(
        appleProtocolFallback(
          AlphaXProtocolPreference.http3,
          AlphaXProtocol.http3,
        ),
        isNull,
      );
    });

    test('reports H3 to H2 fallback explicitly', () {
      final fallback = appleProtocolFallback(
        AlphaXProtocolPreference.http3,
        AlphaXProtocol.http2,
      );

      expect(fallback, isNotNull);
      expect(fallback!.requested, AlphaXProtocolPreference.http3);
      expect(fallback.negotiated, AlphaXProtocol.http2);
    });
  });
}
