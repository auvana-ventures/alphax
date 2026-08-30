import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

import 'package:alphax_protobuf_interop/protobuf_example.dart';
import 'package:alphax_protobuf_interop/proto/fixture.pb.dart';

void main() {
  test(
    'maps a GeneratedMessage through AlphaX bytes in both directions',
    () async {
      final request = createGreetingRequest(
        Greeting()
          ..name = 'Ada'
          ..count = 3,
      );
      expect(request.body, isA<AlphaXBytesBody>());
      expect(request.body.contentType, 'application/x-protobuf');

      final transport = FakeAlphaXTransport(
        responseBuilder: (_) => AlphaXResponse(
          statusCode: 200,
          headers: AlphaXHeaders(<String, String>{
            'content-type': 'application/x-protobuf',
          }),
          bodyBytes: request.body is AlphaXBytesBody
              ? (request.body as AlphaXBytesBody).bytes
              : const <int>[],
        ),
      );
      final client = AlphaXClient(transport: transport);
      try {
        final response = await client.send(request);
        final decoded = await decodeGreeting(response);

        expect(decoded.name, 'Ada');
        expect(decoded.count, 3);
        expect(transport.requests, hasLength(1));
      } finally {
        await client.close();
      }
    },
  );
}
