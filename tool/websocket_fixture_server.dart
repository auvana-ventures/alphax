import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  stdout.writeln('PORT=${server.port}');
  await stdout.flush();

  server.listen((request) => unawaited(_handle(request)));
  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
}

Future<void> _handle(HttpRequest request) async {
  if (request.uri.path == '/abrupt') {
    final key = request.headers.value('sec-websocket-key');
    if (key == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final response = request.response
      ..statusCode = HttpStatus.switchingProtocols
      ..headers.add(HttpHeaders.connectionHeader, HttpHeaders.upgradeHeader)
      ..headers.add(HttpHeaders.upgradeHeader, 'websocket')
      ..headers.add('Sec-WebSocket-Accept', _webSocketAccept(key))
      ..contentLength = 0;
    final socket = await response.detachSocket();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    socket.destroy();
    return;
  }

  if (request.uri.path == '/reject') {
    request.response
      ..statusCode = HttpStatus.serviceUnavailable
      ..headers.contentType = ContentType.text;
    await request.response.close();
    return;
  }

  if (request.uri.path == '/delayed') {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  final socket = await WebSocketTransformer.upgrade(
    request,
    protocolSelector: (protocols) {
      if (request.uri.path == '/echo' || request.uri.path == '/delayed') {
        return protocols.contains('alpha.v1') ? 'alpha.v1' : null;
      }
      return null;
    },
  );

  if (request.uri.path == '/peer-close') {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await socket.close(1001, 'server shutdown');
    return;
  }

  socket.listen(
    (message) {
      if (message is String) {
        socket.add(message);
      } else if (message is List<int>) {
        socket.add(message);
      }
    },
    onError: (_) {},
    onDone: () {},
  );
}

const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

String _webSocketAccept(String key) => base64Encode(_sha1(utf8.encode('$key$_webSocketGuid')));

List<int> _sha1(List<int> input) {
  final bytes = <int>[...input, 0x80];
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  final bitLength = input.length * 8;
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xFF);
  }

  var h0 = 0x67452301;
  var h1 = 0xEFCDAB89;
  var h2 = 0x98BADCFE;
  var h3 = 0x10325476;
  var h4 = 0xC3D2E1F0;

  for (var offset = 0; offset < bytes.length; offset += 64) {
    final words = List<int>.filled(80, 0);
    for (var index = 0; index < 16; index++) {
      final start = offset + index * 4;
      words[index] =
          (bytes[start] << 24) |
          (bytes[start + 1] << 16) |
          (bytes[start + 2] << 8) |
          bytes[start + 3];
    }
    for (var index = 16; index < 80; index++) {
      words[index] = _rotateLeft(
        words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16],
        1,
      );
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    for (var index = 0; index < 80; index++) {
      final (f, k) = switch (index) {
        < 20 => ((b & c) | ((~b) & d), 0x5A827999),
        < 40 => (b ^ c ^ d, 0x6ED9EBA1),
        < 60 => ((b & c) | (b & d) | (c & d), 0x8F1BBCDC),
        _ => (b ^ c ^ d, 0xCA62C1D6),
      };
      final temp = (_rotateLeft(a, 5) + f + e + k + words[index]) & 0xFFFFFFFF;
      e = d;
      d = c;
      c = _rotateLeft(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
  }

  return <int>[
    ..._wordBytes(h0),
    ..._wordBytes(h1),
    ..._wordBytes(h2),
    ..._wordBytes(h3),
    ..._wordBytes(h4),
  ];
}

int _rotateLeft(int value, int bits) => ((value << bits) | (value >> (32 - bits))) & 0xFFFFFFFF;

List<int> _wordBytes(int word) => <int>[
  (word >> 24) & 0xFF,
  (word >> 16) & 0xFF,
  (word >> 8) & 0xFF,
  word & 0xFF,
];
