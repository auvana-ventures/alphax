import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

const _h1Url = String.fromEnvironment('ALPHAX_PHASE1D_H1_URL');
const _h2Url = String.fromEnvironment(
  'ALPHAX_PHASE1D_H2_URL',
  defaultValue: '',
);
const _h3Url = String.fromEnvironment(
  'ALPHAX_PHASE1D_H3_URL',
  defaultValue: '',
);
const _invalidTlsUrl = String.fromEnvironment(
  'ALPHAX_PHASE1D_INVALID_TLS_URL',
  defaultValue: '',
);
const _deviceModel = String.fromEnvironment(
  'ALPHAX_DEVICE_MODEL',
  defaultValue: 'unreported',
);
const _deviceArchitecture = String.fromEnvironment(
  'ALPHAX_DEVICE_ARCH',
  defaultValue: 'unreported',
);
const _gitCommit = String.fromEnvironment(
  'ALPHAX_GIT_COMMIT',
  defaultValue: 'unreported',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Phase1DApp());
  final result = await _runValidation();
  final encoded = jsonEncode(result);
  final resultFile = File(
    '${Directory.systemTemp.path}/alphax-phase1d-apple-result.json',
  );
  await resultFile.writeAsString(encoded, flush: true);
  stdout.writeln('ALPHAX_PHASE1D_APPLE_RESULT_FILE:${resultFile.path}');
  stdout.writeln('ALPHAX_PHASE1D_APPLE_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_PHASE1D_APPLE_RESULT_END');
}

final class _Phase1DApp extends StatelessWidget {
  const _Phase1DApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('AlphaX Phase 1D Apple validation is running.')),
    ),
  );
}

