import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

const _h1BaseUrl = String.fromEnvironment('ALPHAX_ANDROID_H1_URL');
const _redirectTargetUrl = String.fromEnvironment(
  'ALPHAX_ANDROID_REDIRECT_TARGET_URL',
);
const _h3PrimaryUrl = String.fromEnvironment('ALPHAX_ANDROID_H3_PRIMARY_URL');
const _h3SecondaryUrl = String.fromEnvironment(
  'ALPHAX_ANDROID_H3_SECONDARY_URL',
);
const _pinUrl = String.fromEnvironment('ALPHAX_ANDROID_PIN_URL');
const _pinHost = String.fromEnvironment('ALPHAX_ANDROID_PIN_HOST');
const _serverPin = String.fromEnvironment('ALPHAX_ANDROID_SERVER_PIN_B64');
const _pinMode = String.fromEnvironment(
  'ALPHAX_ANDROID_PIN_MODE',
  defaultValue: 'none',
);
const _googlePlayServicesVersion = String.fromEnvironment(
  'ALPHAX_GOOGLE_PLAY_SERVICES_VERSION',
  defaultValue: 'unreported',
);
const _networkType = String.fromEnvironment(
  'ALPHAX_NETWORK_TYPE',
  defaultValue: 'unreported',
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
const _wrongPin = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ReleaseGateApp());

  final result = await _runReleaseGate();
  final encoded = const JsonEncoder.withIndent('  ').convert(result);
  final resultFile = File(
    '${Directory.systemTemp.path}/alphax-phase1f-android-release.json',
  );
  await resultFile.writeAsString(encoded, flush: true);
  stdout.writeln('ALPHAX_PHASE1F_ANDROID_RESULT_FILE:${resultFile.path}');
  stdout.writeln('ALPHAX_PHASE1F_ANDROID_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_PHASE1F_ANDROID_RESULT_END');
  await Future<void>.delayed(const Duration(milliseconds: 250));
  exit(result['status'] == 'passed' ? 0 : 2);
}

final class _ReleaseGateApp extends StatelessWidget {
  const _ReleaseGateApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('AlphaX Android release validation is running.'),
      ),
    ),
  );
}

