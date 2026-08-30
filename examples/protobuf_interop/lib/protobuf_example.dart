import 'package:alphax/alphax.dart';

import 'proto/fixture.pb.dart';

/// Encodes a maintained protobuf.dart message as an AlphaX byte body.
AlphaXRequest createGreetingRequest(Greeting greeting) => AlphaXRequest(
  method: HttpMethod.post,
  uri: Uri.parse('https://example.test/greetings'),
  headers: AlphaXHeaders(<String, String>{
    'content-type': 'application/x-protobuf',
  }),
  body: AlphaXBody.bytes(
    greeting.writeToBuffer(),
    contentType: 'application/x-protobuf',
  ),
);

/// Decodes an AlphaX response body using the generated message type.
Future<Greeting> decodeGreeting(AlphaXResponse response) async =>
    Greeting()..mergeFromBuffer(await response.readAsBytes());
