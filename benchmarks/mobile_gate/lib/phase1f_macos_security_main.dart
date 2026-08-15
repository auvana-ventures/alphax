import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

const _fixtureBody = 'alphax-macos-security-fixture';
const _fixtureDirectory = String.fromEnvironment('ALPHAX_SECURITY_FIXTURE_DIR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SecurityFixtureApp());

  final result = await _runFixture();
  final encoded = const JsonEncoder.withIndent('  ').convert(result);
  final resultFile = File(
    '${Directory.systemTemp.path}/alphax-phase1f-macos-security.json',
  );
  await resultFile.writeAsString(encoded, flush: true);
  stdout.writeln(
    'ALPHAX_PHASE1F_MACOS_SECURITY_RESULT_FILE:${resultFile.path}',
  );
  stdout.writeln('ALPHAX_PHASE1F_MACOS_SECURITY_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_PHASE1F_MACOS_SECURITY_RESULT_END');
  await Future<void>.delayed(const Duration(milliseconds: 250));
  exit(result['status'] == 'passed' ? 0 : 1);
}

final class _SecurityFixtureApp extends StatelessWidget {
  const _SecurityFixtureApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('AlphaX macOS security fixtures are running.')),
    ),
  );
}

Future<Map<String, Object?>> _runFixture() async {
  final checks = <Map<String, Object?>>[];
  final metadata = <String, Object?>{
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'architecture': Platform.version.split(' ').first,
    'dart_version': Platform.version,
    'build_mode': 'focused macOS correctness fixture; no performance data',
    'transport': 'Apple URLSession',
    'tls_verification': 'platform trust remains enabled; no trust-all path',
    'fixture_scope': 'custom CA, SPKI pinning, HTTP proxy, CONNECT, auth',
  };

  if (!Platform.isMacOS) {
    checks.add(_checkResult('platform', false, 'macOS is required'));
    return <String, Object?>{
      'status': 'failed',
      'metadata': metadata,
      'checks': checks,
    };
  }

  if (_fixtureDirectory.isEmpty) {
    checks.add(
      _checkResult(
        'fixture_material_directory',
        false,
        'ALPHAX_SECURITY_FIXTURE_DIR is required',
      ),
    );
    return <String, Object?>{
      'status': 'failed',
      'metadata': metadata,
      'checks': checks,
    };
  }

  final workspace = await _FixtureWorkspace.open(Directory(_fixtureDirectory));
  final httpServer = await _FixtureHttpServer.bind();
  final tlsServer = await _FixtureTlsServer.bind(
    certificatePath: workspace.serverCertificate.path,
    keyPath: workspace.serverKey.path,
  );
  final untrustedTlsServer = await _FixtureTlsServer.bind(
    certificatePath: workspace.untrustedCertificate.path,
    keyPath: workspace.untrustedKey.path,
  );

  try {
    metadata['provider'] = 'Foundation URLSession';
    metadata['server'] = <String, Object?>{
      'http': 'http://127.0.0.1:${httpServer.port}',
      'tls': 'https://localhost:${tlsServer.port}',
      'untrusted_tls': 'https://localhost:${untrustedTlsServer.port}',
    };
    metadata['trust_anchor_mode'] =
        'generated CA, DER anchor supplied to URLSession';
    metadata['pin_digest'] = workspace.serverPin;

    await _record(checks, 'default_trust_rejects_test_ca', () async {
      await _expectFailure(
        () => _get(
          tlsServer.uri,
          tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
        ),
        'default trust accepted the generated test CA',
      );
    });

    await _record(checks, 'configured_custom_ca_succeeds', () async {
      final response = await _get(
        tlsServer.uri,
        tlsPolicy: AlphaXTlsPolicy(
          includePlatformTrust: false,
          trustAnchors: <AlphaXTrustAnchor>[
            AlphaXTrustAnchor.der(workspace.caDer),
          ],
        ),
      );
      _expectFixtureResponse(response);
    });

    await _record(checks, 'incorrect_custom_ca_fails', () async {
      await _expectFailure(
        () => _get(
          tlsServer.uri,
          tlsPolicy: AlphaXTlsPolicy(
            includePlatformTrust: false,
            trustAnchors: <AlphaXTrustAnchor>[
              AlphaXTrustAnchor.der(workspace.wrongCaDer),
            ],
          ),
        ),
        'incorrect trust anchor was accepted',
      );
    });

    await _record(checks, 'correct_spki_pin_succeeds', () async {
      final response = await _get(
        tlsServer.uri,
        tlsPolicy: _pinnedPolicy(workspace, <String>[workspace.serverPin]),
      );
      _expectFixtureResponse(response);
    });

    await _record(checks, 'incorrect_spki_pin_fails', () async {
      await _expectFailure(
        () => _get(
          tlsServer.uri,
          tlsPolicy: _pinnedPolicy(workspace, <String>[_wrongPin]),
        ),
        'incorrect SPKI pin was accepted',
        expected: AlphaXCertificatePinMismatchException,
      );
    });

    await _record(checks, 'backup_spki_pin_succeeds', () async {
      final response = await _get(
        tlsServer.uri,
        tlsPolicy: _pinnedPolicy(workspace, <String>[
          _wrongPin,
          workspace.serverPin,
        ]),
      );
      _expectFixtureResponse(response);
    });

    await _record(checks, 'pin_does_not_trust_untrusted_certificate', () async {
      await _expectFailure(
        () => _get(
          untrustedTlsServer.uri,
          tlsPolicy: AlphaXTlsPolicy(
            pins: <AlphaXSpkiPin>[
              _pin(host: 'localhost', digest: workspace.untrustedPin),
            ],
          ),
        ),
        'a matching pin made an untrusted certificate valid',
      );
    });

    await _record(checks, 'direct_policy_routes_without_proxy', () async {
      final response = await _get(
        httpServer.uri,
        proxyPolicy: const AlphaXProxyPolicy.direct(),
      );
      _expectFixtureResponse(response);
    });

    final explicitProxy = await _FixtureProxy.bind();
    try {
      await _record(checks, 'explicit_http_proxy_routes_http', () async {
        final response = await _get(
          httpServer.uri,
          proxyPolicy: AlphaXProxyPolicy.http(
            host: '127.0.0.1',
            port: explicitProxy.port,
          ),
        );
        _expectFixtureResponse(response);
        if (explicitProxy.requests == 0) {
          throw StateError('The explicit proxy did not observe a request');
        }
      });
    } finally {
      await explicitProxy.close();
    }

    final connectProxy = await _FixtureProxy.bind();
    try {
      await _record(checks, 'custom_ca_over_connect_fails_closed', () async {
        await _expectFailure(
          () => _get(
            tlsServer.proxiedUri,
            tlsPolicy: _customCaPolicy(workspace),
            proxyPolicy: AlphaXProxyPolicy.http(
              host: '127.0.0.1',
              port: connectProxy.port,
            ),
          ),
          'The local custom-CA CONNECT path unexpectedly completed',
          expected: AlphaXTlsException,
        );
      });
      await _record(
        checks,
        'http_proxy_connects_trusted_https_destination',
        () async {
          final response = await _get(
            Uri.parse('https://www.apple.com/'),
            proxyPolicy: AlphaXProxyPolicy.http(
              host: '127.0.0.1',
              port: connectProxy.port,
            ),
          );
          if (response.statusCode != HttpStatus.ok ||
              connectProxy.connects < 2) {
            throw StateError(
              'The explicit HTTP proxy did not complete a trusted HTTPS CONNECT',
            );
          }
        },
      );
    } finally {
      metadata['connect_proxy_observed'] = connectProxy.observed;
      metadata['connect_proxy_connects'] = connectProxy.connects;
      metadata['connect_proxy_client_bytes'] = connectProxy.clientBytes;
      metadata['connect_proxy_upstream_bytes'] = connectProxy.upstreamBytes;
      await connectProxy.close();
    }

    final authProxy = await _FixtureProxy.bind(requireAuthentication: true);
    try {
      await _record(checks, 'proxy_basic_auth_succeeds', () async {
        final response = await _get(
          httpServer.uri,
          proxyPolicy: AlphaXProxyPolicy.http(
            host: '127.0.0.1',
            port: authProxy.port,
            credentials: const AlphaXProxyCredentials.basic(
              username: 'fixture-user',
              password: 'fixture-password',
            ),
          ),
        );
        _expectFixtureResponse(response);
      });
    } finally {
      metadata['auth_proxy_observed_auth'] = authProxy.observedAuth;
      await authProxy.close();
    }

    final wrongAuthProxy = await _FixtureProxy.bind(
      requireAuthentication: true,
    );
    try {
      await _record(checks, 'proxy_wrong_credentials_fail_closed', () async {
        await _expectFailure(
          () => _get(
            httpServer.uri,
            proxyPolicy: AlphaXProxyPolicy.http(
              host: '127.0.0.1',
              port: wrongAuthProxy.port,
              credentials: const AlphaXProxyCredentials.basic(
                username: 'fixture-user',
                password: 'wrong-password',
              ),
            ),
          ),
          'wrong proxy credentials were accepted',
          expected: AlphaXProxyAuthenticationException,
        );
      });
    } finally {
      await wrongAuthProxy.close();
    }

    final unreachableProxy = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final unreachablePort = unreachableProxy.port;
    await unreachableProxy.close();
    await _record(checks, 'unreachable_proxy_fails_closed', () async {
      await _expectFailure(
        () => _get(
          httpServer.uri,
          proxyPolicy: AlphaXProxyPolicy.http(
            host: '127.0.0.1',
            port: unreachablePort,
          ),
        ),
        'unreachable proxy unexpectedly completed the request',
      );
    });

    await _record(checks, 'system_policy_is_observable', () async {
      try {
        final response = await _get(
          httpServer.uri,
          proxyPolicy: const AlphaXProxyPolicy.system(),
        );
        _expectFixtureResponse(response);
      } on AlphaXException catch (error) {
        throw StateError(
          'System proxy policy was not usable for loopback in this environment: '
          '${error.kind.name}',
        );
      }
    });
  } finally {
    await untrustedTlsServer.close();
    await tlsServer.close();
    await httpServer.close();
    await workspace.dispose();
  }

  final failures = checks.where((check) => check['status'] != 'passed');
  return <String, Object?>{
    'status': failures.isEmpty ? 'passed' : 'failed',
    'metadata': metadata,
    'checks': checks,
  };
}

