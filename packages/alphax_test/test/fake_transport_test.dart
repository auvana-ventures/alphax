import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

void main() {
  group('FakeAlphaXTransport', () {
    test('records requests and returns the configured response', () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(statusCode: 201, bodyBytes: <int>[1, 2, 3]),
      );
      final request = AlphaXRequest(method: HttpMethod.post, uri: Uri.parse('https://example.com'));

      final response = await transport.send(request);

      expect(response.statusCode, 201);
      expect(response.bodyBytes, <int>[1, 2, 3]);
      expect(transport.requests, <AlphaXRequest>[request]);
    });

    test('emits default response events', () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(statusCode: 200, bodyBytes: <int>[7, 8]),
      );
      final events = await transport
          .sendStreaming(
            AlphaXRequest(method: HttpMethod.get, uri: Uri.parse('https://example.com')),
          )
          .toList();

      expect(events, hasLength(3));
      expect(events[0], isA<AlphaXResponseStarted>());
      expect((events[1] as AlphaXResponseChunk).bytes, <int>[7, 8]);
      expect((events[2] as AlphaXResponseCompleted).bytesReceived, 2);
    });

    test('supports deterministic delay cancellation', () async {
      final token = AlphaXCancellationToken();
      final transport = FakeAlphaXTransport(delay: const Duration(seconds: 1));
      final future = transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://example.com'),
          cancellationToken: token,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      token.cancel('test cancellation');

      await expectLater(future, throwsA(isA<AlphaXCancellationException>()));
    });

    test('supports predefined failures', () async {
      final transport = FakeAlphaXTransport(
        error: const AlphaXConnectionException('offline'),
      );

      await expectLater(
        transport.send(
          AlphaXRequest(method: HttpMethod.get, uri: Uri.parse('https://example.com')),
        ),
        throwsA(isA<AlphaXConnectionException>()),
      );
    });
  });
}
