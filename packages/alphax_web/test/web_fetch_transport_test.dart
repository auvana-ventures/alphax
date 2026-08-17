import 'package:alphax/alphax.dart';
import 'package:alphax_web/alphax_web.dart';
import 'package:test/test.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

void main() {
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