AlphaXTlsPolicy _customCaPolicy(_FixtureWorkspace workspace) => AlphaXTlsPolicy(
  includePlatformTrust: false,
  trustAnchors: <AlphaXTrustAnchor>[AlphaXTrustAnchor.der(workspace.caDer)],
);

AlphaXTlsPolicy _pinnedPolicy(
  _FixtureWorkspace workspace,
  List<String> digests,
) => AlphaXTlsPolicy(
  includePlatformTrust: false,
  trustAnchors: <AlphaXTrustAnchor>[AlphaXTrustAnchor.der(workspace.caDer)],
  pins: <AlphaXSpkiPin>[
    for (final digest in digests) _pin(host: 'localhost', digest: digest),
  ],
);

AlphaXSpkiPin _pin({required String host, required String digest}) =>
    AlphaXSpkiPin(
      host: host,
      sha256SpkiBase64: digest,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

Future<AlphaXResponse> _get(
  Uri uri, {
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
}) async {
  final transport = await AppleUrlSessionTransport.create(
    tlsPolicy: tlsPolicy,
    proxyPolicy: proxyPolicy,
  );
  try {
    final response = await transport.send(
      AlphaXRequest(method: HttpMethod.get, uri: uri),
    );
    await response.readAsBytes();
    return response;
  } finally {
    await transport.close();
  }
}

void _expectFixtureResponse(AlphaXResponse response) {
  if (response.statusCode != HttpStatus.ok) {
    throw StateError('Expected HTTP 200, received ${response.statusCode}');
  }
}

Future<void> _expectFailure(
  Future<Object> Function() operation,
  String successMessage, {
  Type? expected,
}) async {
  try {
    await operation();
  } on Object catch (error) {
    if (expected != null && error.runtimeType != expected) {
      throw StateError(
        'Expected ${expected.toString()}, received ${error.runtimeType}',
      );
    }
    return;
  }
  throw StateError(successMessage);
}

Future<void> _record(
  List<Map<String, Object?>> checks,
  String name,
  Future<void> Function() operation,
) async {
  try {
    await operation();
    checks.add(_checkResult(name, true));
  } on Object catch (error) {
    checks.add(_checkResult(name, false, _errorDescription(error)));
  }
}

Map<String, Object?> _checkResult(String name, bool passed, [String? error]) =>
    <String, Object?>{
      'name': name,
      'status': passed ? 'passed' : 'failed',
      'error': error,
    };

String _errorDescription(Object error) {
  if (error is AlphaXException) {
    return '${error.runtimeType} (${error.kind.name}): ${error.message}';
  }
  return '${error.runtimeType}: $error';
}

const _wrongPin = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

final class _FixtureWorkspace {
  _FixtureWorkspace._(this.directory);

  final Directory directory;
  late final File caCertificate = File('${directory.path}/ca.pem');
  late final File caDerFile = File('${directory.path}/ca.der');
  late final File wrongCaDerFile = File('${directory.path}/wrong-ca.der');
  late final File serverCertificate = File('${directory.path}/server.pem');
  late final File serverKey = File('${directory.path}/server.key');
  late final File untrustedCertificate = File(
    '${directory.path}/untrusted.pem',
  );
  late final File untrustedKey = File('${directory.path}/untrusted.key');
  late final File serverPinFile = File('${directory.path}/server.pin');
  late final File untrustedPinFile = File('${directory.path}/untrusted.pin');

  List<int> get caDer => caDerFile.readAsBytesSync();
  List<int> get wrongCaDer => wrongCaDerFile.readAsBytesSync();
  String get serverPin => base64Encode(serverPinFile.readAsBytesSync());
  String get untrustedPin => base64Encode(untrustedPinFile.readAsBytesSync());

  static Future<_FixtureWorkspace> open(Directory directory) async {
    final workspace = _FixtureWorkspace._(directory);
    final required = <File>[
      workspace.caCertificate,
      workspace.caDerFile,
      workspace.wrongCaDerFile,
      workspace.serverCertificate,
      workspace.serverKey,
      workspace.untrustedCertificate,
      workspace.untrustedKey,
      workspace.serverPinFile,
      workspace.untrustedPinFile,
    ];
    for (final file in required) {
      if (!await file.exists()) {
        throw StateError('Missing security fixture material: ${file.path}');
      }
    }
    return workspace;
  }

  Future<void> dispose() async {
    // The invoking shell owns temporary fixture cleanup. The sandboxed app
    // must not delete material while the host process is still collecting it.
  }
}

final class _FixtureHttpServer {
  _FixtureHttpServer(this.server);

  final HttpServer server;
  Uri get uri => Uri.parse('http://localhost:${server.port}/fixture');
  int get port => server.port;

  static Future<_FixtureHttpServer> bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..headers.contentLength = utf8.encode(_fixtureBody).length
        ..write(_fixtureBody);
      unawaited(request.response.close());
    });
    return _FixtureHttpServer(server);
  }

  Future<void> close() => server.close(force: true);
}