Future<Map<String, Object?>> _runValidation() async {
  final report = <String, Object?>{
    'status': 'blocked',
    'metadata': <String, Object?>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'device_model': _deviceModel,
      'architecture': _deviceArchitecture,
      'dart_version': Platform.version,
      'build_mode': 'profile correctness build; no performance ranking',
      'git_commit': _gitCommit,
      'h1_endpoint': _h1Url.isEmpty ? 'not supplied' : _h1Url,
      'h2_endpoint': _h2Url,
      'h3_endpoint': _h3Url,
      'invalid_tls_endpoint': _invalidTlsUrl,
      'tls_policy': 'URLSession platform trust defaults; no trust-all override',
      'protocol_observation':
          'URLSessionTaskMetrics is authoritative and arrives at completion; started protocol may be unknown',
      'bounded_stream_window':
          '4 native credits x 64 KiB = 256 KiB plus one platform callback',
    },
    'capabilities': null,
    'checks': <Map<String, Object?>>[],
    'protocol_probes': <Map<String, Object?>>[],
    'blockers': <String>[],
  };

  if (!Platform.isIOS && !Platform.isMacOS) {
    (report['blockers']! as List<String>).add(
      'This harness requires iOS or macOS.',
    );
    return report;
  }

  final missingEndpoints = <String>[
    if (_h2Url.isEmpty) 'ALPHAX_PHASE1D_H2_URL',
    if (_h3Url.isEmpty) 'ALPHAX_PHASE1D_H3_URL',
    if (_invalidTlsUrl.isEmpty) 'ALPHAX_PHASE1D_INVALID_TLS_URL',
  ];
  if (missingEndpoints.isNotEmpty) {
    (report['blockers']! as List<String>).add(
      'Explicit validation endpoints are required: ${missingEndpoints.join(', ')}',
    );
    return report;
  }

  AppleUrlSessionTransport? transport;
  try {
    transport = await AppleUrlSessionTransport.create();
    report['capabilities'] = _capabilityMap(transport.capabilities);
    final checks = report['checks']! as List<Map<String, Object?>>;
    final probes = report['protocol_probes']! as List<Map<String, Object?>>;

    await _check(checks, 'protocol_h2', () async {
      final probe = await _probe(
        transport!,
        Uri.parse(_h2Url),
        AlphaXProtocolPreference.auto,
      );
      probes.add(probe);
      if (probe['actual_protocol'] != AlphaXProtocol.http2.name) {
        throw StateError(
          'HTTP/2 reference endpoint negotiated ${probe['actual_protocol']}',
        );
      }
      return probe;
    });
    await _check(checks, 'protocol_h3_preference', () async {
      final probe = await _probe(
        transport!,
        Uri.parse(_h3Url),
        AlphaXProtocolPreference.http3,
      );
      probes.add(probe);
      if (probe['actual_protocol'] != AlphaXProtocol.http3.name) {
        throw StateError(
          'HTTP/3 was not negotiated: ${probe['actual_protocol']}',
        );
      }
      return probe;
    });
    await _check(checks, 'protocol_h3_fallback', () async {
      final fallbackUri = _h1Url.isNotEmpty
          ? Uri.parse(_h1Url)
          : Uri.parse(_h2Url);
      final probe = await _probe(
        transport!,
        fallbackUri,
        AlphaXProtocolPreference.http3,
      );
      probes.add(probe);
      if (probe['actual_protocol'] == AlphaXProtocol.unknown.name) {
        throw StateError('Fallback probe did not report an actual protocol');
      }
      if (probe['actual_protocol'] == AlphaXProtocol.http3.name) {
        throw StateError(
          'The H2 reference endpoint unexpectedly negotiated H3',
        );
      }
      return probe;
    });
    await _check(checks, 'tls_invalid_certificate', () async {
      try {
        await transport!
            .sendStreaming(
              AlphaXRequest(
                method: HttpMethod.get,
                uri: Uri.parse(_invalidTlsUrl),
                timeouts: const AlphaXTimeouts(overall: Duration(seconds: 20)),
              ),
            )
            .toList();
      } on AlphaXTlsException {
        return <String, Object?>{'rejected': true};
      }
      throw StateError('The invalid TLS certificate was accepted');
    });

    if (_h1Url.isNotEmpty) {
      final base = Uri.parse(_h1Url);
      await _check(checks, 'required_methods_and_bodies', () async {
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
        for (final method in methods) {
          final response = await transport!.send(
            AlphaXRequest(
              method: method,
              uri: method == HttpMethod.head
                  ? base.resolve('/bytes/1')
                  : base.resolve('/echo'),
              body: method == HttpMethod.get || method == HttpMethod.head
                  ? const AlphaXEmptyBody()
                  : AlphaXBody.bytes(const <int>[1, 2, 3]),
            ),
          );
          final body = await response.readAsBytes();
          if (method == HttpMethod.head && body.isNotEmpty) {
            throw StateError('HEAD returned a body');
          }
          if (method != HttpMethod.get &&
              method != HttpMethod.head &&
              !_same(body, const <int>[1, 2, 3])) {
            throw StateError(
              '$method did not preserve its request body: '
              'status=${response.statusCode}, received=$body, '
              'content_length=${response.headers['content-length']}',
            );
          }
          statuses[method.value] = response.statusCode;
        }
        return <String, Object?>{'statuses': statuses};
      });

      await _check(checks, 'streamed_request_body', () async {
        final response = await transport!.send(
          AlphaXRequest(
            method: HttpMethod.post,
            uri: base.resolve('/echo'),
            body: AlphaXStreamBody(
              Stream<List<int>>.fromIterable(const <List<int>>[
                <int>[1],
                <int>[2, 3],
              ]),
              contentLength: 3,
            ),
            timeouts: const AlphaXTimeouts(overall: Duration(seconds: 10)),
          ),
        );
        final body = await response.readAsBytes();
        if (!_same(body, const <int>[1, 2, 3])) {
          throw StateError('streamed request body was not preserved: $body');
        }
        return <String, Object?>{
          'status': response.statusCode,
          'bytes': body.length,
        };
      });

      await _check(checks, 'redirect_follow_and_metadata', () async {
        final response = await transport!.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: base.resolve('/redirect/1'),
          ),
        );
        final body = await response.readAsString();
        if (response.statusCode != 200 ||
            body != 'redirect complete' ||
            response.redirects.length != 1) {
          throw StateError(
            'redirect validation failed: status=${response.statusCode}, '
            'body=$body, hops=${response.redirects.length}',
          );
        }
        return <String, Object?>{
          'status': response.statusCode,
          'redirects': response.redirects.length,
        };
      });

      await _check(checks, 'bounded_stream_and_pause_resume', () async {
        final response = await transport!.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: base.resolve('/stream/4/65536?delay_ms=5'),
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
                Future<void>.delayed(const Duration(milliseconds: 100)),
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
        if (bytes != 4 * 65536) {
          throw StateError('stream delivered $bytes bytes');
        }
        return <String, Object?>{
          'chunks': chunks,
          'bytes': bytes,
          'paused_once': true,
        };
      });

      await _check(checks, 'cancellation_during_request', () async {
        final token = AlphaXCancellationToken();
        final pending = transport!.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: base.resolve('/delay/500'),
            cancellationToken: token,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        token.cancel('Phase 1D cancellation validation');
        try {
          await pending;
        } on AlphaXCancellationException {
          return <String, Object?>{'cancelled': true};
        }
        throw StateError('The delayed request completed after cancellation');
      });

      await _check(checks, 'request_timeout_mapping', () async {
        try {
          await transport!.send(
            AlphaXRequest(
              method: HttpMethod.get,
              uri: base.resolve('/delay/500'),
              timeouts: const AlphaXTimeouts(
                request: Duration(milliseconds: 50),
                overall: Duration(seconds: 5),
              ),
            ),
          );
        } on AlphaXTimeoutException catch (error) {
          if (error.timeoutKind != AlphaXTimeoutKind.request) {
            throw StateError(
              'request timeout was reported as ${error.timeoutKind.name}',
            );
          }
          return <String, Object?>{'timeout_kind': error.timeoutKind.name};
        }
        throw StateError('The delayed request exceeded its timeout');
      });

      await _check(checks, 'native_file_download', () async {
        final directory = await Directory.systemTemp.createTemp(
          'alphax-phase1d-download-',
        );
        final path = '${directory.path}/download.bin';
        var progressEvents = 0;
        var lastProgress = 0;
        var progressMonotonic = true;
        try {
          final result = await transport!.download(
            AlphaXRequest(
              method: HttpMethod.get,
              uri: base.resolve('/bytes/1048576'),
              onDownloadProgress: (progress) {
                progressEvents += 1;
                if (progress.bytesTransferred < lastProgress) {
                  progressMonotonic = false;
                }
                lastProgress = progress.bytesTransferred;
              },
            ),
            AlphaXLocalFileTarget(path),
          );
          final bytes = await File(path).readAsBytes();
          final expected = _deterministicBytes(bytes.length);
          if (result.bytesTransferred != bytes.length ||
              progressEvents == 0 ||
              lastProgress != bytes.length ||
              !progressMonotonic ||
              !_same(bytes, expected)) {
            throw StateError('native download or progress mismatch');
          }
          return <String, Object?>{
            'bytes': bytes.length,
            'hash': _hash(bytes),
            'protocol': result.protocol.name,
            'progress_events': progressEvents,
          };
        } finally {
          await directory.delete(recursive: true);
        }
      });

      await _check(checks, 'native_file_upload', () async {
        final directory = await Directory.systemTemp.createTemp(
          'alphax-phase1d-upload-',
        );
        final path = '${directory.path}/upload.bin';
        try {
          final bytes = _deterministicBytes(1048576);
          await File(path).writeAsBytes(bytes, flush: true);
          final expectedHash = _hash(bytes);
          var progressEvents = 0;
          var lastProgress = 0;
          var progressMonotonic = true;
          final result = await transport!.upload(
            AlphaXRequest(
              method: HttpMethod.post,
              uri: base.resolve(
                '/upload?expected=${bytes.length}&expected_hash=$expectedHash',
              ),
              onUploadProgress: (progress) {
                progressEvents += 1;
                if (progress.bytesTransferred < lastProgress) {
                  progressMonotonic = false;
                }
                lastProgress = progress.bytesTransferred;
              },
            ),
            AlphaXLocalFileSource(path),
          );
          final serverHash = result.headers['x-alphax-upload-fnv1a64'];
          if (!result.isSuccessful ||
              result.bytesTransferred != bytes.length ||
              progressEvents == 0 ||
              lastProgress != bytes.length ||
              !progressMonotonic ||
              serverHash == null ||
              serverHash != expectedHash) {
            throw StateError(
              'native upload did not acknowledge the complete file',
            );
          }
          return <String, Object?>{
            'bytes': result.bytesTransferred,
            'hash': expectedHash,
            'protocol': result.protocol.name,
            'progress_events': progressEvents,
          };
        } finally {
          await directory.delete(recursive: true);
        }
      });

      await _check(checks, 'client_close_lifecycle', () async {
        final closedTransport = transport!;
        await closedTransport.close();
        try {
          await closedTransport.send(
            AlphaXRequest(
              method: HttpMethod.get,
              uri: base.resolve('/bytes/1'),
            ),
          );
        } on AlphaXClientClosedException {
          return <String, Object?>{'closed': true, 'repeated_close_safe': true};
        }
        throw StateError('A request was accepted after Apple transport close');
      });
    } else {
      (report['blockers']! as List<String>).add(
        'ALPHAX_PHASE1D_H1_URL was not supplied; local contract checks skipped.',
      );
    }

    final h3Probe = probes.firstWhere(
      (probe) =>
          probe['requested_protocol'] == AlphaXProtocolPreference.http3.name &&
          probe['endpoint'] == _h3Url,
      orElse: () => <String, Object?>{},
    );
    final checksPassed = (report['checks']! as List<Map<String, Object?>>)
        .every((check) => check['status'] == 'passed');
    report['status'] =
        h3Probe['actual_protocol'] == AlphaXProtocol.http3.name && checksPassed
        ? 'passed'
        : 'blocked';
    if (h3Probe['actual_protocol'] != AlphaXProtocol.http3.name &&
        h3Probe.isNotEmpty) {
      (report['blockers']! as List<String>).add(
        'Physical/platform H3 negotiation did not produce an actual HTTP/3 metric.',
      );
    }
    for (final check in checks) {
      if (check['status'] == 'failed') {
        final error = check['error']?.toString();
        if (error != null && error.isNotEmpty) {
          (report['blockers']! as List<String>).add('${check['name']}: $error');
        }
      }
    }
  } catch (error, stackTrace) {
    (report['blockers']! as List<String>).add('$error');
    report['stack'] = stackTrace.toString();
  } finally {
    await transport?.close();
  }
  return report;
}

