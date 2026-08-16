import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

const _tlsUrl = String.fromEnvironment('ALPHAX_PHASE1F_TLS_URL');
const _untrustedTlsUrl = String.fromEnvironment(
  'ALPHAX_PHASE1F_UNTRUSTED_TLS_URL',
);
const _redirectUrl = String.fromEnvironment('ALPHAX_PHASE1F_REDIRECT_URL');
const _h1Url = String.fromEnvironment('ALPHAX_PHASE1F_H1_URL');
const _h3Url = String.fromEnvironment('ALPHAX_PHASE1F_H3_URL');
const _tlsHost = String.fromEnvironment('ALPHAX_PHASE1F_TLS_HOST');
const _caDer = String.fromEnvironment('ALPHAX_PHASE1F_CA_DER_B64');
const _wrongCaDer = String.fromEnvironment('ALPHAX_PHASE1F_WRONG_CA_DER_B64');
const _serverPin = String.fromEnvironment('ALPHAX_PHASE1F_SERVER_PIN_B64');
const _wrongPin = String.fromEnvironment('ALPHAX_PHASE1F_WRONG_PIN_B64');
const _untrustedPin = String.fromEnvironment(
  'ALPHAX_PHASE1F_UNTRUSTED_PIN_B64',
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
  runApp(const _ValidationApp());

  final result = await _runValidation();
  final encoded = const JsonEncoder.withIndent('  ').convert(result);
  final resultFile = File(
    '${Directory.systemTemp.path}/alphax-phase1f-apple-security.json',
  );
  await resultFile.writeAsString(encoded, flush: true);
  stdout.writeln(
    'ALPHAX_PHASE1F_APPLE_SECURITY_RESULT_FILE:${resultFile.path}',
  );
  stdout.writeln('ALPHAX_PHASE1F_APPLE_SECURITY_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_PHASE1F_APPLE_SECURITY_RESULT_END');
  await Future<void>.delayed(const Duration(milliseconds: 250));
  exit(result['status'] == 'passed' ? 0 : 1);
}

final class _ValidationApp extends StatelessWidget {
  const _ValidationApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('AlphaX Apple security validation is running.')),
    ),
  );
}

