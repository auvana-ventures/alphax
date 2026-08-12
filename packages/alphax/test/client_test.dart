import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

final class _RecordingTransport implements AlphaXTransport {
  AlphaXRequest? request;
  bool closed = false;

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    this.request = request;
    return AlphaXResponse(statusCode: 204, bodyBytes: const <int>[]);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    this.request = request;
    yield const AlphaXResponseStarted(statusCode: 200);
    yield const AlphaXResponseCompleted(bytesReceived: 0);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  test('AlphaXClient delegates convenience methods to the transport', () async {
    final transport = _RecordingTransport();
    final client = AlphaXClient(transport: transport);

    final response = await client.get(Uri.parse('https://example.com/items'));

    expect(response.statusCode, 204);
    expect(transport.request?.method, 'GET');
    expect(transport.request?.uri.path, '/items');
  });

  test('client checks cancellation before sending', () async {
    final transport = _RecordingTransport();
    final token = AlphaXCancellationToken()..cancel('test cancellation');
    final client = AlphaXClient(transport: transport);

    await expectLater(
      client.get(Uri.parse('https://example.com'), cancellationToken: token),
      throwsA(isA<AlphaXCancelledException>()),
    );
    expect(transport.request, isNull);
  });

  test('client closes the transport', () async {
    final transport = _RecordingTransport();
    await AlphaXClient(transport: transport).close();

    expect(transport.closed, isTrue);
  });
}
