import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax_native/alphax_native.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late DartIoTransport transport;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) => unawaited(_handle(request)));
    transport = DartIoTransport();
  });

  tearDown(() async {
    await transport.close();
    await server.close(force: true);
  });

  defineAlphaXTransportConformanceTests(
    'DartIoTransport',
    DartIoTransport.new,
    baseUriProvider: () => baseUri,
  );

  test('reports only the capabilities Dart IO can provide honestly', () {
    expect(transport.capabilities.http11, AlphaXSupport.supported);
    expect(transport.capabilities.http2, AlphaXSupport.unsupported);
    expect(transport.capabilities.http3, AlphaXSupport.unsupported);
    expect(
      transport.capabilities.negotiatedProtocolReporting,
      AlphaXSupport.unsupported,
    );
    expect(transport.capabilities.nativeFileUpload, AlphaXSupport.unsupported);
    expect(transport.capabilities.nativeFileDownload, AlphaXSupport.unsupported);
  });

  test('normalizes invalid custom trust anchors', () {
    expect(
      () => DartIoTransport(
        tlsPolicy: AlphaXTlsPolicy(
          trustAnchors: <AlphaXTrustAnchor>[
            AlphaXTrustAnchor.der(<int>[1, 2, 3]),
          ],
        ),
      ),
      throwsA(isA<AlphaXUnsupportedTlsPolicyException>()),
    );
  });

  test('supports every required HTTP method without changing the body', () async {
    final cases = <HttpMethod, List<int>>{
      HttpMethod.get: const <int>[],
      HttpMethod.post: <int>[1, 2, 3],
      HttpMethod.put: <int>[4, 5],
      HttpMethod.patch: <int>[6],
      HttpMethod.delete: <int>[7, 8],
      HttpMethod.head: const <int>[],
      HttpMethod.options: <int>[9, 10],
    };

    for (final entry in cases.entries) {
      final response = await transport.send(
        AlphaXRequest(
          method: entry.key,
          uri: baseUri.resolve('/method'),
          body: entry.value.isEmpty ? const AlphaXEmptyBody() : AlphaXBody.bytes(entry.value),
        ),
      );
      final body = await response.readAsBytes();
      if (entry.key == HttpMethod.head) {
        expect(body, isEmpty);
      } else {
        expect(utf8.decode(body), '${entry.key.value}:${entry.value.join(',')}');
      }
    }
  });

  test('streams response chunks progressively and supports delayed consumers', () async {
    final events = transport.sendStreaming(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/stream/4/32?delay_ms=10'),
      ),
    );
    final chunks = <List<int>>[];
    await for (final event in events) {
      if (event case AlphaXResponseChunk(:final bytes)) {
        chunks.add(bytes);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
    expect(chunks, hasLength(4));
    expect(chunks.expand((chunk) => chunk), hasLength(128));
  });

  test('supports request body forms without buffering stream and multipart bodies', () async {
    final textResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.post,
        uri: baseUri.resolve('/echo'),
        body: AlphaXBody.text('hello'),
      ),
    );
    expect(await textResponse.readAsString(), 'hello');

    final jsonResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.post,
        uri: baseUri.resolve('/echo'),
        body: AlphaXBody.json(<String, Object>{'ok': true}),
      ),
    );
    expect(await jsonResponse.readAsJson(), <String, Object>{'ok': true});

    final streamBody = AlphaXStreamBody(
      Stream<List<int>>.fromIterable(const <List<int>>[
        <int>[1, 2],
        <int>[3, 4],
      ]),
      contentLength: 4,
    );
    final streamResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.post,
        uri: baseUri.resolve('/echo'),
        body: streamBody,
      ),
    );
    expect(await streamResponse.readAsBytes(), <int>[1, 2, 3, 4]);

    final multipartResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.post,
        uri: baseUri.resolve('/multipart'),
        body: AlphaXMultipartBody(<AlphaXMultipartPart>[
          AlphaXMultipartField('message', 'hello'),
          AlphaXMultipartFile('data', _MemoryFileSource(const <int>[8, 9]), filename: 'a.bin'),
        ]),
      ),
    );
    final multipartBody = utf8.decode(await multipartResponse.readAsBytes());
    expect(multipartResponse.headers['content-type'], contains('multipart/form-data'));
    expect(multipartBody, contains('name="message"'));
    expect(multipartBody, contains('name="data"'));
    expect(multipartBody, contains('hello'));
  });

  test('reports upload and download progress with exact byte counts', () async {
    final uploadProgress = <AlphaXProgress>[];
    final payload = List<int>.generate(4096, (index) => index % 251);
    final uploadResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.post,
        uri: baseUri.resolve('/upload'),
        body: AlphaXBody.bytes(payload),
        onUploadProgress: uploadProgress.add,
      ),
    );
    expect(await uploadResponse.readAsJson(), <String, Object>{
      'bytes': payload.length,
      'hash': _fnv1a64(payload),
    });
    expect(
      _isNonDecreasing(uploadProgress.map((value) => value.bytesTransferred)),
      isTrue,
    );
    expect(uploadProgress.last.bytesTransferred, payload.length);
    expect(uploadProgress.last.totalBytes, payload.length);
    expect(uploadProgress.last.isComplete, isTrue);

    final downloadProgress = <AlphaXProgress>[];
    final downloadResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/bytes/${payload.length}'),
        onDownloadProgress: downloadProgress.add,
      ),
    );
    expect(await downloadResponse.readAsBytes(), hasLength(payload.length));
    expect(
      _isNonDecreasing(downloadProgress.map((value) => value.bytesTransferred)),
      isTrue,
    );
    expect(downloadProgress.last.bytesTransferred, payload.length);
    expect(downloadProgress.last.isComplete, isTrue);

    final unknownTotalProgress = <AlphaXProgress>[];
    final unknownTotalResponse = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/stream/2/8'),
        onDownloadProgress: unknownTotalProgress.add,
      ),
    );
    expect(await unknownTotalResponse.readAsBytes(), hasLength(16));
    expect(unknownTotalProgress, isNotEmpty);
    expect(
      unknownTotalProgress.every((value) => value.totalBytes == null),
      isTrue,
    );
    expect(unknownTotalProgress.last.bytesTransferred, 16);
  });

  test('preserves request headers and exposes honest response metrics', () async {
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/headers'),
        headers: AlphaXHeaders.fromEntries(<MapEntry<String, String>>[
          const MapEntry<String, String>('X-Trace', 'trace-1'),
        ]),
      ),
    );
    expect(response.headers['x-echo-trace'], 'trace-1');
    expect(response.protocol, AlphaXProtocol.unknown);
    expect(response.requestedProtocol, AlphaXProtocolPreference.auto);
    expect(response.metrics.timeToFirstByte, isNotNull);
    await response.readAsBytes();
    expect(
      (await response.completionMetrics).negotiatedProtocol,
      AlphaXProtocol.unknown,
    );
  });

  test('follows, returns, and rejects redirects according to policy', () async {
    final followed = await transport.send(
      AlphaXRequest(method: HttpMethod.get, uri: baseUri.resolve('/redirect/2')),
    );
    expect(await followed.readAsString(), 'redirect complete');
    expect(followed.redirects, hasLength(2));

    final manual = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/redirect/1'),
        redirectPolicy: const AlphaXRedirectPolicy(mode: AlphaXRedirectMode.manual),
      ),
    );
    expect(manual.statusCode, HttpStatus.found);
    await manual.readAsBytes();

    await expectLater(
      transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: baseUri.resolve('/redirect/1'),
          redirectPolicy: const AlphaXRedirectPolicy(mode: AlphaXRedirectMode.reject),
        ),
      ),
      throwsA(isA<AlphaXRedirectException>()),
    );
  });

  test('normalizes redirect limits as redirect errors', () async {
    await expectLater(
      transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: baseUri.resolve('/redirect/2'),
          redirectPolicy: const AlphaXRedirectPolicy(maxRedirects: 1),
        ),
      ),
      throwsA(isA<AlphaXRedirectException>()),
    );
  });

  test('does not replay a single-use request body across a redirect', () async {
    final body = AlphaXStreamBody(Stream<List<int>>.value(<int>[1, 2, 3]));
    await expectLater(
      transport.send(
        AlphaXRequest(
          method: HttpMethod.post,
          uri: baseUri.resolve('/redirect/1'),
          body: body,
        ),
      ),
      throwsA(isA<AlphaXRedirectException>()),
    );
  });

  test('rejects cross-origin redirects carrying sensitive credentials', () async {
    var targetWasReached = false;
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => target.close(force: true));
    target.listen((request) {
      targetWasReached = true;
      _writeText(request.response, 'unexpected target request');
    });

    for (final header in const <String>[
      'Authorization',
      'Proxy-Authorization',
      'Cookie',
    ]) {
      await expectLater(
        transport.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: baseUri.resolve('/redirect-to-port/${target.port}'),
            headers: AlphaXHeaders(<String, String>{header: 'sensitive-test-value'}),
          ),
        ),
        throwsA(isA<AlphaXRedirectException>()),
      );
    }
    expect(targetWasReached, isFalse);
  });

  test('normalizes request, read, and overall timeouts', () async {
    await expectLater(
      transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: baseUri.resolve('/delay/200'),
          timeout: const AlphaXTimeouts(request: Duration(milliseconds: 20)),
        ),
      ),
      throwsA(
        isA<AlphaXTimeoutException>().having(
          (error) => error.timeoutKind,
          'timeout kind',
          AlphaXTimeoutKind.request,
        ),
      ),
    );

    final readTimeout = transport.sendStreaming(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/stream/2/8?delay_ms=200'),
        timeout: const AlphaXTimeouts(read: Duration(milliseconds: 20)),
      ),
    );
    await expectLater(
      readTimeout.toList(),
      throwsA(
        isA<AlphaXTimeoutException>().having(
          (error) => error.timeoutKind,
          'timeout kind',
          AlphaXTimeoutKind.read,
        ),
      ),
    );

    final overallTimeout = transport.sendStreaming(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/stream/3/8?delay_ms=100'),
        timeout: const AlphaXTimeouts(overall: Duration(milliseconds: 40)),
      ),
    );
    await expectLater(
      overallTimeout.toList(),
      throwsA(
        isA<AlphaXTimeoutException>().having(
          (error) => error.timeoutKind,
          'timeout kind',
          AlphaXTimeoutKind.overall,
        ),
      ),
    );
  });

  test('cancellation is distinct and releases a streaming request', () async {
    final token = AlphaXCancellationToken();
    final future = transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/delay/500'),
        cancellationToken: token,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    token.cancel('test cancellation');
    await expectLater(future, throwsA(isA<AlphaXCancellationException>()));

    final streamToken = AlphaXCancellationToken();
    final stream = transport.sendStreaming(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/stream/10/8?delay_ms=20'),
        cancellationToken: streamToken,
      ),
    );
    final subscription = stream.listen((event) {
      if (event is AlphaXResponseChunk) {
        streamToken.cancel('stream stopped');
      }
    });
    await expectLater(subscription.asFuture<void>(), throwsA(isA<AlphaXCancellationException>()));
  });

  test('client close aborts active streaming work and rejects new requests', () async {
    final started = Completer<void>();
    final stream = transport.sendStreaming(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/stream/10/8?delay_ms=50'),
      ),
    );
    final subscription = stream.listen((event) {
      if (event is AlphaXResponseStarted && !started.isCompleted) {
        started.complete();
      }
    });
    await started.future;

    final closing = transport.close();
    await expectLater(
      subscription.asFuture<void>(),
      throwsA(isA<AlphaXClientClosedException>()),
    );
    await closing;
    await expectLater(
      transport.send(AlphaXRequest(method: HttpMethod.get, uri: baseUri.resolve('/resource'))),
      throwsA(isA<AlphaXClientClosedException>()),
    );
  });

  test('normalizes request stream failures and preserves repeated headers', () async {
    final response = await transport.send(
      AlphaXRequest(method: HttpMethod.get, uri: baseUri.resolve('/headers')),
    );
    expect(response.headers['x-many'], 'one, two');
    expect(
      response.headers.values(HttpHeaders.setCookieHeader),
      <String>['a=1', 'b=2'],
    );
    await response.readAsBytes();

    final failingBody = AlphaXStreamBody(
      Stream<List<int>>.error(StateError('body failed')),
    );
    await expectLater(
      transport.send(
        AlphaXRequest(method: HttpMethod.post, uri: baseUri.resolve('/echo'), body: failingBody),
      ),
      throwsA(isA<AlphaXRequestBodyException>()),
    );
  });

  test('runs middleware around the real transport without changing body ownership', () async {
    final client = AlphaXClient(
      transport: transport,
      middleware: <AlphaXMiddleware>[_TraceMiddleware()],
    );
    final response = await client.get(baseUri.resolve('/headers'));
    expect(response.headers['x-echo-trace'], 'middleware');
    await response.readAsBytes();
    await client.close();
  });

  test('supports file upload and download through Dart streams', () async {
    final directory = await Directory.systemTemp.createTemp('alphax-dart-io-test-');
    addTearDown(() => directory.delete(recursive: true));
    final sourceFile = File('${directory.path}/source.bin');
    final targetFile = File('${directory.path}/target.bin');
    final bytes = List<int>.generate(8192, (index) => (index * 7) % 251);
    await sourceFile.writeAsBytes(bytes);

    final upload = await transport.upload(
      AlphaXRequest(method: HttpMethod.post, uri: baseUri.resolve('/upload')),
      _IoFileSource(sourceFile),
    );
    expect(upload.bytesTransferred, bytes.length);
    expect(upload.headers['x-upload-hash'], _fnv1a64(bytes));

    final download = await transport.download(
      AlphaXRequest(method: HttpMethod.get, uri: baseUri.resolve('/bytes/${bytes.length}')),
      _IoFileTarget(targetFile),
    );
    expect(download.bytesTransferred, bytes.length);
    expect(
      await targetFile.readAsBytes(),
      List<int>.generate(bytes.length, (index) => index % 251),
    );
  });

  test('protocol preference permits an honest Dart IO fallback', () async {
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: baseUri.resolve('/resource'),
        protocolPreference: AlphaXProtocolPreference.http3,
      ),
    );

    expect(response.requestedProtocol, AlphaXProtocolPreference.http3);
    expect(response.protocol, AlphaXProtocol.unknown);
    await response.readAsBytes();
    // Completion metadata is deliberately allowed to remain pending until a
    // streamed body reaches a terminal state.
    expect(await response.completionProtocolFallback, isNull);
  });

  test('protocol requirement fails closed when Dart IO cannot report H1', () async {
    await expectLater(
      transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: baseUri.resolve('/resource'),
          protocolRequirement: AlphaXProtocolRequirement.http11,
        ),
      ),
      throwsA(
        isA<AlphaXProtocolRequirementException>().having(
          (error) => error.actualProtocol,
          'actualProtocol',
          AlphaXProtocol.unknown,
        ),
      ),
    );
  });

  test('reuses the HttpClient connection for sequential requests', () async {
    final first = await transport.send(
      AlphaXRequest(method: HttpMethod.get, uri: baseUri.resolve('/connection')),
    );
    final firstPort = first.headers['x-client-port'];
    await first.readAsBytes();

    final second = await transport.send(
      AlphaXRequest(method: HttpMethod.get, uri: baseUri.resolve('/connection')),
    );
    final secondPort = second.headers['x-client-port'];
    await second.readAsBytes();

    expect(firstPort, isNotNull);
    expect(secondPort, firstPort);
  });

  test('does not trust a locally generated self-signed certificate', () async {
    final directory = await Directory.systemTemp.createTemp('alphax-dart-io-tls-');
    addTearDown(() => directory.delete(recursive: true));
    final certificate = File('${directory.path}/server.crt');
    final privateKey = File('${directory.path}/server.key');
    final result = await Process.run('openssl', <String>[
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      privateKey.path,
      '-out',
      certificate.path,
      '-subj',
      '/CN=127.0.0.1',
      '-days',
      '1',
    ]);
    if (result.exitCode != 0) {
      fail('openssl certificate generation failed: ${result.stderr}');
    }
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(certificate.path)
      ..usePrivateKey(privateKey.path)
      ..setAlpnProtocols(<String>['http/1.1'], true);
    final secureServer = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    addTearDown(() => secureServer.close(force: true));
    secureServer.listen((request) {
      request.response
        ..headers.contentLength = 2
        ..add(<int>[1, 2]);
      unawaited(request.response.close());
    });

    await expectLater(
      transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://127.0.0.1:${secureServer.port}/resource'),
        ),
      ),
      throwsA(isA<AlphaXTlsException>()),
    );
  });
}