Future<Map<String, Object?>> _runValidation() async {
  final checks = <Map<String, Object?>>[];
  final metadata = <String, Object?>{
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'device_model': _deviceModel,
    'architecture': _deviceArchitecture,
    'dart_version': Platform.version,
    'build_mode': 'profile correctness validation; no performance data',
    'git_commit': _gitCommit,
    'tls_endpoint': _tlsUrl,
    'untrusted_tls_endpoint': _untrustedTlsUrl,
    'redirect_endpoint': _redirectUrl,
    'protocol_requirement_h1_endpoint': _h1Url,
    'protocol_requirement_h3_endpoint': _h3Url,
    'tls_policy':
        'platform trust remains enabled unless explicitly replaced by the test anchor; hostname and validity checks remain enabled',
    'pin_policy': 'SPKI SHA-256 pinning after normal trust validation',
  };

  final missing = <String>[
    if (_tlsUrl.isEmpty) 'ALPHAX_PHASE1F_TLS_URL',
    if (_untrustedTlsUrl.isEmpty) 'ALPHAX_PHASE1F_UNTRUSTED_TLS_URL',
    if (_redirectUrl.isEmpty) 'ALPHAX_PHASE1F_REDIRECT_URL',
    if (_h1Url.isEmpty) 'ALPHAX_PHASE1F_H1_URL',
    if (_h3Url.isEmpty) 'ALPHAX_PHASE1F_H3_URL',
    if (_tlsHost.isEmpty) 'ALPHAX_PHASE1F_TLS_HOST',
    if (_caDer.isEmpty) 'ALPHAX_PHASE1F_CA_DER_B64',
    if (_wrongCaDer.isEmpty) 'ALPHAX_PHASE1F_WRONG_CA_DER_B64',
    if (_serverPin.isEmpty) 'ALPHAX_PHASE1F_SERVER_PIN_B64',
    if (_wrongPin.isEmpty) 'ALPHAX_PHASE1F_WRONG_PIN_B64',
    if (_untrustedPin.isEmpty) 'ALPHAX_PHASE1F_UNTRUSTED_PIN_B64',
  ];
  if (missing.isNotEmpty) {
    return <String, Object?>{
      'status': 'blocked',
      'metadata': metadata,
      'checks': checks,
      'blockers': <String>['Missing validation defines: ${missing.join(', ')}'],
    };
  }

  await _check(checks, 'h3_protocol_requirement_succeeds', () async {
    final transport = await AppleUrlSessionTransport.create();
    try {
      final preferenceResponse = await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_h3Url),
          protocolPreference: AlphaXProtocolPreference.http3,
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
        ),
      );
      await preferenceResponse.readAsBytes();
      final preferenceMetrics = await preferenceResponse.completionMetrics;
      if (preferenceMetrics.negotiatedProtocol != AlphaXProtocol.http3) {
        throw StateError(
          'H3 discovery completed as ${preferenceMetrics.negotiatedProtocol.name}',
        );
      }

      final requiredResponse = await transport.send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_h3Url),
          protocolPreference: AlphaXProtocolPreference.http3,
          protocolRequirement: AlphaXProtocolRequirement.http3,
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
        ),
      );
      await requiredResponse.readAsBytes();
      final completion = await requiredResponse.completionMetrics;
      if (completion.negotiatedProtocol != AlphaXProtocol.http3) {
        throw StateError(
          'required HTTP/3 completed as ${completion.negotiatedProtocol.name}',
        );
      }
      return <String, Object?>{
        'discovery_protocol': preferenceMetrics.negotiatedProtocol.name,
        'required_protocol': completion.negotiatedProtocol.name,
      };
    } finally {
      await transport.close();
    }
  });

  await _check(checks, 'default_trust_rejects_test_ca', () async {
    await _expectFailure(
      () => _get(
        Uri.parse(_tlsUrl),
        tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
      ),
      expected: AlphaXTlsException,
      message: 'default platform trust accepted the generated test CA',
    );
    return <String, Object?>{'rejected': true};
  });

  await _check(checks, 'custom_ca_succeeds', () async {
    final response = await _get(
      Uri.parse(_tlsUrl),
      tlsPolicy: AlphaXTlsPolicy(
        includePlatformTrust: false,
        trustAnchors: <AlphaXTrustAnchor>[
          AlphaXTrustAnchor.der(_decode(_caDer)),
        ],
      ),
    );
    if (response.statusCode != HttpStatus.ok || response.body.isEmpty) {
      throw StateError('custom trust request returned an invalid response');
    }
    return <String, Object?>{'status': response.statusCode};
  });

  await _check(checks, 'incorrect_custom_ca_fails', () async {
    await _expectFailure(
      () => _get(
        Uri.parse(_tlsUrl),
        tlsPolicy: AlphaXTlsPolicy(
          includePlatformTrust: false,
          trustAnchors: <AlphaXTrustAnchor>[
            AlphaXTrustAnchor.der(_decode(_wrongCaDer)),
          ],
        ),
      ),
      expected: AlphaXTlsException,
      message: 'incorrect custom trust anchor was accepted',
    );
    return <String, Object?>{'rejected': true};
  });

  await _check(checks, 'correct_spki_pin_succeeds', () async {
    final response = await _get(
      Uri.parse(_tlsUrl),
      tlsPolicy: _pinnedPolicy(<String>[_serverPin]),
    );
    if (response.statusCode != HttpStatus.ok || response.body.isEmpty) {
      throw StateError('correct SPKI pin request returned an invalid response');
    }
    return <String, Object?>{'status': response.statusCode};
  });

  await _check(checks, 'backup_spki_pin_succeeds', () async {
    final response = await _get(
      Uri.parse(_tlsUrl),
      tlsPolicy: _pinnedPolicy(<String>[_wrongPin, _serverPin]),
    );
    if (response.statusCode != HttpStatus.ok || response.body.isEmpty) {
      throw StateError('backup SPKI pin request returned an invalid response');
    }
    return <String, Object?>{'status': response.statusCode};
  });

  await _check(checks, 'incorrect_spki_pin_fails', () async {
    await _expectFailure(
      () => _get(
        Uri.parse(_tlsUrl),
        tlsPolicy: _pinnedPolicy(<String>[_wrongPin]),
      ),
      expected: AlphaXCertificatePinMismatchException,
      message: 'incorrect SPKI pin was accepted',
    );
    return <String, Object?>{'rejected': true};
  });

  await _check(checks, 'pin_does_not_trust_untrusted_certificate', () async {
    await _expectFailure(
      () => _get(
        Uri.parse(_untrustedTlsUrl),
        tlsPolicy: AlphaXTlsPolicy(pins: <AlphaXSpkiPin>[_pin(_untrustedPin)]),
      ),
      expected: AlphaXTlsException,
      message: 'a matching pin made an untrusted certificate valid',
    );
    return <String, Object?>{'rejected': true};
  });

  await _check(checks, 'h3_protocol_requirement_fails_on_h1', () async {
    await _expectFailure(
      () => _get(
        Uri.parse(_h1Url),
        request: AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.parse(_h1Url),
          protocolPreference: AlphaXProtocolPreference.http3,
          protocolRequirement: AlphaXProtocolRequirement.http3,
        ),
      ),
      expected: AlphaXProtocolRequirementException,
      message: 'HTTP/3 requirement unexpectedly accepted HTTP/1.1',
    );
    return <String, Object?>{'rejected': true};
  });

  await _check(checks, 'cross_origin_sensitive_redirect_is_safe', () async {
    final transport = await AppleUrlSessionTransport.create();
    try {
      try {
        final response = await transport.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: Uri.parse(_redirectUrl),
            headers: AlphaXHeaders(<String, String>{
              'Authorization': 'Bearer phase1f-test-token',
              'Proxy-Authorization': 'Basic phase1f-test-credentials',
              'Cookie': 'session=phase1f-test-cookie',
            }),
          ),
        );
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        if (response.statusCode != HttpStatus.ok ||
            body['authorization_present'] == true ||
            body['proxy_authorization_present'] == true ||
            body['cookie_present'] == true) {
          throw StateError('sensitive header reached the cross-origin target');
        }
        return <String, Object?>{
          'mode': 'followed_with_sensitive_headers_removed',
        };
      } on AlphaXRedirectException {
        return <String, Object?>{'mode': 'secure_rejection'};
      }
    } finally {
      await transport.close();
    }
  });

  final failures = checks.where((check) => check['status'] != 'passed');
  return <String, Object?>{
    'status': failures.isEmpty ? 'passed' : 'failed',
    'metadata': metadata,
    'checks': checks,
    'blockers': <String>[
      for (final failure in failures) '${failure['name']}: ${failure['error']}',
    ],
  };
}

