import 'dart:async';
import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  group('request bodies', () {
    test('supports empty, bytes, text, and JSON forms', () async {
      expect(await AlphaXBody.empty().openStream().toList(), isEmpty);
      expect(await AlphaXBody.bytes(<int>[1, 2]).openStream().toList(), <List<int>>[
        <int>[1, 2],
      ]);

      final text = AlphaXBody.text('hello');
      expect(await text.openStream().expand((chunk) => chunk).toList(), utf8.encode('hello'));

      final json = AlphaXBody.json(<String, Object?>{'ok': true});
      expect(await json.openStream().expand((chunk) => chunk).toList(), utf8.encode('{"ok":true}'));
    });

    test('stream bodies are single-consumption by default', () async {
      final body = AlphaXStreamBody(Stream<List<int>>.value(<int>[1, 2]));

      expect(await body.openStream().expand((chunk) => chunk).toList(), <int>[1, 2]);
      expect(() => body.openStream(), throwsStateError);
    });

    test('multipart remains streamable and reports unknown length when needed', () async {
      final body = AlphaXMultipartBody(<AlphaXMultipartPart>[
        AlphaXMultipartField('name', 'AlphaX'),
      ]);

      final bytes = await body.openStream().expand((chunk) => chunk).toList();
      final text = utf8.decode(bytes);

      expect(text, contains('name="name"'));
      expect(text, contains('AlphaX'));
      expect(text, endsWith('--alphax-boundary--\r\n'));
      expect(body.contentLength, bytes.length);
    });
  });

  group('response bodies', () {
    test('buffered bodies can be read repeatedly', () async {
      final body = AlphaXResponseBody.bytes(<int>[72, 105]);

      expect(await body.readAsString(), 'Hi');
      expect(await body.readAsBytes(), <int>[72, 105]);
      expect(body.isConsumed, isFalse);
    });

    test('streamed bodies reject a second consumer', () async {
      final body = AlphaXResponseBody.stream(Stream<List<int>>.value(<int>[7, 8]));

      expect(await body.readAsBytes(), <int>[7, 8]);
      expect(body.isConsumed, isTrue);
      expect(() => body.stream, throwsStateError);
    });

    test('JSON response helper decodes without changing transport contracts', () async {
      final response = AlphaXResponse(
        statusCode: 200,
        body: AlphaXResponseBody.bytes(utf8.encode('{"value":3}')),
      );

      expect(await response.readAsJson(), <String, Object?>{'value': 3});
    });
  });
}
