import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:alphax_rust_http_ffi_prototype/rust_ffi.dart';
import 'package:test/test.dart';

Uri uriFor(Uri base, String path) => base.replace(path: path);

void main() {
  final libraryPath = Platform.environment['ALPHAX_RUST_LIBRARY'];
  if (libraryPath == null || libraryPath.isEmpty) {
    test('Rust library path is required', () {}, skip: 'Set ALPHAX_RUST_LIBRARY to run FFI tests');
    return;
  }

  late HttpServer server;
  late RustFfiClient transport;
  late Uri baseUri;
  late Directory tempDirectory;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      switch (request.uri.path) {
        case '/stream':
          for (final chunk in <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]) {
            request.response.add(chunk);
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
        default:
          request.response.add(List<int>.generate(64, (index) => index % 251));
      }
      await request.response.close();
    });
    transport = RustFfiClient.fromPath(libraryPath);
    tempDirectory = await Directory.systemTemp.createTemp('alphax-rust-test-');
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

  test('completes streaming and direct file transfers', () async {
    final events = await transport.getStreaming(uriFor(baseUri, '/stream')).toList();
    final downloadPath = '${tempDirectory.path}/download.bin';
    final uploadPath = '${tempDirectory.path}/upload.bin';
    await File(uploadPath).writeAsBytes(<int>[8, 7, 6, 5]);

    final download = await transport.downloadFile(uriFor(baseUri, '/bytes'), downloadPath);
    final upload = await transport.uploadFile(uriFor(baseUri, '/upload'), uploadPath);

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
}
