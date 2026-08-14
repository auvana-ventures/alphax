import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  group('AlphaXRequest', () {
    test('normalizes method and validates the URI', () {
      final request = AlphaXRequest(
        method: HttpMethod.post,
        uri: Uri.parse('https://example.com/items'),
        body: AlphaXBody.text('hello'),
      );

      expect(request.method, HttpMethod.post);
      expect(request.body.contentLength, 5);
    });

    test('rejects relative and non-HTTP URIs', () {
      expect(
        () => AlphaXRequest(method: HttpMethod.get, uri: Uri.parse('/items')),
        throwsArgumentError,
      );
      expect(
        () => AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse('ftp://example.com/items'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive timeouts', () {
      expect(
        () => AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://example.com'),
          timeout: const AlphaXTimeout(total: Duration.zero),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AlphaXResponse', () {
    test('copies bytes and exposes status helpers', () {
      final input = <int>[72, 105];
      final response = AlphaXResponse(statusCode: 200, bodyBytes: input);
      input[0] = 0;

      expect(response.bodyBytes, <int>[72, 105]);
      expect(response.text, 'Hi');
      expect(response.isSuccessful, isTrue);
      expect(response.isRedirect, isFalse);
    });
  });
}