Future<Map<String, Object?>> _runReleaseGate() async {
  final checks = <Map<String, Object?>>[];
  final metadata = <String, Object?>{
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'device_model': _deviceModel,
    'architecture': _deviceArchitecture,
    'dart_version': Platform.version,
    'flutter_version': _flutterVersion,
    'build_mode': 'profile/release-equivalent correctness validation',
    'git_commit': _gitCommit,
    'network_type': _networkType,
    'google_play_services_version': _googlePlayServicesVersion,
    'h1_url': _h1BaseUrl,
    'h3_primary_url': _h3PrimaryUrl,
    'h3_secondary_url': _h3SecondaryUrl,
    'pin_host': _pinHost,
    'pin_url': _pinUrl,
    'pin_mode': _pinMode,
    'tls_policy': 'Cronet platform trust defaults; no trust-all override',
    'diagnostic_quic_hint': false,
  };

  final missing = <String>[
    if (_h1BaseUrl.isEmpty) 'ALPHAX_ANDROID_H1_URL',
    if (_redirectTargetUrl.isEmpty) 'ALPHAX_ANDROID_REDIRECT_TARGET_URL',
    if (_h3PrimaryUrl.isEmpty) 'ALPHAX_ANDROID_H3_PRIMARY_URL',
    if (_h3SecondaryUrl.isEmpty) 'ALPHAX_ANDROID_H3_SECONDARY_URL',
    if (_pinUrl.isEmpty) 'ALPHAX_ANDROID_PIN_URL',
    if (_pinHost.isEmpty) 'ALPHAX_ANDROID_PIN_HOST',
    if (_serverPin.isEmpty) 'ALPHAX_ANDROID_SERVER_PIN_B64',
  ];
  if (missing.isNotEmpty) {
    return <String, Object?>{
      'status': 'blocked_environment',
      'metadata': metadata,
      'checks': checks,
      'blockers': <String>['Missing defines: ${missing.join(', ')}'],
    };
  }

  late final AndroidCronetTransport transport;
  try {
    transport = await AndroidCronetTransport.create(
      tlsPolicy: switch (_pinMode) {
        'correct' => _pinPolicy(<String>[_serverPin]),
        'backup' => _pinPolicy(<String>[_wrongPin, _serverPin]),
        'wrong' => _pinPolicy(<String>[_wrongPin]),
        _ => const AlphaXTlsPolicy.platformDefault(),
      },
    );
    metadata['provider'] = transport.capabilities.transportName;
    metadata['provider_version'] = transport.capabilities.transportVersion;
    metadata['capabilities'] = <String, String>{
      for (final capability in AlphaXCapability.values)
        capability.name: transport.capabilities.supportFor(capability).name,
    };
  } catch (error) {
    return <String, Object?>{
      'status': 'failed',
      'metadata': metadata,
      'checks': checks,
      'blockers': <String>[
        'Cronet provider initialization failed: ${_describe(error)}',
      ],
    };
  }

  final h3Uris = <Uri>[Uri.parse(_h3PrimaryUrl), Uri.parse(_h3SecondaryUrl)];
  final h3Probes = <Map<String, Object?>>[];
  Uri? h3VerifiedUri;
  for (final uri in h3Uris) {
    final probe = await _probePreferredH3(transport, uri);
    h3Probes.add(probe);
    if (probe['actual_protocol'] == AlphaXProtocol.http3.name &&
        h3VerifiedUri == null) {
      h3VerifiedUri = uri;
    }
  }
  checks.add(<String, Object?>{
    'name': 'h3_live_negotiation',
    'status': h3VerifiedUri == null ? 'blocked_environment' : 'passed',
    'result': <String, Object?>{
      'probes': h3Probes,
      'verified_endpoint': h3VerifiedUri?.toString(),
      'requirement': 'actual Cronet HTTP/3 metadata and AlphaX HTTP/3 report',
    },
    if (h3VerifiedUri == null)
      'error':
          'No probe negotiated HTTP/3; lower-protocol fallback was observed or the endpoint failed.',
  });

  if (h3VerifiedUri == null) {
    checks.add(<String, Object?>{
      'name': 'h3_protocol_requirement_succeeds',
      'status': 'blocked_environment',
      'result': <String, Object?>{
        'reason':
            'No live H3 path was available to exercise the success branch.',
      },
    });
  } else {
    await _record(checks, 'h3_protocol_requirement_succeeds', () async {
      final response = await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: h3VerifiedUri!,
          protocolPreference: AlphaXProtocolPreference.http3,
          protocolRequirement: AlphaXProtocolRequirement.http3,
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
        ),
      );
      await response.readAsBytes();
      final completion = await response.completionMetrics;
      if (completion.negotiatedProtocol != AlphaXProtocol.http3) {
        throw StateError(
          'H3 requirement completed as ${completion.negotiatedProtocol.name}',
        );
      }
      return <String, Object?>{
        'requested_protocol': AlphaXProtocolRequirement.http3.name,
        'actual_protocol': completion.negotiatedProtocol.name,
      };
    });
  }

  await _record(checks, 'h3_protocol_requirement_fails_on_h1', () async {
    try {
      await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_h1BaseUrl).resolve('bytes/1'),
          protocolPreference: AlphaXProtocolPreference.http3,
          protocolRequirement: AlphaXProtocolRequirement.http3,
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 15)),
        ),
      );
    } on AlphaXProtocolRequirementException catch (error) {
      return <String, Object?>{
        'error_type': error.runtimeType.toString(),
        'required_protocol': error.requiredProtocol.name,
        'actual_protocol': error.actualProtocol.name,
      };
    }
    throw StateError('H3 requirement accepted a non-H3 response');
  });

  await _record(checks, 'h3_preference_falls_back_truthfully', () async {
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse(_h1BaseUrl).resolve('bytes/1'),
        protocolPreference: AlphaXProtocolPreference.http3,
        timeouts: const AlphaXTimeouts(overall: Duration(seconds: 15)),
      ),
    );
    await response.readAsBytes();
    final completion = await response.completionMetrics;
    if (completion.negotiatedProtocol == AlphaXProtocol.http3) {
      throw StateError('The H1 fixture unexpectedly negotiated H3');
    }
    return <String, Object?>{
      'requested_protocol': AlphaXProtocolPreference.http3.name,
      'actual_protocol': completion.negotiatedProtocol.name,
      'response_fallback': response.protocolFallback?.negotiated.name,
    };
  });

  if (_pinMode == 'correct') {
    await _record(checks, 'correct_spki_pin_succeeds', () async {
      final response = await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_pinUrl),
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
        ),
      );
      final body = await response.readAsBytes();
      if (response.statusCode < 200 ||
          response.statusCode >= 400 ||
          body.isEmpty) {
        throw StateError('Pinned request returned an invalid response');
      }
      return <String, Object?>{
        'status_code': response.statusCode,
        'protocol': (await response.completionMetrics).negotiatedProtocol.name,
      };
    });
  }

  if (_pinMode == 'backup') {
    await _record(checks, 'backup_spki_pin_succeeds', () async {
      final response = await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_pinUrl),
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
        ),
      );
      await response.readAsBytes();
      return <String, Object?>{
        'status_code': response.statusCode,
        'backup_pin_used': true,
      };
    });
  }

  if (_pinMode == 'wrong') {
    await _record(checks, 'incorrect_spki_pin_fails', () async {
      try {
        final response = await transport.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: Uri.parse(_pinUrl),
            timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
          ),
        );
        await response.readAsBytes();
      } on AlphaXCertificatePinMismatchException catch (error) {
        return <String, Object?>{'error_type': error.runtimeType.toString()};
      }
      throw StateError('Incorrect SPKI pin was accepted');
    });
  }

  await _record(checks, 'cross_origin_sensitive_redirect_is_safe', () async {
    final base = Uri.parse(_h1BaseUrl);
    final target = Uri.parse(_redirectTargetUrl);
    final redirectUri = base.resolve(
      'redirect-cross-origin?to=${Uri.encodeQueryComponent(target.toString())}',
    );
    try {
      final response = await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: redirectUri,
          headers: AlphaXHeaders(<String, String>{
            'Authorization': 'Bearer phase1f-android-test-token',
            'Proxy-Authorization': 'Basic phase1f-android-test-credentials',
            'Cookie': 'session=phase1f-android-test-cookie',
          }),
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 15)),
        ),
      );
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      if (body['authorization_present'] == true ||
          body['proxy_authorization_present'] == true ||
          body['cookie_present'] == true) {
        throw StateError('Sensitive header reached the cross-origin target');
      }
      return <String, Object?>{'mode': 'followed_without_sensitive_headers'};
    } on AlphaXRedirectException {
      return <String, Object?>{'mode': 'secure_rejection'};
    }
  });

  await _record(checks, 'cancellation_sanity', () async {
    final token = AlphaXCancellationToken();
    final future = transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse(_h1BaseUrl).resolve('delay/5000'),
        cancellationToken: token,
        timeouts: const AlphaXTimeouts(overall: Duration(seconds: 15)),
      ),
    );
    Timer(const Duration(milliseconds: 150), token.cancel);
    try {
      await future;
    } on AlphaXCancellationException {
      return <String, Object?>{'cancelled': true};
    }
    throw StateError('Delayed request completed instead of cancellation');
  });

  await _record(checks, 'file_transfer_sanity', () async {
    final directory = await Directory.systemTemp.createTemp(
      'alphax-phase1f-android-',
    );
    final sourcePath = '${directory.path}/upload.bin';
    final targetPath = '${directory.path}/download.bin';
    try {
      final expected = _deterministicBytes(1024 * 1024, 0);
      await File(sourcePath).writeAsBytes(expected, flush: true);
      final download = await transport.download(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_h1BaseUrl).resolve('bytes/1048576'),
        ),
        AlphaXLocalFileTarget(targetPath),
      );
      final downloaded = await File(targetPath).readAsBytes();
      if (download.statusCode != HttpStatus.ok ||
          downloaded.length != expected.length ||
          _fnv1a64(downloaded) != _fnv1a64(expected)) {
        throw StateError('Native download hash or size mismatch');
      }
      final upload = await transport.upload(
        AlphaXRequest(
          method: HttpMethod.post,
          uri: Uri.parse(_h1BaseUrl).resolve('upload'),
          headers: AlphaXHeaders(<String, String>{
            'content-type': 'application/octet-stream',
          }),
        ),
        AlphaXLocalFileSource(sourcePath),
      );
      if (upload.statusCode != HttpStatus.ok ||
          upload.bytesTransferred != expected.length) {
        throw StateError('Native upload size or status mismatch');
      }
      return <String, Object?>{
        'download_status': download.statusCode,
        'download_bytes': downloaded.length,
        'download_hash': _fnv1a64(downloaded),
        'upload_bytes': upload.bytesTransferred,
        'upload_status': upload.statusCode,
      };
    } finally {
      await directory.delete(recursive: true);
    }
  });

  await _record(checks, 'close_and_reuse_sanity', () async {
    final first = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse(_h1BaseUrl).resolve('bytes/1'),
      ),
    );
    await first.readAsBytes();
    final second = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: Uri.parse(_h1BaseUrl).resolve('bytes/1'),
      ),
    );
    await second.readAsBytes();
    await _closeWithDeadline(transport);
    await _closeWithDeadline(transport);
    try {
      await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_h1BaseUrl).resolve('bytes/1'),
        ),
      );
    } on AlphaXClientClosedException {
      return <String, Object?>{
        'sequential_requests': 2,
        'repeated_close': true,
        'post_close_rejected': true,
      };
    }
    throw StateError('Request after close was accepted');
  });

  await _closeWithDeadline(transport);

  final hasFailure = checks.any((check) => check['status'] == 'failed');
  final h3Blocked = checks.any(
    (check) =>
        check['name'] == 'h3_live_negotiation' &&
        check['status'] == 'blocked_environment',
  );
  return <String, Object?>{
    'status': hasFailure
        ? 'failed'
        : h3Blocked
        ? 'blocked_environment'
        : 'passed',
    'metadata': metadata,
    'checks': checks,
    'blockers': <String>[
      if (h3Blocked)
        'No actual HTTP/3 negotiation was observed on the tested network paths.',
      for (final check in checks.where((check) => check['status'] == 'failed'))
        '${check['name']}: ${check['error']}',
    ],
  };
}