final class _FixtureTlsServer {
  _FixtureTlsServer(this.server);

  final SecureServerSocket server;
  Uri get uri => Uri.parse('https://localhost:${server.port}/fixture');
  Uri get proxiedUri => Uri.parse('https://example.com:${server.port}/fixture');
  int get port => server.port;

  static Future<_FixtureTlsServer> bind({
    required String certificatePath,
    required String keyPath,
  }) async {
    final context = SecurityContext();
    context
      ..useCertificateChain(certificatePath)
      ..usePrivateKey(keyPath);
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((socket) => unawaited(_serveHttp(socket)));
    return _FixtureTlsServer(server);
  }

  Future<void> close() => server.close();
}

Future<void> _serveHttp(Socket socket) async {
  try {
    await _readHeaders(socket);
    final body = utf8.encode(_fixtureBody);
    socket.add(
      utf8.encode(
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/plain\r\n'
        'Content-Length: ${body.length}\r\n'
        'Connection: close\r\n\r\n',
      ),
    );
    socket.add(body);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

final class _FixtureProxy {
  _FixtureProxy(this.server, this.requireAuthentication);

  final ServerSocket server;
  final bool requireAuthentication;
  int requests = 0;
  int connects = 0;
  int clientBytes = 0;
  int upstreamBytes = 0;
  final List<String> observed = <String>[];
  final List<bool> observedAuth = <bool>[];
  final List<Future<void>> _active = <Future<void>>[];

  int get port => server.port;

  static Future<_FixtureProxy> bind({
    bool requireAuthentication = false,
  }) async {
    final proxy = _FixtureProxy(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      requireAuthentication,
    );
    proxy.server.listen((socket) {
      final operation = proxy._handle(socket);
      proxy._active.add(operation);
      unawaited(operation.whenComplete(() => proxy._active.remove(operation)));
    });
    return proxy;
  }

  Future<void> _handle(Socket client) async {
    final iterator = StreamIterator<List<int>>(client);
    try {
      var request = await _readProxyRequest(iterator);
      observed.add('${request.method} ${request.target}');
      observedAuth.add(request.headers.containsKey('proxy-authorization'));
      final expected =
          'Basic ${base64Encode(utf8.encode('fixture-user:fixture-password'))}';
      var authenticationAttempts = 0;
      while (requireAuthentication &&
          request.headers['proxy-authorization'] != expected) {
        authenticationAttempts++;
        if (authenticationAttempts > 3) return;
        client.add(
          utf8.encode(
            'HTTP/1.1 407 Proxy Authentication Required\r\n'
            'Proxy-Authenticate: Basic realm="AlphaX"\r\n'
            'Content-Length: 0\r\n'
            'Connection: keep-alive\r\n'
            'Proxy-Connection: keep-alive\r\n\r\n',
          ),
        );
        await client.flush();
        request = await _readProxyRequest(iterator);
        observed.add('${request.method} ${request.target}');
        observedAuth.add(request.headers.containsKey('proxy-authorization'));
      }
      requests++;
      if (request.method == 'CONNECT') {
        connects++;
        final target = _parseConnectTarget(request.target);
        final upstream = await Socket.connect(
          target.host == 'example.com'
              ? InternetAddress.loopbackIPv4
              : target.host,
          target.port,
        );
        client.add(
          utf8.encode(
            'HTTP/1.1 200 Connection Established\r\n'
            'Connection: keep-alive\r\n\r\n',
          ),
        );
        await client.flush();
        await _bridge(iterator, client, upstream, request.remaining);
      } else {
        final target = Uri.parse(request.target);
        final upstream = await Socket.connect(target.host, target.port);
        final path = target.hasQuery
            ? '${target.path}?${target.query}'
            : target.path;
        final headers = StringBuffer()
          ..write(
            '${request.method} ${path.isEmpty ? '/' : path} HTTP/1.1\r\n',
          );
        for (final entry in request.rawHeaders.entries) {
          if (entry.key == 'proxy-authorization' ||
              entry.key == 'proxy-connection') {
            continue;
          }
          headers.write('${entry.value.name}: ${entry.value.value}\r\n');
        }
        headers.write('Connection: close\r\n\r\n');
        upstream.add(utf8.encode(headers.toString()));
        if (request.remaining.isNotEmpty) upstream.add(request.remaining);
        await upstream.flush();
        await _bridge(iterator, client, upstream, const <int>[]);
      }
    } catch (error) {
      // A failed proxy route is intentionally represented by a closed route;
      // the Apple adapter normalizes the resulting failure without exposing
      // proxy implementation details.
      stderr.writeln('fixture proxy route failed: $error');
    } finally {
      await iterator.cancel();
      await client.close();
    }
  }

  Future<void> _bridge(
    StreamIterator<List<int>> clientIterator,
    Socket client,
    Socket upstream,
    List<int> remaining,
  ) async {
    final clientToUpstream = () async {
      if (remaining.isNotEmpty) upstream.add(remaining);
      try {
        while (await clientIterator.moveNext()) {
          clientBytes += clientIterator.current.length;
          upstream.add(clientIterator.current);
        }
        await upstream.flush();
      } finally {
        await upstream.close();
      }
    }();
    final upstreamToClient = () async {
      try {
        await for (final chunk in upstream) {
          upstreamBytes += chunk.length;
          client.add(chunk);
        }
        await client.flush();
      } finally {
        await client.close();
      }
    }();
    await Future.wait(<Future<void>>[clientToUpstream, upstreamToClient]);
  }

  Future<void> close() async {
    await server.close();
    await Future.wait(_active.toList(growable: false));
  }
}

final class _ProxyRequest {
  _ProxyRequest({
    required this.method,
    required this.target,
    required this.headers,
    required this.rawHeaders,
    required this.remaining,
  });

  final String method;
  final String target;
  final Map<String, String> headers;
  final Map<String, _RawHeader> rawHeaders;
  final List<int> remaining;
}

final class _RawHeader {
  _RawHeader(this.name, this.value);

  final String name;
  final String value;
}

Future<_ProxyRequest> _readProxyRequest(
  StreamIterator<List<int>> iterator,
) async {
  final bytes = <int>[];
  var headerEnd = -1;
  while (bytes.length < 65536 && await iterator.moveNext()) {
    bytes.addAll(iterator.current);
    headerEnd = _headerEnd(bytes);
    if (headerEnd >= 0) break;
  }
  if (headerEnd < 0) {
    final prefix = bytes
        .take(16)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    throw StateError('proxy request headers were incomplete (prefix=$prefix)');
  }
  final headerText = utf8.decode(bytes.sublist(0, headerEnd));
  final remaining = bytes.sublist(headerEnd + 4);
  final lines = headerText.split('\r\n');
  final start = lines.removeAt(0).split(' ');
  if (start.length < 2) throw StateError('invalid proxy request line');
  final headers = <String, String>{};
  final rawHeaders = <String, _RawHeader>{};
  for (final line in lines) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final name = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    final key = name.toLowerCase();
    headers[key] = value;
    rawHeaders[key] = _RawHeader(name, value);
  }
  return _ProxyRequest(
    method: start[0],
    target: start[1],
    headers: headers,
    rawHeaders: rawHeaders,
    remaining: remaining,
  );
}

({String host, int port}) _parseConnectTarget(String target) {
  final split = target.lastIndexOf(':');
  if (split <= 0) throw StateError('invalid CONNECT target');
  return (
    host: target.substring(0, split),
    port: int.parse(target.substring(split + 1)),
  );
}

Future<List<int>> _readHeaders(Stream<List<int>> stream) async {
  final iterator = StreamIterator<List<int>>(stream);
  final bytes = <int>[];
  try {
    while (bytes.length < 65536 && await iterator.moveNext()) {
      bytes.addAll(iterator.current);
      if (_headerEnd(bytes) >= 0) return bytes;
    }
    throw StateError('fixture request headers were incomplete');
  } finally {
    await iterator.cancel();
  }
}

int _headerEnd(List<int> bytes) {
  for (var index = 0; index + 3 < bytes.length; index++) {
    if (bytes[index] == 13 &&
        bytes[index + 1] == 10 &&
        bytes[index + 2] == 13 &&
        bytes[index + 3] == 10) {
      return index;
    }
  }
  return -1;
}
