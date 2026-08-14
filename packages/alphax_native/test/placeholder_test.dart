import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:test/test.dart';

void main() {
  test('placeholder reports that native transport selection is pending', () async {
    const transport = ExperimentalAlphaXNativeTransport();

    await expectLater(
      transport.send(
        AlphaXRequest(method: HttpMethod.get, uri: Uri.parse('https://example.com')),
      ),
      throwsA(isA<AlphaXNativeTransportException>()),
    );
  });
}