Future<Map<String, Object?>> _probePreferredH3(
  AndroidCronetTransport transport,
  Uri uri,
) async {
  try {
    final response = await transport
        .send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: uri,
            protocolPreference: AlphaXProtocolPreference.http3,
            timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
          ),
        )
        .timeout(const Duration(seconds: 40));
    final body = await response.readAsBytes().timeout(
      const Duration(seconds: 40),
    );
    final completion = await response.completionMetrics.timeout(
      const Duration(seconds: 5),
    );
    return <String, Object?>{
      'endpoint': uri.toString(),
      'status_code': response.statusCode,
      'body_bytes': body.length,
      'requested_protocol': AlphaXProtocolPreference.http3.name,
      'initial_protocol': response.negotiatedProtocol.name,
      'actual_protocol': completion.negotiatedProtocol.name,
      'alphax_reported_protocol': completion.negotiatedProtocol.name,
      'fallback': response.protocolFallback == null
          ? null
          : <String, Object?>{
              'requested': response.protocolFallback!.requested.name,
              'negotiated': response.protocolFallback!.negotiated.name,
              'reason': response.protocolFallback!.reason.name,
            },
      'alt_svc': response.headers['alt-svc'],
    };
  } catch (error) {
    return <String, Object?>{
      'endpoint': uri.toString(),
      'requested_protocol': AlphaXProtocolPreference.http3.name,
      'error_type': error.runtimeType.toString(),
      'error': _describe(error),
    };
  }
}

Future<void> _closeWithDeadline(AlphaXTransport transport) async {
  try {
    await transport.close().timeout(const Duration(seconds: 5));
  } on TimeoutException {
    // A stalled external QUIC teardown must not prevent the focused report
    // from recording the probe as an environment/provider timeout.
  }
}

AlphaXTlsPolicy _pinPolicy(List<String> pins) => AlphaXTlsPolicy(
  pins: <AlphaXSpkiPin>[
    for (final digest in pins)
      AlphaXSpkiPin(
        host: _pinHost,
        sha256SpkiBase64: digest,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 3)),
      ),
  ],
);

Future<void> _record(
  List<Map<String, Object?>> checks,
  String name,
  Future<Map<String, Object?>> Function() action,
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
      'error': _describe(error),
      'stack': stackTrace.toString(),
    });
  }
}

String _describe(Object error) => error is AlphaXException
    ? '${error.runtimeType} (${error.kind.name}): ${error.message}'
    : '${error.runtimeType}: $error';

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
