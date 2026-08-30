import 'dart:async';
import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:alphax_http/alphax_http.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('AlphaXHttpClient', () {
    late _RecordingTransport transport;
    late AlphaXClient alphaXClient;
    late AlphaXHttpClient client;

    setUp(() {
      transport = _RecordingTransport();
      alphaXClient = AlphaXClient(transport: transport);
      client = AlphaXHttpClient(alphaXClient);
    });

    tearDown(() async {
      await alphaXClient.close();
    });

    test('maps all AlphaX-supported package:http verbs', () async {
      const methods = <String>[
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD',
        'OPTIONS',
      ];

      for (final method in methods) {
        final response = await client.send(
          http.Request(method, Uri.parse('https://example.test/$method')),
        );
        await response.stream.drain<void>();
      }

      expect(
        transport.requests.map((request) => request.method.value),
        methods,
      );
    });

    test('keeps the original URI, headers, and body length', () async {
      final uri = Uri.parse('https://example.test/items?filter=active&limit=2');
      final request = http.Request('POST', uri)
        ..headers['X-Request-Id'] = 'request-1'
        ..headers['content-type'] = 'text/plain; charset=utf-8'
        ..body = 'hello AlphaX';

      final response = await client.send(request);
      await response.stream.drain<void>();

      final alphaRequest = transport.requests.single;
      expect(identical(alphaRequest.uri, uri), isTrue);
      expect(alphaRequest.headers['x-request-id'], 'request-1');
      expect(alphaRequest.headers['content-type'], 'text/plain; charset=utf-8');
      expect(alphaRequest.body.contentLength, utf8.encode('hello AlphaX').length);
      expect(transport.requestBodies.single, utf8.encode('hello AlphaX'));
    });

    test('preserves empty and buffered byte request bodies', () async {
      final emptyResponse = await client.send(
        http.Request('GET', Uri.parse('https://example.test/empty')),
      );
      await emptyResponse.stream.drain<void>();

      final bytesRequest = http.Request('POST', Uri.parse('https://example.test/bytes'))
        ..bodyBytes = <int>[0, 1, 2, 255];
      final bytesResponse = await client.send(bytesRequest);
      await bytesResponse.stream.drain<void>();

      expect(transport.requests[0].body.contentLength, 0);
      expect(transport.requestBodies[0], isEmpty);
      expect(transport.requests[1].body.contentLength, 4);
      expect(transport.requestBodies[1], <int>[0, 1, 2, 255]);
    });

    test('streams known-length, unknown-length, and large request bodies', () async {
      final known = http.StreamedRequest('POST', Uri.parse('https://example.test/known'))
        ..contentLength = 6;
      final knownFuture = client.send(known);
      known.sink
        ..add(<int>[1, 2])
        ..add(<int>[3, 4, 5, 6])
        ..close();
      final knownResponse = await knownFuture;
      await knownResponse.stream.drain<void>();

      final unknown = http.StreamedRequest('POST', Uri.parse('https://example.test/unknown'));
      final unknownFuture = client.send(unknown);
      unknown.sink
        ..add(<int>[7, 8])
        ..add(<int>[9])
        ..close();
      final unknownResponse = await unknownFuture;
      await unknownResponse.stream.drain<void>();

      final largeChunk = List<int>.generate(64 * 1024, (index) => index % 251);
      final large = http.StreamedRequest('POST', Uri.parse('https://example.test/large'))
        ..contentLength = largeChunk.length * 16;
      final largeFuture = client.send(large);
      for (var index = 0; index < 16; index++) {
        large.sink.add(largeChunk);
      }
      large.sink.close();
      final largeResponse = await largeFuture;
      await largeResponse.stream.drain<void>();

      expect(transport.requests[0].body.contentLength, 6);
      expect(transport.requestBodies[0], <int>[1, 2, 3, 4, 5, 6]);
      expect(transport.requests[1].body.contentLength, isNull);
      expect(transport.requestBodies[1], <int>[7, 8, 9]);
      expect(transport.requests[2].body.contentLength, largeChunk.length * 16);
      expect(transport.requestBodies[2].length, largeChunk.length * 16);
      expect(transport.requestBodies[2].sublist(0, largeChunk.length), largeChunk);
    });

    test('passes finalized package:http multipart bytes through unchanged', () async {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('https://example.test/upload'),
            )
            ..fields['title'] = 'hello'
            ..files.add(
              http.MultipartFile(
                'asset',
                Stream<List<int>>.fromIterable(<List<int>>[
                  <int>[0, 1],
                  <int>[2, 3, 255],
                ]),
                5,
                filename: 'payload.bin',
                contentType: http.MediaType('application', 'octet-stream'),
              ),
            );

      final response = await client.send(request);
      await response.stream.drain<void>();

      final alphaRequest = transport.requests.single;
      final body = transport.requestBodies.single;
      final bodyText = latin1.decode(body);
      expect(alphaRequest.headers['content-type'], startsWith('multipart/form-data; boundary='));
      expect(alphaRequest.body.contentLength, request.contentLength);
      expect(body.length, request.contentLength);
      expect(bodyText, contains('name="title"'));
      expect(bodyText, contains('hello'));
      expect(bodyText, contains('name="asset"; filename="payload.bin"'));
      expect(bodyText, contains('content-type: application/octet-stream'));
      expect(body, contains(0));
      expect(body, contains(255));
    });

    test('maps AlphaX response metadata to a streamed response', () async {
      var sourceListened = false;
      final source = StreamController<List<int>>(
        onListen: () => sourceListened = true,
      );
      transport.responseFactory = (_) => AlphaXResponse(
        statusCode: 302,
        headers: AlphaXHeaders.fromEntries(<MapEntry<String, String>>[
          const MapEntry<String, String>('x-value', 'one'),
          const MapEntry<String, String>('x-value', 'two'),
        ]),
        body: AlphaXResponseBody.stream(source.stream, contentLength: 6),
      );

      final request = http.Request('GET', Uri.parse('https://example.test/stream'));
      final response = await client.send(request);

      expect(response, isA<http.StreamedResponse>());
      expect(response.statusCode, 302);
      expect(response.headers['x-value'], 'one, two');
      expect(response.contentLength, 6);
      expect(identical(response.request, request), isTrue);
      expect(response.isRedirect, isTrue);
      expect(response.reasonPhrase, isNull);
      expect(response.persistentConnection, isTrue);
      expect(sourceListened, isFalse);

      final bodyFuture = response.stream.toList();
      source.add(<int>[1, 2]);
      source.add(<int>[3, 4, 5, 6]);
      await source.close();
      expect(await bodyFuture, <List<int>>[
        <int>[1, 2],
        <int>[3, 4, 5, 6],
      ]);
      expect(sourceListened, isTrue);
    });

    test('maps response stream errors without buffering the response', () async {
      transport.responseFactory = (_) => AlphaXResponse(
        statusCode: 200,
        body: AlphaXResponseBody.stream(
          Stream<List<int>>.error(const AlphaXResponseBodyException('body failed')),
        ),
      );

      final response = await client.send(
        http.Request('GET', Uri.parse('https://example.test/failure')),
      );

      await expectLater(
        response.stream,
        emitsError(isA<http.ClientException>()),
      );
    });

    test('does not turn HTTP error status codes into transport errors', () async {
      transport.responseFactory = (_) => AlphaXResponse(
        statusCode: 503,
        bodyBytes: utf8.encode('service unavailable'),
      );

      final response = await client.get(Uri.parse('https://example.test/status'));

      expect(response.statusCode, 503);
      expect(response.body, 'service unavailable');
      await expectLater(
        client.read(Uri.parse('https://example.test/status')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('maps normalized AlphaX transport failures to ClientException', () async {
      transport.error = const AlphaXConnectionException('offline');

      await expectLater(
        client.send(http.Request('GET', Uri.parse('https://example.test/offline'))),
        throwsA(
          predicate<Object>((error) {
            return error is http.ClientException &&
                error.uri == Uri.parse('https://example.test/offline') &&
                error.message.contains('offline') &&
                !error.toString().contains('AlphaXConnectionException');
          }),
        ),
      );
    });

    test('does not expose an unknown provider exception as the primary contract', () async {
      transport.error = StateError('provider detail should not escape');

      await expectLater(
        client.send(http.Request('GET', Uri.parse('https://example.test/provider-error'))),
        throwsA(
          predicate<Object>((error) {
            return error is http.ClientException &&
                error.message == 'AlphaX request failed.' &&
                !error.toString().contains('provider detail');
          }),
        ),
      );
    });

    test('maps Abortable request cancellation before response headers', () async {
      final abort = Completer<void>();
      transport.responseFactory = (request) async {
        final token = request.cancellationToken;
        expect(token, isNotNull);
        await token!.whenCancelled;
        token.throwIfCancelled();
        return AlphaXResponse(statusCode: 200);
      };

      final request = http.AbortableRequest(
        'GET',
        Uri.parse('https://example.test/cancel'),
        abortTrigger: abort.future,
      );
      final responseFuture = client.send(request);
      await Future<void>.delayed(Duration.zero);
      abort.complete();

      await expectLater(responseFuture, throwsA(isA<http.RequestAbortedException>()));
    });

    test('maps transport cancellation after response headers to the response stream', () async {
      final abort = Completer<void>();
      late StreamController<List<int>> responseController;
      transport.responseFactory = (request) {
        responseController = StreamController<List<int>>();
        return AlphaXResponse(
          statusCode: 200,
          body: AlphaXResponseBody.stream(responseController.stream),
        );
      };

      final request = http.AbortableRequest(
        'GET',
        Uri.parse('https://example.test/cancel-stream'),
        abortTrigger: abort.future,
      );
      final response = await client.send(request);
      final streamResult = expectLater(
        response.stream,
        emitsError(isA<http.RequestAbortedException>()),
      );
      abort.complete();

      await streamResult;
      await responseController.close();
    });

    test('aborts a streamed response before the consumer starts listening', () async {
      final abort = Completer<void>();
      final responseController = StreamController<List<int>>();
      transport.responseFactory = (_) => AlphaXResponse(
        statusCode: 200,
        body: AlphaXResponseBody.stream(responseController.stream),
      );

      final request = http.AbortableRequest(
        'GET',
        Uri.parse('https://example.test/cancel-before-listen'),
        abortTrigger: abort.future,
      );
      final response = await client.send(request);
      abort.complete();

      await expectLater(
        response.stream,
        emitsError(isA<http.RequestAbortedException>()),
      );
      await responseController.close();
    });

    test('response stream cancellation propagates to the AlphaX stream', () async {
      final cancelled = Completer<void>();
      final source = StreamController<List<int>>(
        onCancel: () {
          if (!cancelled.isCompleted) {
            cancelled.complete();
          }
        },
      );
      transport.responseFactory = (_) => AlphaXResponse(
        statusCode: 200,
        body: AlphaXResponseBody.stream(source.stream),
      );

      final response = await client.send(
        http.Request('GET', Uri.parse('https://example.test/cancel-response-stream')),
      );
      final subscription = response.stream.listen((_) {});
      await subscription.cancel();

      await cancelled.future.timeout(const Duration(seconds: 1));
      await source.close();
    });

    test('maps followRedirects and maxRedirects without inventing other policy', () async {
      final follow = http.Request('GET', Uri.parse('https://example.test/follow'))
        ..followRedirects = true
        ..maxRedirects = 2;
      final followResponse = await client.send(follow);
      await followResponse.stream.drain<void>();

      final manual = http.Request('GET', Uri.parse('https://example.test/manual'))
        ..followRedirects = false
        ..maxRedirects = 0;
      final manualResponse = await client.send(manual);
      await manualResponse.stream.drain<void>();

      expect(transport.requests[0].redirectPolicy.mode, AlphaXRedirectMode.follow);
      expect(transport.requests[0].redirectPolicy.maxRedirects, 2);
      expect(transport.requests[1].redirectPolicy.mode, AlphaXRedirectMode.manual);
      expect(transport.requests[1].redirectPolicy.maxRedirects, 0);
    });

    test('does not install an AlphaX timeout for package:http requests', () async {
      final response = await client.get(Uri.parse('https://example.test/no-timeout'));

      expect(response.statusCode, 200);
      expect(transport.requests.single.timeouts.isEmpty, isTrue);
    });

    test('rejects non-AlphaX custom methods as ClientException', () async {
      await expectLater(
        client.send(http.Request('PROPFIND', Uri.parse('https://example.test/custom'))),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('close is idempotent, borrows AlphaXClient, and blocks new sends', () async {
      client.close();
      client.close();

      await expectLater(
        client.get(Uri.parse('https://example.test/closed')),
        throwsA(isA<http.ClientException>()),
      );
      expect(alphaXClient.isClosed, isFalse);

      final directResponse = await alphaXClient.get(Uri.parse('https://example.test/direct'));
      expect(directResponse.statusCode, 200);
      expect(transport.requests, hasLength(1));
    });

    test('maps an independently closed AlphaXClient to ClientException', () async {
      await alphaXClient.close();

      await expectLater(
        client.get(Uri.parse('https://example.test/alpha-closed')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('active response streams continue after adapter close', () async {
      final source = StreamController<List<int>>();
      transport.responseFactory = (_) => AlphaXResponse(
        statusCode: 200,
        body: AlphaXResponseBody.stream(source.stream),
      );

      final response = await client.send(
        http.Request('GET', Uri.parse('https://example.test/active')),
      );
      client.close();
      final bodyFuture = response.stream.toList();
      source.add(<int>[1, 2, 3]);
      await source.close();

      expect(await bodyFuture, <List<int>>[
        <int>[1, 2, 3],
      ]);
      expect(alphaXClient.isClosed, isFalse);
    });

    test('reuses one injected AlphaXClient for concurrent requests', () async {
      final responses = await Future.wait(<Future<http.Response>>[
        client.get(Uri.parse('https://example.test/one')),
        client.get(Uri.parse('https://example.test/two')),
        client.get(Uri.parse('https://example.test/three')),
      ]);

      expect(responses.map((response) => response.statusCode), everyElement(200));
      expect(transport.requests, hasLength(3));
      expect(transport.closeCount, 0);
    });

    test('preserves middleware and underlying TLS/proxy policy', () async {
      final tlsPolicy = AlphaXTlsPolicy(
        includePlatformTrust: true,
        pins: <AlphaXSpkiPin>[],
      );
      final proxyPolicy = const AlphaXProxyPolicy.direct();
      final middleware = _HeaderMiddleware();
      final configuredTransport = _RecordingTransport(
        tlsPolicy: tlsPolicy,
        proxyPolicy: proxyPolicy,
      );
      final configuredAlpha = AlphaXClient(
        transport: configuredTransport,
        middleware: <AlphaXMiddleware>[middleware],
      );
      final configuredHttp = AlphaXHttpClient(configuredAlpha);

      final response = await configuredHttp.get(Uri.parse('https://example.test/configured'));
      expect(response.statusCode, 200);
      expect(middleware.calls, 1);
      expect(configuredTransport.requests.single.headers['x-middleware'], 'preserved');
      expect(configuredAlpha.tlsPolicy, same(tlsPolicy));
      expect(configuredAlpha.proxyPolicy, same(proxyPolicy));

      configuredHttp.close();
      await configuredAlpha.close();
    });

    test('works with the shared deterministic FakeAlphaXTransport', () async {
      final fakeTransport = FakeAlphaXTransport(
        response: AlphaXResponse(statusCode: 204),
      );
      final fakeAlpha = AlphaXClient(transport: fakeTransport);
      final fakeHttp = AlphaXHttpClient(fakeAlpha);

      final response = await fakeHttp.get(Uri.parse('https://example.test/fake'));

      expect(response.statusCode, 204);
      expect(fakeTransport.requests, hasLength(1));
      fakeHttp.close();
      await fakeAlpha.close();
    });
  });
}

final class _RecordingTransport extends AlphaXTransport {
  _RecordingTransport({
    this.tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
    this.proxyPolicy = const AlphaXProxyPolicy.system(),
  });

  FutureOr<AlphaXResponse> Function(AlphaXRequest request)? responseFactory;
  Object? error;
  final List<AlphaXRequest> requests = <AlphaXRequest>[];
  final List<List<int>> requestBodies = <List<int>>[];
  @override
  final AlphaXTlsPolicy tlsPolicy;
  @override
  final AlphaXProxyPolicy proxyPolicy;
  int closeCount = 0;
  bool _closed = false;

  @override
  final AlphaXCapabilities capabilities = const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
    streamingUpload: AlphaXSupport.supported,
    streamingDownload: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    if (_closed) {
      throw const AlphaXClientClosedException('recording transport is closed');
    }
    requests.add(request);
    final configuredError = error;
    if (configuredError != null) {
      throw configuredError;
    }
    final bytes = <int>[];
    await for (final chunk in request.body.openStream()) {
      bytes.addAll(chunk);
    }
    requestBodies.add(List<int>.unmodifiable(bytes));
    return await (responseFactory?.call(request) ?? AlphaXResponse(statusCode: 200));
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) =>
      Stream<AlphaXEvent>.error(UnsupportedError('not used by this fixture'));

  @override
  Future<void> close() async {
    closeCount++;
    _closed = true;
  }
}

final class _HeaderMiddleware extends AlphaXMiddleware {
  int calls = 0;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) {
    calls++;
    return next(request.copyWith(headers: request.headers.add('x-middleware', 'preserved')));
  }
}
