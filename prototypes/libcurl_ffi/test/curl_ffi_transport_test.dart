import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:alphax_libcurl_ffi_prototype/curl_ffi.dart';
import 'package:test/test.dart';

Uri uriFor(Uri base, String path) => base.replace(path: path);

void main() {
  final libraryPath = Platform.environment['ALPHAX_CURL_LIBRARY'];
  if (libraryPath == null || libraryPath.isEmpty) {
    test(
      'libcurl library path is required',
      () {},
      skip: 'Set ALPHAX_CURL_LIBRARY to run FFI tests',
    );
    return;
  }

  late HttpServer server;
  late CurlFfiClient transport;
  late Uri baseUri;
  late Directory tempDirectory;
  final connectionIds = <String, int>{};
  var nextConnectionId = 0;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      final connectionInfo = request.connectionInfo;
      final connectionKey = connectionInfo == null
          ? 'unknown-${identityHashCode(request)}'
          : '${connectionInfo.remoteAddress.address}:${connectionInfo.remotePort}';
      final connectionId = connectionIds.putIfAbsent(connectionKey, () => ++nextConnectionId);
      request.response.headers.set('x-test-connection-id', '$connectionId');
      switch (request.uri.path) {
        case '/stream':
          for (final chunk in <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]) {
            request.response.add(chunk);
            await request.response.flush();
          }
        case '/bounded':
          for (var offset = 0; offset < 64; offset += 8) {
            request.response.add(List<int>.generate(8, (index) => offset + index));
            await request.response.flush();
          }
        case '/delay':
          await Future<void>.delayed(const Duration(seconds: 1));
          request.response.write('delayed');
        case '/upload':
          final body = await request.fold<List<int>>(<int>[], (bytes, chunk) {
            bytes.addAll(chunk);
            return bytes;
          });
          request.response.headers.set('x-uploaded', '${body.length}');
          request.response.write('${body.length}');
        case '/post':
          final body = await request.fold<List<int>>(<int>[], (bytes, chunk) {
            bytes.addAll(chunk);
            return bytes;
          });
          request.response.add(body);
        case '/headers':
          request.response.headers
            ..set('x-test', 'ok')
            ..set('x-repeated', 'one')
            ..add('x-repeated', 'two');
          request.response.write('headers');
        case '/redirect':
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/final');
        case '/final':
          request.response.write('redirected');
        default:
          request.response.add(List<int>.generate(64, (index) => index % 251));
      }
      await request.response.close();
    });
    transport = CurlFfiClient.fromPath(libraryPath);
    tempDirectory = await Directory.systemTemp.createTemp('alphax-libcurl-test-');
  });

  tearDown(() async {
    await transport.close();
    await server.close(force: true);
    await tempDirectory.delete(recursive: true);
  });

  test('matches buffered response, POST, and headers', () async {
    final response = await transport.getBytes(uriFor(baseUri, '/headers'));
    final post = await transport.postBytes(uriFor(baseUri, '/post'), <int>[4, 5]);

    expect(response.statusCode, 200);
    expect(response.bodyBytes, 'headers'.codeUnits);
    expect(response.header('x-test'), 'ok');
    expect(response.headerValues('x-repeated'), <String>['one, two']);
    expect(post.bodyBytes, <int>[4, 5]);
  });

  test('reuses one persistent connection for sequential requests', () async {
    final ids = <String>{};
    for (var index = 0; index < 100; index++) {
      final response = await transport.getBytes(uriFor(baseUri, '/bytes/1'));
      ids.add(response.header('x-test-connection-id')!);
    }
    expect(ids.length, lessThanOrEqualTo(2));
    expect(ids.length, lessThan(100));
  });

  test('completes streaming and direct file transfers', () async {
    final events = await transport.getStreaming(uriFor(baseUri, '/stream')).toList();
    final downloadPath = '${tempDirectory.path}/download.bin';
    final uploadPath = '${tempDirectory.path}/upload.bin';
    await File(uploadPath).writeAsBytes(<int>[8, 7, 6, 5]);

    final download = await transport.downloadFile(uriFor(baseUri, '/bytes'), downloadPath);
    final upload = await transport.uploadFile(
      uriFor(baseUri, '/upload'),
      uploadPath,
    );

    expect(
      events.whereType<BenchmarkStreamChunk>().expand((event) => event.bytes),
      <int>[1, 2, 3, 4],
    );
    expect(events.whereType<BenchmarkStreamCompleted>().single.bytesTransferred, 4);
    expect(download.statusCode, 200);
    expect(await File(downloadPath).length(), 64);
    expect(download.bytesTransferred, 64);
    expect(upload.statusCode, 200);
    expect(upload.bytesTransferred, 4);
  });

  test('bounds native streaming with credit acknowledgments', () async {
    final bounded = CurlFfiClient.fromPath(
      libraryPath,
      streamChunkSize: 4,
      streamWindowChunks: 2,
    );
    addTearDown(bounded.close);
    final received = <int>[];
    Map<String, Object?> flow = const <String, Object?>{};
    await for (final event in bounded.getStreaming(uriFor(baseUri, '/bounded'))) {
      if (event case BenchmarkStreamChunk(:final bytes)) {
        received.addAll(bytes);
        await Future<void>.delayed(const Duration(milliseconds: 2));
      } else if (event case BenchmarkStreamCompleted(diagnostics: final diagnostics)) {
        flow = Map<String, Object?>.from(diagnostics['stream_flow_control']! as Map);
      }
    }
    expect(received, List<int>.generate(64, (index) => index));
    expect(flow['window_chunks'], 2);
    expect(flow['max_in_flight_chunks'], lessThanOrEqualTo(2));
    expect(flow['queue_capacity_bytes'], greaterThanOrEqualTo(8));
    expect(
      flow['max_buffered_bytes'],
      lessThanOrEqualTo(flow['queue_capacity_bytes']! as num),
    );
    expect(flow['pause_count'], greaterThan(0));
    expect(flow['ack_count'], greaterThan(0));
  });

  test('reports timeout and cancellation', () async {
    await expectLater(
      transport.getBytes(
        uriFor(baseUri, '/delay'),
        options: const BenchmarkRequestOptions(timeout: Duration(milliseconds: 20)),
      ),
      throwsA(isA<BenchmarkTimeoutException>()),
    );

    final cancellation = BenchmarkCancellationToken();
    final request = transport.getBytes(
      uriFor(baseUri, '/delay'),
      options: BenchmarkRequestOptions(cancellation: cancellation),
    );
    cancellation.cancel();
    await expectLater(request, throwsA(isA<BenchmarkCancelledException>()));
  });

  test('follows redirects', () async {
    final response = await transport.getBytes(uriFor(baseUri, '/redirect'));

    expect(response.statusCode, 200);
    expect(response.bodyBytes, 'redirected'.codeUnits);
  });
}
