import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

final _ConnectionTracker _defaultConnectionTracker = _ConnectionTracker();

/// A deterministic HTTP server used only by the Phase 0 benchmark harness.
final class BenchmarkServer {
  /// Creates a server bound to [host] and [port]. Port zero selects an ephemeral port.
  BenchmarkServer({
    InternetAddress? host,
    this.port = 0,
    this.certificatePath,
    this.privateKeyPath,
  }) : host = host ?? InternetAddress.loopbackIPv4,
       _connectionTracker = _ConnectionTracker() {
    if ((certificatePath == null) != (privateKeyPath == null)) {
      throw ArgumentError('certificatePath and privateKeyPath must be provided together');
    }
  }

  /// Address to bind.
  final InternetAddress host;

  /// Port to bind, or zero for an ephemeral port.
  final int port;

  /// PEM certificate chain used for the optional local TLS profile.
  final String? certificatePath;

  /// PEM private key used for the optional local TLS profile.
  final String? privateKeyPath;

  /// Whether this server uses TLS.
  bool get isSecure => certificatePath != null;
  final _ConnectionTracker _connectionTracker;

  HttpServer? _server;
  Completer<void>? _done;

  /// Whether the server is listening.
  bool get isRunning => _server != null;

  /// Base URI after [start] has completed.
  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('benchmark server is not running');
    }
    final address = server.address.address.contains(':')
        ? '[${server.address.address}]'
        : server.address.address;
    return Uri(scheme: isSecure ? 'https' : 'http', host: address, port: server.port);
  }

  /// Completes after [close] has stopped the server.
  Future<void> get done => (_done ??= Completer<void>()).future;

  /// Starts listening.
  Future<void> start() async {
    if (_server != null) {
      return;
    }
    // Keep the accept queue large enough for the highest initial concurrency
    // profile without changing request handling or payload generation.
    final certificate = certificatePath;
    final privateKey = privateKeyPath;
    final server = certificate == null || privateKey == null
        ? await HttpServer.bind(host, port, backlog: 1024)
        : await _bindSecure(host, port, certificate, privateKey);
    _server = server;
    _done ??= Completer<void>();
    unawaited(_serve(server));
  }

  Future<HttpServer> _bindSecure(
    InternetAddress address,
    int bindPort,
    String certificate,
    String privateKey,
  ) async {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(certificate)
      ..usePrivateKey(privateKey)
      // The Dart benchmark server intentionally implements HTTP/1.1 only.
      // Do not advertise h2 until a real HTTP/2 server is in the harness.
      ..setAlpnProtocols(<String>['http/1.1'], true);
    return HttpServer.bindSecure(address, bindPort, context, backlog: 1024);
  }

  /// Stops listening and closes active responses.
  Future<void> close() async {
    final server = _server;
    if (server == null) {
      return;
    }
    _server = null;
    await server.close(force: true);
    final done = _done;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleBenchmarkRequest(request, _connectionTracker));
    }
  }
}

/// Handles one request using the deterministic benchmark contract.
Future<void> handleBenchmarkRequest(HttpRequest request) =>
    _handleBenchmarkRequest(request, _defaultConnectionTracker);

Future<void> _handleBenchmarkRequest(
  HttpRequest request,
  _ConnectionTracker tracker,
) async {
  final response = request.response;
  final connection = tracker.observe(request);
  response.headers
    ..set('x-alphax-server-connection-id', '${connection.id}')
    ..set('x-alphax-server-connection-request-count', '${connection.requestCount}')
    ..set('x-alphax-server-connections-established', '${connection.connectionsEstablished}')
    ..set('x-alphax-server-requests-observed', '${connection.requestsObserved}')
    ..set('x-alphax-server-protocol', request.protocolVersion)
    ..set('x-alphax-server-connection-close-events', 'unavailable:dart-http-server-api');
  try {
    final segments = request.uri.pathSegments;
    if (segments.isEmpty || segments.first.isEmpty) {
      _writeText(response, 'AlphaX benchmark server');
      return;
    }

    switch (segments.first) {
      case 'bytes':
        await _writeBytes(response, _positiveInt(segments, 1, 'size'));
      case 'json':
        await _writeJson(response, _positiveInt(segments, 1, 'size'));
      case 'stream':
        await _writeStream(
          response,
          chunks: _positiveInt(segments, 1, 'chunks'),
          chunkSize: _positiveInt(segments, 2, 'chunkSize'),
          delay: _durationFromQuery(request.uri.queryParameters['delay_ms']),
        );
      case 'echo':
        await _echo(request, response);
      case 'upload':
        await _countUpload(request, response);
      case 'health':
        _writeJsonBody(response, <String, Object>{'status': 'ok'});
      case 'connections':
        _writeJsonBody(response, tracker.snapshot());
      case 'delay':
        await Future<void>.delayed(_durationFromPath(segments, 1, 'milliseconds'));
        _writeText(response, 'delayed');
      case 'status':
        response.statusCode = _positiveInt(segments, 1, 'status');
        _writeText(response, 'status ${response.statusCode}');
      case 'headers':
        response.headers
          ..set('x-alphax-server', 'benchmark')
          ..set('x-alphax-request-method', request.method);
        final trace = request.headers.value('x-trace');
        if (trace != null) {
          response.headers.set('x-alphax-echo-trace', trace);
        }
        _writeText(response, 'headers');
      case 'redirect':
        _redirect(response, _positiveInt(segments, 1, 'count'));
      default:
        response.statusCode = HttpStatus.notFound;
        _writeText(response, 'not found');
    }
  } on HttpException {
    // Client cancellation during an upload/download closes the request socket;
    // that is an expected benchmark outcome, not a server failure.
    return;
  } on FormatException catch (error) {
    response.statusCode = HttpStatus.badRequest;
    _writeText(response, error.message);
  } catch (error, stackTrace) {
    stderr.writeln('benchmark server error: $error\n$stackTrace');
    response.statusCode = HttpStatus.internalServerError;
    _writeText(response, 'internal server error');
  } finally {
    await response.close();
  }
}

