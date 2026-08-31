import 'dart:async';
import 'dart:convert';

import 'package:alphax/app_client.dart';
import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  group('URL resolution', () {
    test('uses the base URL as a directory for relative paths', () async {
      expect(
        await _requestUri('https://api.example.com', 'users'),
        Uri.parse('https://api.example.com/users'),
      );
      expect(
        await _requestUri('https://api.example.com/', '/users'),
        Uri.parse('https://api.example.com/users'),
      );
      expect(
        await _requestUri('https://api.example.com/v1', 'users'),
        Uri.parse('https://api.example.com/v1/users'),
      );
      expect(
        await _requestUri('https://api.example.com/v1/', 'users/1'),
        Uri.parse('https://api.example.com/v1/users/1'),
      );
      expect(
        await _requestUri('https://api.example.com/v1/', '../users'),
        Uri.parse('https://api.example.com/users'),
      );
      expect(
        await _requestUri('https://api.example.com/v1/', '/users'),
        Uri.parse('https://api.example.com/users'),
      );
    });

    test('absolute HTTP and HTTPS targets bypass the base URL', () async {
      expect(
        await _requestUri('https://api.example.com/v1', 'http://other.example/status'),
        Uri.parse('http://other.example/status'),
      );
    });

    test('follows Uri resolution for empty, query-only, dot, encoded, and IPv6 targets', () async {
      expect(
        await _requestUri('https://api.example.com/v1/', ''),
        Uri.parse('https://api.example.com/v1/'),
      );
      expect(
        await _requestUri('https://api.example.com/v1/', '?page=2'),
        Uri.parse('https://api.example.com/v1/?page=2'),
      );
      expect(
        await _requestUri('https://api.example.com/v1/', './users/%2Fdetail'),
        Uri.parse('https://api.example.com/v1/users/%2Fdetail'),
      );
      expect(
        await _requestUri('https://api.example.com/v1/', 'https://[2001:db8::1]:8443/status'),
        Uri.parse('https://[2001:db8::1]:8443/status'),
      );
    });

    test('merges base, path, and request queries with request precedence', () async {
      final uri = await _requestUri(
        'https://api.example.com/v1?tenant=base&keep=yes',
        'users?tenant=path&from=path',
        queryParameters: <String, Object?>{
          'tenant': 'request',
          'page': 2,
          'enabled': true,
          'ratio': 1.5,
          'tag': <String>['one', 'two'],
        },
      );

      expect(uri.path, '/v1/users');
      expect(uri.queryParametersAll, <String, List<String>>{
        'tenant': <String>['request'],
        'keep': <String>['yes'],
        'from': <String>['path'],
        'page': <String>['2'],
        'enabled': <String>['true'],
        'ratio': <String>['1.5'],
        'tag': <String>['one', 'two'],
      });
      expect(
        uri.query,
        'tenant=request&keep=yes&from=path&page=2&enabled=true&ratio=1.5&tag=one&tag=two',
      );
    });

    test('null and empty iterables remove inherited query keys', () async {
      final uri = await _requestUri(
        'https://api.example.com?remove=base&keep=base',
        'items?remove=path&path=value',
        queryParameters: <String, Object?>{
          'remove': null,
          'keep': <String>[],
          'path': 'request',
        },
      );

      expect(uri.queryParametersAll, <String, List<String>>{
        'path': <String>['request'],
      });
    });

    test('rejects unsupported query values', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await expectLater(
        client.get('/items', queryParameters: <String, Object?>{'when': DateTime(2026)}),
        throwsArgumentError,
      );
      await expectLater(
        client.get('/items', queryParameters: <String, Object?>{'value': double.nan}),
        throwsArgumentError,
      );
      await expectLater(
        client.get('/items', queryParameters: <String, Object?>{'value': double.infinity}),
        throwsArgumentError,
      );
    });

    test('rejects fragments and non-HTTP targets', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await expectLater(client.get('/items#fragment'), throwsArgumentError);
      await expectLater(client.get('ftp://example.com/items'), throwsArgumentError);
      await expectLater(client.get('//other.example/items'), throwsArgumentError);
      await expectLater(client.get('https://user:pass@other.example/items'), throwsArgumentError);
    });

    test('rejects invalid base URLs', () {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);

      expect(
        () => AlphaXAppClient.borrowed(raw, baseUrl: 'ftp://example.com'),
        throwsArgumentError,
      );
      expect(
        () => AlphaXAppClient.borrowed(raw, baseUrl: 'https://'),
        throwsArgumentError,
      );
      expect(
        () => AlphaXAppClient.borrowed(raw, baseUrl: 'https://example.com#fragment'),
        throwsArgumentError,
      );
      expect(
        () => AlphaXAppClient.borrowed(raw, baseUrl: 'https://user:pass@example.com'),
        throwsArgumentError,
      );
    });
  });

  group('request mapping', () {
    test('maps all supported verbs and simple headers', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await client.get('/get', headers: <String, String>{'X-Trace': 'one'});
      await client.post('/post', data: <String, Object?>{'ok': true});
      await client.put('/put', body: AlphaXBody.text('put'));
      await client.patch('/patch', data: <String, Object?>{'ok': true});
      await client.delete('/delete');
      await client.head('/head');

      expect(
        transport.requests.map((request) => request.method),
        <HttpMethod>[
          HttpMethod.get,
          HttpMethod.post,
          HttpMethod.put,
          HttpMethod.patch,
          HttpMethod.delete,
          HttpMethod.head,
        ],
      );
      expect(transport.requests.first.headers['x-trace'], 'one');
    });

    test('converts JSON data and preserves explicit bodies', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await client.post('/json', data: <String, Object?>{'name': 'Yuvraj'});
      final jsonBody = transport.requests.single.body;
      expect(jsonBody, isA<AlphaXJsonBody>());
      expect(
        await jsonBody.openStream().expand((chunk) => chunk).toList(),
        utf8.encode('{"name":"Yuvraj"}'),
      );
      expect(jsonBody.contentType, 'application/json; charset=utf-8');

      await client.post('/null', data: null);
      expect(
        await transport.requests[1].body.openStream().expand((chunk) => chunk).toList(),
        utf8.encode('null'),
      );

      await expectLater(
        client.post('/null-conflict', data: null, body: AlphaXBody.empty()),
        throwsArgumentError,
      );

      await client.post('/text', body: AlphaXBody.text('raw'));
      expect(transport.requests[2].body, isA<AlphaXTextBody>());
    });

    test('rejects data and body together', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await expectLater(
        client.post('/items', data: <String, Object?>{'ok': true}, body: AlphaXBody.empty()),
        throwsArgumentError,
      );
    });

    test('converts simple headers through AlphaXHeaders validation', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await client.get('/items', headers: <String, String>{'X-Request-ID': 'abc'});
      expect(transport.requests.single.headers.names, <String>['x-request-id']);
      expect(transport.requests.single.headers['X-REQUEST-ID'], 'abc');
      await expectLater(
        client.get('/items', headers: <String, String>{'x-test': 'bad\nvalue'}),
        throwsArgumentError,
      );
    });
  });

  group('timeouts and cancellation', () {
    test('applies a client default and a request override', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(
        raw,
        baseUrl: 'https://api.example.com',
        timeout: const Duration(seconds: 30),
      );
      addTearDown(raw.close);

      await client.get('/default');
      await client.get('/override', timeout: const Duration(seconds: 5));
      expect(transport.requests[0].timeouts.overall, const Duration(seconds: 30));
      expect(transport.requests[1].timeouts.overall, const Duration(seconds: 5));
    });

    test('does not add a timeout when no default or override is supplied', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await client.get('/no-timeout');
      expect(transport.requests.single.timeouts.isEmpty, isTrue);
    });

    test('passes the caller cancellation token to AlphaX', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);
      final token = AlphaXCancellationToken()..cancel('cancelled in test');

      await expectLater(
        client.get('/cancelled', cancellationToken: token),
        throwsA(isA<AlphaXCancelledException>()),
      );
      expect(transport.requests, isEmpty);
    });

    test('preserves underlying response and transport errors', () async {
      final response = AlphaXResponse(statusCode: 201, bodyBytes: <int>[1, 2]);
      final transport = _RecordingTransport(response: response);
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      expect(await client.get('/response'), same(response));

      const error = AlphaXTransportException('transport failed');
      transport.error = error;
      await expectLater(client.get('/failure'), throwsA(same(error)));
    });

    test('does not buffer or replace a streamed AlphaX response', () async {
      final body = AlphaXResponseBody.stream(
        Stream<List<int>>.fromIterable(<List<int>>[
          <int>[1],
          <int>[2],
        ]),
        contentLength: 2,
      );
      final response = AlphaXResponse(statusCode: 200, body: body);
      final transport = _RecordingTransport(response: response);
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      final returned = await client.get('/stream');
      expect(returned, same(response));
      expect(await returned.readAsBytes(), <int>[1, 2]);
    });
  });

  group('delegation and ownership', () {
    test('retains middleware behavior from the wrapped AlphaXClient', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(
        transport: transport,
        middleware: const <AlphaXMiddleware>[_HeaderMiddleware()],
      );
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');
      addTearDown(raw.close);

      await client.get('/middleware');
      expect(transport.requests.single.headers['x-from-middleware'], 'yes');
    });

    test('owned close closes the wrapped client once and rejects requests', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.owned(raw, baseUrl: 'https://api.example.com');

      final first = client.close();
      expect(client.close(), same(first));
      await first;

      expect(transport.closeCalls, 1);
      await expectLater(client.get('/after-close'), throwsA(isA<AlphaXClientClosedException>()));
      await expectLater(
        raw.get(Uri.parse('https://api.example.com')),
        throwsA(isA<AlphaXClientClosedException>()),
      );
    });

    test('borrowed close leaves the caller-owned client usable', () async {
      final transport = _RecordingTransport();
      final raw = AlphaXClient(transport: transport);
      final client = AlphaXAppClient.borrowed(raw, baseUrl: 'https://api.example.com');

      final first = client.close();
      expect(client.close(), same(first));
      await first;

      expect(transport.closeCalls, 0);
      expect((await raw.get(Uri.parse('https://api.example.com/raw'))).statusCode, 200);
      await raw.close();
      expect(transport.closeCalls, 1);
    });

    test('rejects non-positive default timeouts during construction', () {
      final raw = AlphaXClient(transport: _RecordingTransport());

      expect(
        () => AlphaXAppClient.borrowed(
          raw,
          baseUrl: 'https://api.example.com',
          timeout: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}

Future<Uri> _requestUri(
  String baseUrl,
  String path, {
  Map<String, Object?>? queryParameters,
}) async {
  final transport = _RecordingTransport();
  final raw = AlphaXClient(transport: transport);
  final client = AlphaXAppClient.borrowed(raw, baseUrl: baseUrl);
  try {
    await client.get(path, queryParameters: queryParameters);
    return transport.requests.single.uri;
  } finally {
    await raw.close();
  }
}

final class _RecordingTransport extends AlphaXTransport {
  _RecordingTransport({AlphaXResponse? response})
    : response = response ?? AlphaXResponse(statusCode: 200);

  final List<AlphaXRequest> requests = <AlphaXRequest>[];
  AlphaXResponse response;
  Object? error;
  int closeCalls = 0;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities.unknown();

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    requests.add(request);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return response;
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) => const Stream<AlphaXEvent>.empty();

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

final class _HeaderMiddleware extends AlphaXMiddleware {
  const _HeaderMiddleware();

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) =>
      next(request.copyWith(headers: request.headers.add('x-from-middleware', 'yes')));
}
