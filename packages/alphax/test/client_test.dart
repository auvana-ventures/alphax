import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

final class _RecordingTransport extends AlphaXTransport {
  AlphaXRequest? request;
  bool closed = false;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
    streamingDownload: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    this.request = request;
    return AlphaXResponse(statusCode: 204, bodyBytes: const <int>[]);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    this.request = request;
    yield AlphaXResponseStarted(statusCode: 200);
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
    expect(transport.request?.method, HttpMethod.get);
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

  test('convenience methods expose the required HTTP surface', () async {
    final transport = _RecordingTransport();
    final client = AlphaXClient(transport: transport);
    final uri = Uri.parse('https://example.com');

    await client.post(uri);
    expect(transport.request?.method, HttpMethod.post);
    await client.put(uri);
    expect(transport.request?.method, HttpMethod.put);
    await client.patch(uri);
    expect(transport.request?.method, HttpMethod.patch);
    await client.delete(uri);
    expect(transport.request?.method, HttpMethod.delete);
    await client.head(uri);
    expect(transport.request?.method, HttpMethod.head);
    await client.options(uri);
    expect(transport.request?.method, HttpMethod.options);
  });

  test('client closes the transport', () async {
    final transport = _RecordingTransport();
    await AlphaXClient(transport: transport).close();

    expect(transport.closed, isTrue);
  });
}
