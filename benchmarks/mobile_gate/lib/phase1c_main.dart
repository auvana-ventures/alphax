import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

const _h1BaseUrl = String.fromEnvironment('ALPHAX_PHASE1C_H1_BASE_URL');
const _h2Url = String.fromEnvironment(
  'ALPHAX_PHASE1C_H2_URL',
  defaultValue: 'https://nghttp2.org/httpbin/get',
);
const _h3Url = String.fromEnvironment(
  'ALPHAX_PHASE1C_H3_URL',
  defaultValue: 'https://cloudflare-quic.com/',
);
const _deviceModel = String.fromEnvironment(
  'ALPHAX_DEVICE_MODEL',
  defaultValue: 'unreported',
);
const _deviceArchitecture = String.fromEnvironment(
  'ALPHAX_DEVICE_ARCH',
  defaultValue: 'unreported',
);
const _flutterVersion = String.fromEnvironment(
  'ALPHAX_FLUTTER_VERSION',
  defaultValue: 'unreported',
);
const _gitCommit = String.fromEnvironment(
  'ALPHAX_GIT_COMMIT',
  defaultValue: 'unreported',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Phase1CApp());

  final result = await _runValidation();
  final encoded = jsonEncode(result);
  final resultFile = File(
    '${Directory.systemTemp.path}/alphax-phase1c-result.json',
  );
  await resultFile.writeAsString(encoded, flush: true);
  _emitResult(encoded, resultFile.path);
}

void _emitResult(String encoded, String resultPath) {
  // Android log entries are limited in size. Keep each entry small enough to
  // preserve the complete machine-readable result for physical-device runs.
  const chunkSize = 2400;
  debugPrint('ALPHAX_PHASE1C_RESULT_BEGIN');
  debugPrint('ALPHAX_PHASE1C_RESULT_FILE:$resultPath');
  stdout.writeln('ALPHAX_PHASE1C_RESULT_BEGIN');
  stdout.writeln('ALPHAX_PHASE1C_RESULT_FILE:$resultPath');
  for (var offset = 0; offset < encoded.length; offset += chunkSize) {
    final end = (offset + chunkSize).clamp(0, encoded.length);
    final chunk = encoded.substring(offset, end);
    debugPrint('ALPHAX_PHASE1C_RESULT_CHUNK:${offset ~/ chunkSize}:$chunk');
    stdout.writeln('ALPHAX_PHASE1C_RESULT_CHUNK:${offset ~/ chunkSize}:$chunk');
  }
  debugPrint('ALPHAX_PHASE1C_RESULT_END');
  stdout.writeln('ALPHAX_PHASE1C_RESULT_END');
}

final class _Phase1CApp extends StatelessWidget {
  const _Phase1CApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('AlphaX Phase 1C Android validation is running.'),
      ),
    ),
  );
}