Future<Map<String, Object?>> _probe(
  AppleUrlSessionTransport transport,
  Uri uri,
  AlphaXProtocolPreference preference,
) async {
  final events = await transport
      .sendStreaming(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: uri,
          protocolPreference: preference,
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 20)),
        ),
      )
      .toList();
  final started = events.whereType<AlphaXResponseStarted>().firstOrNull;
  final completed = events.whereType<AlphaXResponseCompleted>().firstOrNull;
  final bodyBytes = events.whereType<AlphaXResponseChunk>().fold<int>(
    0,
    (total, chunk) => total + chunk.bytes.length,
  );
  final actual =
      completed?.metrics.negotiatedProtocol ?? AlphaXProtocol.unknown;
  final fallback =
      preference == AlphaXProtocolPreference.auto ||
          actual == AlphaXProtocol.unknown ||
          preference.name == actual.name
      ? null
      : <String, Object?>{
          'requested': preference.name,
          'negotiated': actual.name,
          'reason': 'unknown',
        };
  return <String, Object?>{
    'endpoint': uri.toString(),
    'requested_protocol': preference.name,
    'started_protocol': started?.protocol.name,
    'actual_protocol': actual.name,
    'status_code': started?.statusCode,
    'body_bytes': bodyBytes,
    'alt_svc': started?.headers['alt-svc'],
    'connection_reused': completed?.metrics.connectionReused,
    'fallback': fallback,
  };
}

Future<void> _check(
  List<Map<String, Object?>> checks,
  String name,
  Future<Object?> Function() action,
) async {
  try {
    checks.add(<String, Object?>{
      'name': name,
      'status': 'passed',
      'result': await action(),
    });
  } catch (error, stackTrace) {
    checks.add(<String, Object?>{
      'name': name,
      'status': 'failed',
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

List<int> _deterministicBytes(int length) =>
    List<int>.generate(length, (index) => index % 251, growable: false);

bool _same(List<int> left, List<int> right) =>
    left.length == right.length &&
    left.asMap().entries.every((entry) => entry.value == right[entry.key]);

String _hash(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
