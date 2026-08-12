import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

Future<void> main(List<String> args) async {
  final options = _ServerOptions.parse(args);
  final server = await HttpServer.bind(options.host, options.port);
  stdout.writeln(
    'AlphaX benchmark server listening on http://${server.address.address}:${server.port}',
  );

  ProcessSignal.sigint.watch().listen((_) {
    unawaited(server.close(force: true));
  });

  await for (final request in server) {
    unawaited(_handle(request));
  }
}

Future<void> _handle(HttpRequest request) async {
  final response = request.response;
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
    response.add(_pattern(length, offset));
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
    response.add(_pattern(chunkSize, index));
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
  await for (final chunk in request) {
    bytes += chunk.length;
  }
  final expectedString = request.uri.queryParameters['expected'];
  final expected = expectedString == null ? null : int.tryParse(expectedString);
  if (expectedString != null && expected == null) {
    throw FormatException('Invalid expected byte count: $expectedString');
  }
  final matches = expected == null || expected == bytes;
  if (!matches) {
    response.statusCode = HttpStatus.badRequest;
  }
  response.headers.set('x-alphax-uploaded-bytes', '$bytes');
  _writeJsonBody(response, <String, Object>{
    'bytes': bytes,
    'expected': expected ?? bytes,
    'ok': matches,
  });
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

List<int> _pattern(int length, int offset) =>
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

final class _ServerOptions {
  const _ServerOptions({required this.host, required this.port});

  final InternetAddress host;
  final int port;

  static _ServerOptions parse(List<String> args) {
    var host = InternetAddress.loopbackIPv4;
    var port = 8080;
    for (var index = 0; index < args.length; index++) {
      switch (args[index]) {
        case '--host':
          host = InternetAddress(args[++index]);
        case '--port':
          port = int.parse(args[++index]);
        default:
          throw FormatException('Unknown argument: ${args[index]}');
      }
    }
    return _ServerOptions(host: host, port: port);
  }
}