Future<Map<String, Object?>> _runValidation() async {
  final report = <String, Object?>{
    'metadata': <String, Object?>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'device_model': _deviceModel,
      'architecture': _deviceArchitecture,
      'dart_version': Platform.version,
      'flutter_version': _flutterVersion,
      'build_mode': 'profile device build; no debug transport comparison',
      'git_commit': _gitCommit,
      'h1_endpoint': _h1BaseUrl.isEmpty ? 'not supplied' : _h1BaseUrl,
      'h2_endpoint': _h2Url,
      'h3_endpoint': _h3Url,
      'h2_h3_endpoint_type': 'external protocol-validation endpoints',
      'tls_policy': 'Cronet platform trust defaults; no trust-all override',
      'bounded_stream_window': '4 native read credits x 64 KiB = 256 KiB',
    },
    'status': 'blocked',
    'capabilities': null,
    'checks': <Map<String, Object?>>[],
    'blockers': <String>[],
  };

  if (!Platform.isAndroid) {
    (report['blockers']! as List<String>).add('This harness requires Android.');
    return report;
  }
  if (_h1BaseUrl.isEmpty) {
    (report['blockers']! as List<String>).add(
      'ALPHAX_PHASE1C_H1_BASE_URL was not supplied.',
    );
    return report;
  }

  AndroidCronetTransport? transport;
  try {
    transport = await AndroidCronetTransport.create();
    report['capabilities'] = _capabilityMap(transport.capabilities);
    final checks = report['checks']! as List<Map<String, Object?>>;
    final h1 = Uri.parse(_h1BaseUrl);

    await _check(checks, 'h1_methods_and_headers', () async {
      final methods = <HttpMethod>[
        HttpMethod.get,
        HttpMethod.post,
        HttpMethod.put,
        HttpMethod.patch,
        HttpMethod.delete,
        HttpMethod.head,
        HttpMethod.options,
      ];
      final statuses = <String, int>{};
      final protocols = <String, String>{};
      for (final method in methods) {
        final response = await transport!.send(
          AlphaXRequest(
            method: method,
            uri: method == HttpMethod.head
                ? h1.resolve('/bytes/1')
                : h1.resolve('/echo'),
            body: method == HttpMethod.get || method == HttpMethod.head
                ? const AlphaXEmptyBody()
                : AlphaXBody.bytes(const <int>[1, 2, 3]),
            headers: AlphaXHeaders(<String, String>{
              'x-phase1c-check': 'methods',
              if (method != HttpMethod.get && method != HttpMethod.head)
                'content-type': 'application/octet-stream',
            }),
          ),
        );
        final body = await response.readAsBytes();
        if (method == HttpMethod.head && body.isNotEmpty) {
          throw StateError('HEAD returned a body');
        }
        if (method != HttpMethod.head &&
            method != HttpMethod.get &&
            !listEquals(body, const <int>[1, 2, 3])) {
          throw StateError('$method echo body was not preserved');
        }
        statuses[method.value] = response.statusCode;
        protocols[method.value] = response.protocol.name;
      }
      return <String, Object?>{'statuses': statuses, 'protocols': protocols};
    });

    await _check(checks, 'h1_streaming_pause_resume', () async {
      final response = await transport!.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: h1.resolve('/stream/8/65536?delay_ms=5'),
        ),
      );
      var chunks = 0;
      var bytes = 0;
      final done = Completer<void>();
      late StreamSubscription<List<int>> subscription;
      subscription = response.stream.listen(
        (chunk) {
          chunks += 1;
          bytes += chunk.length;
          if (chunks == 1) {
            subscription.pause(
              Future<void>.delayed(const Duration(milliseconds: 150)),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!done.isCompleted) done.completeError(error, stackTrace);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      await subscription.cancel();
      final expected = 8 * 65536;
      if (bytes != expected) {
        throw StateError('stream delivered $bytes bytes; expected $expected');
      }
      return <String, Object?>{
        'chunks': chunks,
        'bytes': bytes,
        'paused_once': true,
      };
    });

    await _check(checks, 'h1_redirect_and_reuse', () async {
      final requests = <AlphaXResponse>[];
      for (var index = 0; index < 2; index++) {
        requests.add(
          await transport!.send(
            AlphaXRequest(method: HttpMethod.get, uri: h1.resolve('/bytes/1')),
          ),
        );
      }
      for (final response in requests) {
        await response.readAsBytes();
      }
      final redirect = await transport!.send(
        AlphaXRequest(method: HttpMethod.get, uri: h1.resolve('/redirect/1')),
      );
      final redirectBody = await redirect.readAsString();
      if (redirect.statusCode != 200 || redirect.redirects.length != 1) {
        throw StateError('redirect did not resolve with one recorded hop');
      }
      return <String, Object?>{
        'connection_ids': requests
            .map(
              (response) => response.headers['x-alphax-server-connection-id'],
            )
            .toList(),
        'connection_request_counts': requests
            .map(
              (response) =>
                  response.headers['x-alphax-server-connection-request-count'],
            )
            .toList(),
        'redirect_body': redirectBody,
        'redirects': redirect.redirects.length,
      };
    });

    await _check(checks, 'h1_native_file_download', () async {
      final directory = await Directory.systemTemp.createTemp(
        'alphax-phase1c-download-',
      );
      final path = '${directory.path}/download.bin';
      try {
        final result = await transport!.download(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: h1.resolve('/bytes/1048576'),
          ),
          AlphaXLocalFileTarget(path),
        );
        final bytes = await File(path).readAsBytes();
        final expected = _deterministicBytes(1048576, 0);
        if (result.bytesTransferred != bytes.length ||
            !listEquals(bytes, expected)) {
          throw StateError(
            'native download size or deterministic content mismatch',
          );
        }
        return <String, Object?>{
          'status_code': result.statusCode,
          'bytes': bytes.length,
          'hash': _fnv1a64(bytes),
          'protocol': result.protocol.name,
        };
      } finally {
        await directory.delete(recursive: true);
      }
    });

    await _check(checks, 'h1_native_file_upload', () async {
      final directory = await Directory.systemTemp.createTemp(
        'alphax-phase1c-upload-',
      );
      final path = '${directory.path}/upload.bin';
      try {
        final bytes = _deterministicBytes(1048576, 0);
        await File(path).writeAsBytes(bytes, flush: true);
        final uploadRequest = AlphaXRequest(
          method: HttpMethod.post,
          uri: h1.resolve('/upload'),
          headers: AlphaXHeaders(<String, String>{
            'content-type': 'application/octet-stream',
          }),
        );
        final transfer = await transport!.upload(
          uploadRequest,
          AlphaXLocalFileSource(path),
        );
        final response = await transport!.send(
          AlphaXRequest(
            method: HttpMethod.post,
            uri: h1.resolve('/upload'),
            body: AlphaXFileBody(AlphaXLocalFileSource(path)),
            headers: AlphaXHeaders(<String, String>{
              'content-type': 'application/octet-stream',
            }),
          ),
        );
        final validation =
            jsonDecode(await response.readAsString()) as Map<String, Object?>;
        if (transfer.statusCode != 200 ||
            validation['ok'] != true ||
            validation['bytes'] != bytes.length ||
            validation['hash'] != _fnv1a64(bytes)) {
          throw StateError(
            'native upload size or deterministic content mismatch',
          );
        }
        return <String, Object?>{
          'status_code': transfer.statusCode,
          'bytes': validation['bytes'],
          'hash': validation['hash'],
          'server_ok': validation['ok'],
          'upload_api_bytes': transfer.bytesTransferred,
        };
      } finally {
        await directory.delete(recursive: true);
      }
    });

    await _check(checks, 'h1_cancellation', () async {
      final token = AlphaXCancellationToken();
      final future = transport!.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: h1.resolve('/delay/5000'),
          cancellationToken: token,
        ),
      );
      Timer(const Duration(milliseconds: 150), token.cancel);
      try {
        await future;
      } on AlphaXCancellationException {
        return <String, Object?>{'cancelled': true};
      }
      throw StateError('delayed request completed instead of being cancelled');
    });

    await _checkProtocol(
      checks,
      transport,
      'h2',
      Uri.parse(_h2Url),
      AlphaXProtocolPreference.http2,
    );
    await _checkProtocol(
      checks,
      transport,
      'h3',
      Uri.parse(_h3Url),
      AlphaXProtocolPreference.http3,
    );
  } catch (error, stackTrace) {
    (report['blockers']! as List<String>).add('Transport setup failed: $error');
    report['setup_error_stack'] = stackTrace.toString();
  } finally {
    await transport?.close();
  }

  final checks = report['checks']! as List<Map<String, Object?>>;
  final failures = checks
      .where((check) => check['ok'] != true)
      .toList(growable: false);
  final h3 = checks.where((check) => check['name'] == 'h3').firstOrNull;
  report['status'] = failures.isEmpty && h3?['negotiated_protocol'] == 'http3'
      ? 'complete'
      : 'correctness_or_capability_failure';
  if (h3?['negotiated_protocol'] != 'http3') {
    (report['blockers']! as List<String>).add(
      'No HTTP/3 negotiation was observed; fallback is reported, not counted as H3 support.',
    );
  }
  return report;
}

