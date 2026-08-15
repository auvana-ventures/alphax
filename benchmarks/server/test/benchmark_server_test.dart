import 'dart:convert';
import 'dart:io';

import 'package:alphax_benchmark_server/benchmark_server.dart';
import 'package:test/test.dart';

void main() {
  late BenchmarkServer server;
  late BenchmarkServer redirectTargetServer;
  late HttpClient client;

  setUp(() async {
    server = BenchmarkServer();
    await server.start();
    redirectTargetServer = BenchmarkServer();
    await redirectTargetServer.start();
    client = HttpClient();
    _activeServer = server;
    _activeClient = client;
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
    await redirectTargetServer.close();
  });

  test('exposes health and deterministic bytes', () async {
    final health = await _get('/health');
    final bytes = await _get('/bytes/8');
    final connections = await _get('/connections');

    expect(health.statusCode, 200);
    expect(utf8.decode(health.body), '{"status":"ok"}');
    expect(bytes.statusCode, 200);
    expect(bytes.body, deterministicBytes(8, 0));
    expect(bytes.headers.contentLength, 8);
    final connectionJson = jsonDecode(utf8.decode(connections.body)) as Map<String, dynamic>;
    expect(connectionJson['requests_observed'], greaterThanOrEqualTo(3));
    expect(connectionJson['connection_close_events'], 'unavailable:dart-http-server-api');
  });

  test('supports echo, upload validation, headers, status, and redirects', () async {
    final echo = await _request('POST', '/echo', <int>[1, 2, 3]);
    final upload = await _request('POST', '/upload?expected=3', <int>[1, 2, 3]);
    final mismatch = await _request('POST', '/upload?expected=4', <int>[1, 2, 3]);
    final headers = await _get('/headers', requestHeaders: <String, String>{'x-trace': 'trace-1'});
    final status = await _get('/status/418');
    final redirect = await _get('/redirect/2');

    expect(echo.body, <int>[1, 2, 3]);
    final uploadJson = jsonDecode(utf8.decode(upload.body)) as Map<String, dynamic>;
    expect(uploadJson['bytes'], 3);
    expect(uploadJson['expected'], 3);
    expect(uploadJson['ok'], true);
    expect(uploadJson['hash'], isA<String>());
    expect(mismatch.statusCode, 400);
    expect(headers.headers['x-alphax-echo-trace'], contains('trace-1'));
    expect(status.statusCode, 418);
    expect(redirect.body, utf8.encode('redirect complete'));
  });

  test('redirect fixture can inspect sensitive headers at another origin', () async {
    final target = redirectTargetServer.baseUri.resolve('/redirect-target-headers');
    final redirect = await _get(
      '/redirect-cross-origin?to=${Uri.encodeQueryComponent(target.toString())}',
      requestHeaders: <String, String>{
        'authorization': 'Bearer test-token',
        'proxy-authorization': 'Basic test-credentials',
        'cookie': 'session=test-cookie',
      },
    );
    final body = jsonDecode(utf8.decode(redirect.body)) as Map<String, dynamic>;

    expect(redirect.statusCode, 200);
    expect(body['authorization_present'], isFalse);
    expect(body['proxy_authorization_present'], isFalse);
    expect(body['cookie_present'], isFalse);
  });

  test('streams deterministic chunks and delay endpoint waits', () async {
    final stream = await _get('/stream/3/4?delay_ms=1');
    final started = DateTime.now();
    final delayed = await _get('/delay/10');

    expect(stream.body, <int>[
      ...deterministicBytes(4, 0),
      ...deterministicBytes(4, 1),
      ...deterministicBytes(4, 2),
    ]);
    expect(delayed.body, utf8.encode('delayed'));
    expect(
      DateTime.now().difference(started),
      greaterThanOrEqualTo(const Duration(milliseconds: 8)),
    );
  });
}

Future<_ResponseData> _get(
  String path, {
  Map<String, String> requestHeaders = const <String, String>{},
}) => _request('GET', path, const <int>[], requestHeaders: requestHeaders);

Future<_ResponseData> _request(
  String method,
  String path,
  List<int> body, {
  Map<String, String> requestHeaders = const <String, String>{},
}) async {
  final base = _activeServer.baseUri;
  final relative = Uri.parse(path);
  final request = await _activeClient.openUrl(
    method,
    base.replace(path: relative.path, query: relative.query),
  );
  request.headers.add('content-type', 'application/octet-stream');
  requestHeaders.forEach(request.headers.set);
  if (body.isNotEmpty) {
    request.contentLength = body.length;
    request.add(body);
  }
  final response = await request.close();
  final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
    buffer.addAll(chunk);
    return buffer;
  });
  return _ResponseData(response.statusCode, response.headers, bytes);
}

late BenchmarkServer _activeServer;
late HttpClient _activeClient;

final class _ResponseData {
  const _ResponseData(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final List<int> body;
}
