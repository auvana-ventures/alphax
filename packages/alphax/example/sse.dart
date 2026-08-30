import 'package:alphax/alphax.dart';
import 'package:alphax/sse.dart';

/// Consumes one SSE response from a caller-owned, already configured client.
Future<void> consumeSse(AlphaXClient client, Uri uri) async {
  final response = await client.send(
    AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: AlphaXHeaders({'accept': 'text/event-stream'}),
    ),
  );

  await for (final event in response.stream.transform(AlphaXSseParser())) {
    print('${event.event ?? 'message'}: ${event.data}');
  }
}