Future<void> _check(
  List<Map<String, Object?>> checks,
  String name,
  Future<Map<String, Object?>> Function() action,
) async {
  try {
    checks.add(<String, Object?>{
      'name': name,
      'ok': true,
      'details': await action(),
    });
  } catch (error, stackTrace) {
    checks.add(<String, Object?>{
      'name': name,
      'ok': false,
      'error': error.toString(),
      'stack': stackTrace.toString(),
    });
  }
}

Future<void> _checkProtocol(
  List<Map<String, Object?>> checks,
  AndroidCronetTransport transport,
  String name,
  Uri uri,
  AlphaXProtocolPreference preference,
) async {
  try {
    AlphaXProtocol? prewarmProtocol;
    if (preference == AlphaXProtocolPreference.http3) {
      // Cronet learns an origin's Alt-Svc advertisement from a normal secure
      // request. This is one fixed capability probe, not a benchmark sample.
      final warmup = await transport.send(
        AlphaXRequest(method: HttpMethod.get, uri: uri),
      );
      prewarmProtocol = warmup.protocol;
      await warmup.readAsBytes();
      // Cronet learns Alt-Svc asynchronously from the completed response.
      // Give that cache update a short deterministic settling window before
      // the single explicit H3 probe.
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: uri,
        protocolPreference: preference,
      ),
    );
    final bytes = await response.readAsBytes();
    checks.add(<String, Object?>{
      'name': name,
      'ok': response.statusCode >= 200 && response.statusCode < 400,
      'status_code': response.statusCode,
      'body_bytes': bytes.length,
      'prewarm_protocol': prewarmProtocol?.name,
      'negotiated_protocol': response.protocol.name,
      'requested_protocol': preference.name,
      'fallback': response.protocolFallback == null
          ? null
          : <String, Object?>{
              'requested': response.protocolFallback!.requested.name,
              'negotiated': response.protocolFallback!.negotiated.name,
              'reason': response.protocolFallback!.reason.name,
            },
      'headers_protocol': response.headers['x-alphax-server-protocol'],
      'alt_svc': response.headers['alt-svc'],
    });
  } catch (error, stackTrace) {
    checks.add(<String, Object?>{
      'name': name,
      'ok': false,
      'requested_protocol': preference.name,
      'error': error.toString(),
      'stack': stackTrace.toString(),
    });
  }
}

Map<String, Object?> _capabilityMap(AlphaXCapabilities capabilities) =>
    <String, Object?>{
      'transport_name': capabilities.transportName,
      'transport_version': capabilities.transportVersion,
      for (final capability in AlphaXCapability.values)
        capability.name: capabilities.supportFor(capability).name,
    };

List<int> _deterministicBytes(int length, int offset) => <int>[
  for (var index = 0; index < length; index++) (index + offset) % 251,
];

String _fnv1a64(List<int> bytes) {
  var value = 0xcbf29ce484222325;
  for (final byte in bytes) {
    value = ((value ^ byte) * 0x100000001b3) & 0xffffffffffffffff;
  }
  return value.toRadixString(16).padLeft(16, '0');
}

bool listEquals(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