Future<void> _handle(HttpRequest request) async {
  final response = request.response;
  try {
    final segments = request.uri.pathSegments;
    if (segments.firstOrNull == 'delay') {
      await Future<void>.delayed(Duration(milliseconds: int.parse(segments[1])));
      _writeText(response, 'delayed');
    } else if (segments.firstOrNull == 'bytes') {
      final size = int.parse(segments[1]);
      response.contentLength = size;
      for (var offset = 0; offset < size; offset += 64) {
        final length = (size - offset).clamp(0, 64);
        response.add(List<int>.generate(length, (index) => (index + offset) % 251));
        await response.flush();
      }
    } else if (segments.firstOrNull == 'stream') {
      final chunks = int.parse(segments[1]);
      final size = int.parse(segments[2]);
      final delay = int.parse(request.uri.queryParameters['delay_ms'] ?? '0');
      for (var index = 0; index < chunks; index++) {
        response.add(List<int>.filled(size, index));
        await response.flush();
        if (delay > 0) {
          await Future<void>.delayed(Duration(milliseconds: delay));
        }
      }
    } else if (segments.firstOrNull == 'method') {
      final body = await request.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });
      if (request.method == 'HEAD') {
        response.contentLength = 0;
      } else {
        _writeText(response, '${request.method}:${body.join(',')}');
      }
    } else if (segments.firstOrNull == 'echo') {
      final body = await request.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });
      response
        ..contentLength = body.length
        ..add(body);
    } else if (segments.firstOrNull == 'multipart') {
      final body = await request.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });
      response
        ..headers.contentType = ContentType('multipart', 'form-data')
        ..headers.set('content-type', request.headers.contentType?.toString() ?? '')
        ..contentLength = body.length
        ..add(body);
    } else if (segments.firstOrNull == 'upload') {
      final body = await request.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });
      response.headers.set('x-upload-hash', _fnv1a64(body));
      _writeJson(response, <String, Object>{
        'bytes': body.length,
        'hash': _fnv1a64(body),
      });
    } else if (segments.firstOrNull == 'redirect') {
      final count = int.parse(segments[1]);
      if (count == 0) {
        _writeText(response, 'redirect complete');
      } else {
        response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/redirect/${count - 1}');
      }
    } else if (segments.firstOrNull == 'redirect-to-port') {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: int.parse(segments[1]),
            path: '/capture',
          ).toString(),
        );
    } else if (segments.firstOrNull == 'capture') {
      _writeText(response, 'capture');
    } else if (segments.firstOrNull == 'connection') {
      final port = request.connectionInfo?.remotePort;
      response
        ..headers.set('x-client-port', '$port')
        ..contentLength = 0;
    } else if (segments.firstOrNull == 'headers') {
      response.headers
        ..add('x-many', 'one')
        ..add('x-many', 'two')
        ..add(HttpHeaders.setCookieHeader, 'a=1')
        ..add(HttpHeaders.setCookieHeader, 'b=2');
      final trace = request.headers.value('x-trace');
      if (trace != null) {
        response.headers.set('x-echo-trace', trace);
      }
      _writeText(response, 'headers');
    } else {
      _writeText(response, 'resource');
    }
  } on HttpException {
    return;
  } finally {
    await response.close();
  }
}