Future<void> _writeBytes(HttpResponse response, int size) async {
  response
    ..headers.contentType = ContentType.binary
    ..contentLength = size;
  const chunkSize = 64 * 1024;
  var offset = 0;
  while (offset < size) {
    final length = math.min(chunkSize, size - offset);
    response.add(deterministicBytes(length, offset));
    // Keep large deterministic responses bounded in the server process. This
    // endpoint is used by direct-file and buffered candidates as well as
    // streaming candidates, so it must not accumulate the whole payload in
    // the Dart HTTP response sink.
    await response.flush();
    offset += length;
  }
}

Future<void> _writeJson(HttpResponse response, int size) async {
  final payloadLength = math.max(0, size - 16);
  final payload = List<String>.filled(payloadLength, 'a').join();
  _writeJsonBody(response, <String, Object>{'payload': payload});
}

void _writeJsonBody(HttpResponse response, Map<String, Object> value) {
  final body = utf8.encode(jsonEncode(value));
  response
    ..headers.contentType = ContentType.json
    ..contentLength = body.length
    ..add(body);
}

Future<void> _writeStream(
  HttpResponse response, {
  required int chunks,
  required int chunkSize,
  required Duration delay,
}) async {
  response.headers.contentType = ContentType.binary;
  for (var index = 0; index < chunks; index++) {
    response.add(deterministicBytes(chunkSize, index));
    await response.flush();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}

Future<void> _echo(HttpRequest request, HttpResponse response) async {
  final bytes = await request.fold<List<int>>(<int>[], (buffer, chunk) {
    buffer.addAll(chunk);
    return buffer;
  });
  response
    ..headers.contentType = ContentType.binary
    ..contentLength = bytes.length
    ..add(bytes);
}

Future<void> _countUpload(HttpRequest request, HttpResponse response) async {
  var bytes = 0;
  var hash = _fnv1aOffset;
  final delay = _durationFromQuery(request.uri.queryParameters['delay_ms']);
  final bodyStopwatch = Stopwatch()..start();
  await for (final chunk in request) {
    bytes += chunk.length;
    for (final byte in chunk) {
      hash = ((hash ^ byte) * _fnv1aPrime) & _fnv1aMask;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
  bodyStopwatch.stop();
  final expectedString = request.uri.queryParameters['expected'];
  final expected = expectedString == null ? null : int.tryParse(expectedString);
  if (expectedString != null && expected == null) {
    throw FormatException('Invalid expected byte count: $expectedString');
  }
  final expectedHash = request.uri.queryParameters['expected_hash'];
  final actualHash = hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  final matches =
      (expected == null || expected == bytes) &&
      (expectedHash == null || expectedHash == actualHash);
  if (!matches) {
    response.statusCode = HttpStatus.badRequest;
  }
  response.headers
    ..set('x-alphax-server-body-read-us', '${bodyStopwatch.elapsed.inMicroseconds}')
    ..set('x-alphax-upload-hash-algorithm', 'fnv1a64')
    ..set('x-alphax-upload-fnv1a64', actualHash);
  response.headers.set('x-alphax-uploaded-bytes', '$bytes');
  _writeJsonBody(response, <String, Object>{
    'bytes': bytes,
    'expected': expected ?? bytes,
    'hash': actualHash,
    'expected_hash': expectedHash ?? actualHash,
    'ok': matches,
  });
}

const int _fnv1aOffset = 0xcbf29ce484222325;
const int _fnv1aPrime = 0x100000001b3;
const int _fnv1aMask = 0xffffffffffffffff;

/// Computes the deterministic upload hash used by the benchmark contract.
int fnv1a64(Iterable<int> bytes) {
  var hash = _fnv1aOffset;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * _fnv1aPrime) & _fnv1aMask;
  }
  return hash;
}

final class _ConnectionObservation {
  const _ConnectionObservation({
    required this.id,
    required this.requestCount,
    required this.connectionsEstablished,
    required this.requestsObserved,
  });

  final int id;
  final int requestCount;
  final int connectionsEstablished;
  final int requestsObserved;
}

final class _ConnectionTracker {
  final Map<String, int> _ids = <String, int>{};
  final Map<String, int> _requestCounts = <String, int>{};
  var _requestsObserved = 0;

  _ConnectionObservation observe(HttpRequest request) {
    _requestsObserved++;
    final info = request.connectionInfo;
    final key = info == null
        ? 'unknown-${identityHashCode(request)}'
        : '${info.remoteAddress.address}:${info.remotePort}';
    final id = _ids.putIfAbsent(key, () => _ids.length + 1);
    final requestCount = (_requestCounts[key] ?? 0) + 1;
    _requestCounts[key] = requestCount;
    return _ConnectionObservation(
      id: id,
      requestCount: requestCount,
      connectionsEstablished: _ids.length,
      requestsObserved: _requestsObserved,
    );
  }

  Map<String, Object> snapshot() => <String, Object>{
    'requests_observed': _requestsObserved,
    'connections_established': _ids.length,
    'requests_per_connection': _requestCounts.map(
      (key, value) => MapEntry<String, int>('${_ids[key]}', value),
    ),
    'connection_close_events': 'unavailable:dart-http-server-api',
    'connection_observation': 'remote-address-and-port',
  };
}

void _redirect(HttpResponse response, int count) {
  if (count == 0) {
    _writeText(response, 'redirect complete');
    return;
  }
  response
    ..statusCode = HttpStatus.found
    ..headers.set(HttpHeaders.locationHeader, '/redirect/${count - 1}');
}

void _writeText(HttpResponse response, String text) {
  response
    ..headers.contentType = ContentType.text
    ..write(text);
}

/// Returns the deterministic byte pattern used by all binary endpoints.
List<int> deterministicBytes(int length, int offset) =>
    List<int>.generate(length, (index) => (index + offset) % 251, growable: false);

int _positiveInt(List<String> segments, int index, String name) {
  if (index >= segments.length) {
    throw FormatException('Missing $name');
  }
  final value = int.tryParse(segments[index]);
  if (value == null || value < 0) {
    throw FormatException('Invalid $name: ${segments[index]}');
  }
  return value;
}

Duration _durationFromPath(List<String> segments, int index, String name) =>
    Duration(milliseconds: _positiveInt(segments, index, name));

Duration _durationFromQuery(String? value) {
  if (value == null) {
    return Duration.zero;
  }
  final milliseconds = int.tryParse(value);
  if (milliseconds == null || milliseconds < 0) {
    throw FormatException('Invalid delay_ms: $value');
  }
  return Duration(milliseconds: milliseconds);
}

/// CLI options for [BenchmarkServer].
final class BenchmarkServerOptions {
  const BenchmarkServerOptions({
    required this.host,
    required this.port,
    required this.certificatePath,
    required this.privateKeyPath,
  });

  /// Parsed bind address.
  final InternetAddress host;

  /// Parsed port.
  final int port;

  /// Optional PEM certificate chain.
  final String? certificatePath;

  /// Optional PEM private key.
  final String? privateKeyPath;

  /// Parses `--host` and `--port`.
  static BenchmarkServerOptions parse(List<String> args) {
    var host = InternetAddress.loopbackIPv4;
    var port = 8080;
    String? certificatePath;
    String? privateKeyPath;
    for (var index = 0; index < args.length; index++) {
      switch (args[index]) {
        case '--host':
          host = InternetAddress(args[++index]);
        case '--port':
          port = int.parse(args[++index]);
        case '--tls-certificate':
          certificatePath = args[++index];
        case '--tls-private-key':
          privateKeyPath = args[++index];
        default:
          throw FormatException('Unknown argument: ${args[index]}');
      }
    }
    if ((certificatePath == null) != (privateKeyPath == null)) {
      throw FormatException('--tls-certificate and --tls-private-key must be provided together');
    }
    return BenchmarkServerOptions(
      host: host,
      port: port,
      certificatePath: certificatePath,
      privateKeyPath: privateKeyPath,
    );
  }
}
