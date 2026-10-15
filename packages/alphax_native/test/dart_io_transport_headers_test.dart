import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Uri uri;
  late DartIoTransport transport;
  late List<String> requestEncodings;
  late List<String> repeatedValues;
  final pdfBytes = utf8.encode('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n');
  final gzipBytes = gzip.encode(pdfBytes);

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    uri = Uri.parse('http://127.0.0.1:${server.port}/document.pdf');
    transport = DartIoTransport();
    server.listen((request) {
      requestEncodings = <String>[
        for (final value in request.headers[HttpHeaders.acceptEncodingHeader] ?? <String>[])
          ...value.split(',').map((encoding) => encoding.trim()),
      ];
      repeatedValues = <String>[
        for (final value in request.headers['x-many'] ?? <String>[])
          ...value.split(',').map((item) => item.trim()),
      ];
      final compress = requestEncodings.contains('gzip');
      final bytes = compress ? gzipBytes : pdfBytes;
      request.response.headers.contentType = ContentType('application', 'pdf');
      request.response.contentLength = bytes.length;
      if (compress) {
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      }
      request.response.add(bytes);
      unawaited(request.response.close());
    });
  });

  tearDown(() async {
    await transport.close();
    await server.close(force: true);
  });

  test('explicit identity replaces the native gzip default for PDF bytes', () async {
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: uri,
        headers: AlphaXHeaders(<String, String>{'Accept-Encoding': 'identity'}),
      ),
    );
    final bytes = await response.readAsBytes();

    expect(requestEncodings, <String>['identity']);
    expect(response.headers.values(HttpHeaders.contentEncodingHeader), isEmpty);
    expect(response.headers[HttpHeaders.contentLengthHeader], '${pdfBytes.length}');
    expect(bytes, pdfBytes);
  });

  test('omitted encoding keeps the native gzip default and compressed wire bytes', () async {
    final response = await transport.send(AlphaXRequest(method: HttpMethod.get, uri: uri));
    final bytes = await response.readAsBytes();

    expect(requestEncodings, <String>['gzip']);
    expect(response.headers.values(HttpHeaders.contentEncodingHeader), <String>['gzip']);
    expect(response.headers[HttpHeaders.contentLengthHeader], '${gzipBytes.length}');
    expect(bytes, gzipBytes);
  });

  test('explicit repeated values replace defaults without losing their order', () async {
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: uri,
        headers: AlphaXHeaders.fromEntries(const <MapEntry<String, String>>[
          MapEntry<String, String>('Accept-Encoding', 'br'),
          MapEntry<String, String>('accept-encoding', 'identity'),
          MapEntry<String, String>('X-Many', 'one'),
          MapEntry<String, String>('x-many', 'two'),
        ]),
      ),
    );
    final bytes = await response.readAsBytes();

    expect(requestEncodings, <String>['br', 'identity']);
    expect(repeatedValues, <String>['one', 'two']);
    expect(response.headers.values(HttpHeaders.contentEncodingHeader), isEmpty);
    expect(bytes, pdfBytes);
  });
}
