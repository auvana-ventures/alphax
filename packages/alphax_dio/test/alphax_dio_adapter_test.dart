import 'dart:async';
import 'dart:typed_data';

import 'package:alphax/alphax.dart';
import 'package:alphax_dio/alphax_dio.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test('maps Dio requests and AlphaX response metadata', () async {
    late AlphaXRequest receivedRequest;
    final transport = FakeAlphaXTransport(
      responseBuilder: (request) {
        receivedRequest = request;
        return AlphaXResponse(
          statusCode: 201,
          headers: AlphaXHeaders(<String, String>{
            'content-type': 'application/octet-stream',
            'content-length': '2',
          }),
          bodyBytes: <int>[7, 8],
          protocol: AlphaXProtocol.http2,
          metrics: const AlphaXRequestMetrics(
            protocol: AlphaXProtocol.http2,
            downloadedBytes: 2,
          ),
        );
      },
    );
    final dio = _createDio(transport);

    final response = await dio.postUri<List<int>>(
      Uri.parse('https://example.test/resource?query=1'),
      data: Uint8List.fromList(<int>[1, 2, 3]),
      options: Options(
        responseType: ResponseType.bytes,
        headers: <String, dynamic>{
          'X-Trace': <String>['one', 'two'],
        },
        connectTimeout: const Duration(seconds: 1),
        sendTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 3),
        extra: <String, dynamic>{
          AlphaXDioAdapter.protocolRequirementExtraKey: AlphaXProtocolRequirement.http2,
        },
      ),
    );

    expect(response.statusCode, 201);
    expect(response.data, <int>[7, 8]);
    expect(receivedRequest.method, HttpMethod.post);
    expect(receivedRequest.uri.queryParameters['query'], '1');
    expect(receivedRequest.headers.values('x-trace'), <String>['one', 'two']);
    expect(
      await receivedRequest.body.openStream().fold<List<int>>(<int>[], (all, chunk) {
        return <int>[...all, ...chunk];
      }),
      <int>[1, 2, 3],
    );
    expect(receivedRequest.protocolPreference, AlphaXProtocolPreference.http2);
    expect(receivedRequest.protocolRequirement, AlphaXProtocolRequirement.http2);
    expect(receivedRequest.timeouts.connect, const Duration(seconds: 1));
    expect(receivedRequest.timeouts.request, const Duration(seconds: 2));
    expect(receivedRequest.timeouts.read, const Duration(seconds: 3));
    expect(
      response.extra[HttpClientAdapter.extraKeyHttpVersion],
      '2.0',
    );
    expect(
      response.extra[AlphaXDioAdapter.protocolExtraKey],
      AlphaXProtocol.http2,
    );
    expect(
      response.extra[AlphaXDioAdapter.metricsExtraKey],
      isA<AlphaXRequestMetrics>(),
    );
  });

  test('preserves streaming response semantics and completion metadata', () async {
    final completion = Completer<AlphaXRequestMetrics>();
    final transport = FakeAlphaXTransport(
      response: AlphaXResponse(
        statusCode: 200,
        headers: AlphaXHeaders(<String, String>{
          'content-length': '4',
        }),
        body: AlphaXResponseBody.stream(
          Stream<List<int>>.fromIterable(const <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]),
          contentLength: 4,
        ),
        metrics: const AlphaXRequestMetrics(),
        completionMetrics: completion.future,
      ),
    );
    final dio = _createDio(transport);

    final response = await dio.getUri<ResponseBody>(
      Uri.parse('https://example.test/stream'),
      options: Options(responseType: ResponseType.stream),
    );
    final body = response.data!;
    expect(await body.stream.expand((chunk) => chunk).toList(), <int>[1, 2, 3, 4]);

    completion.complete(
      const AlphaXRequestMetrics(
        protocol: AlphaXProtocol.http3,
        downloadedBytes: 4,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      response.extra[HttpClientAdapter.extraKeyHttpVersion],
      '3.0',
    );
    expect(
      response.extra[AlphaXDioAdapter.protocolExtraKey],
      AlphaXProtocol.http3,
    );
  });

  test('maps cancellation to Dio cancellation and cancels AlphaX work', () async {
    final transport = FakeAlphaXTransport(
      delay: const Duration(seconds: 5),
    );
    final dio = _createDio(transport);
    final cancelToken = CancelToken();

    final pending = dio.get<void>(
      'https://example.test/cancel',
      cancelToken: cancelToken,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    cancelToken.cancel('screen closed');

    await expectLater(
      pending,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test('maps normalized AlphaX connection and timeout errors', () async {
    final connectionDio = _createDio(
      FakeAlphaXTransport(
        error: const AlphaXConnectionException('connection unavailable'),
      ),
    );
    await expectLater(
      connectionDio.get<void>('https://example.test/error'),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );

    final timeoutDio = _createDio(
      FakeAlphaXTransport(
        error: const AlphaXTimeoutException(
          'request timed out',
          timeoutKind: AlphaXTimeoutKind.request,
        ),
      ),
    );
    await expectLater(
      timeoutDio.get<void>('https://example.test/timeout'),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.sendTimeout,
        ),
      ),
    );
  });

  test('maps redirect metadata without claiming a redirect status', () async {
    final transport = FakeAlphaXTransport(
      response: AlphaXResponse(
        statusCode: 200,
        bodyBytes: <int>[1],
        redirects: <AlphaXRedirectInfo>[
          AlphaXRedirectInfo(
            statusCode: 302,
            from: Uri.parse('https://example.test/from'),
            to: Uri.parse('https://example.test/to'),
            method: 'GET',
          ),
        ],
      ),
    );
    final dio = _createDio(transport);

    final response = await dio.get<List<int>>(
      'https://example.test/from',
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );

    expect(response.isRedirect, isTrue);
    expect(response.redirects, hasLength(1));
    expect(response.redirects.single.statusCode, 302);
    expect(response.redirects.single.location.toString(), 'https://example.test/to');
  });

  test('does not duplicate Dio progress callbacks', () async {
    final transport = FakeAlphaXTransport(
      responseBuilder: (request) async {
        await request.body.openStream().drain<void>();
        return AlphaXResponse(
          statusCode: 200,
          headers: AlphaXHeaders(<String, String>{'content-length': '3'}),
          bodyBytes: <int>[4, 5, 6],
        );
      },
    );
    final dio = _createDio(transport);
    final sent = <List<int>>[];
    final received = <List<int>>[];

    await dio.post<List<int>>(
      'https://example.test/progress',
      data: Uint8List.fromList(<int>[1, 2, 3]),
      options: Options(
        responseType: ResponseType.bytes,
      ),
      onSendProgress: (count, total) => sent.add(<int>[count, total]),
      onReceiveProgress: (count, total) => received.add(<int>[count, total]),
    );

    expect(sent, <List<int>>[
      <int>[3, 3],
    ]);
    expect(received, <List<int>>[
      <int>[3, 3],
    ]);
  });
}

Dio _createDio(FakeAlphaXTransport transport) {
  final client = AlphaXClient(transport: transport);
  final dio = Dio()
    ..httpClientAdapter = AlphaXDioAdapter(
      client,
      closeClient: true,
    );
  addTearDown(() => dio.close(force: true));
  return dio;
}
