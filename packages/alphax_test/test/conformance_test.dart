import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';

void main() {
  defineAlphaXTransportConformanceTests(
    'FakeAlphaXTransport',
    () => FakeAlphaXTransport(
      response: AlphaXResponse(
        statusCode: 200,
        bodyBytes: <int>[1, 2, 3],
      ),
    ),
  );
}