Future<_ObservedResponse> _get(
  Uri uri, {
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXRequest? request,
}) async {
  final transport = await AppleUrlSessionTransport.create(tlsPolicy: tlsPolicy);
  try {
    final response = await transport.send(
      request ?? AlphaXRequest(method: HttpMethod.get, uri: uri),
    );
    final body = await response.readAsBytes();
    return _ObservedResponse(
      statusCode: response.statusCode,
      body: body,
      completionMetrics: await response.completionMetrics,
    );
  } finally {
    await transport.close();
  }
}

AlphaXTlsPolicy _pinnedPolicy(List<String> digests) => AlphaXTlsPolicy(
  includePlatformTrust: false,
  trustAnchors: <AlphaXTrustAnchor>[AlphaXTrustAnchor.der(_decode(_caDer))],
  pins: <AlphaXSpkiPin>[for (final digest in digests) _pin(digest)],
);

AlphaXSpkiPin _pin(String digest) => AlphaXSpkiPin(
  host: _tlsHost,
  sha256SpkiBase64: base64Encode(_decode(digest)),
  expiresAt: DateTime.now().add(const Duration(days: 1)),
);

List<int> _decode(String value) => base64Decode(value);

Future<void> _expectFailure(
  Future<Object?> Function() action, {
  required Type expected,
  required String message,
}) async {
  try {
    await action();
  } catch (error) {
    if (error.runtimeType == expected ||
        (expected == AlphaXTlsException && error is AlphaXTlsException) ||
        (expected == AlphaXCertificatePinMismatchException &&
            error is AlphaXCertificatePinMismatchException) ||
        (expected == AlphaXProtocolRequirementException &&
            error is AlphaXProtocolRequirementException)) {
      return;
    }
    rethrow;
  }
  throw StateError(message);
}

final class _ObservedResponse {
  const _ObservedResponse({
    required this.statusCode,
    required this.body,
    required this.completionMetrics,
  });

  final int statusCode;
  final List<int> body;
  final AlphaXRequestMetrics completionMetrics;
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