void _writeText(HttpResponse response, String value) {
  final bytes = utf8.encode(value);
  response
    ..headers.contentType = ContentType.text
    ..contentLength = bytes.length
    ..add(bytes);
}

void _writeJson(HttpResponse response, Map<String, Object> value) {
  final bytes = utf8.encode(jsonEncode(value));
  response
    ..headers.contentType = ContentType.json
    ..contentLength = bytes.length
    ..add(bytes);
}

String _fnv1a64(Iterable<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

bool _isNonDecreasing(Iterable<int> values) {
  var previous = 0;
  for (final value in values) {
    if (value < previous) return false;
    previous = value;
  }
  return true;
}

final class _MemoryFileSource implements AlphaXFileSource {
  const _MemoryFileSource(this.bytes);

  final List<int> bytes;

  @override
  String? get name => 'memory';

  @override
  int get length => bytes.length;

  @override
  bool get isReplayable => true;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(bytes);
}

final class _TraceMiddleware extends AlphaXMiddleware {
  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    final response = await next(
      request.copyWith(
        headers: request.headers.set('x-trace', 'middleware'),
      ),
    );
    return response;
  }
}

final class _IoFileSource implements AlphaXFileSource {
  const _IoFileSource(this.file);

  final File file;

  @override
  String get name => file.path;

  @override
  int? get length => file.lengthSync();

  @override
  bool get isReplayable => true;

  @override
  Stream<List<int>> openRead() => file.openRead();
}

final class _IoFileTarget implements AlphaXFileTarget {
  const _IoFileTarget(this.file);

  final File file;

  @override
  String get name => file.path;

  @override
  Future<AlphaXFileSink> openWrite() async => _IoFileSink(file.openWrite());
}

final class _IoFileSink implements AlphaXFileSink {
  _IoFileSink(this._sink);

  final IOSink _sink;

  @override
  void add(List<int> bytes) => _sink.add(bytes);

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() => _sink.close();

  @override
  Future<void> abort() => _sink.close();
}
