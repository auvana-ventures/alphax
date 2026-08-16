import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _primaryUrl = String.fromEnvironment(
  'ALPHAX_H3_PRIMARY_URL',
  defaultValue: 'https://cloudflare-quic.com/',
);
const _secondaryUrl = String.fromEnvironment(
  'ALPHAX_H3_SECONDARY_URL',
  defaultValue: 'https://www.google.com/',
);
const _networkType = String.fromEnvironment(
  'ALPHAX_NETWORK_TYPE',
  defaultValue: 'runtime-unspecified',
);
const _networkMode = String.fromEnvironment(
  'ALPHAX_NETWORK_MODE',
  defaultValue: 'cellular',
);
const _deviceModel = String.fromEnvironment(
  'ALPHAX_DEVICE_MODEL',
  defaultValue: 'runtime-unspecified',
);
const _deviceArchitecture = String.fromEnvironment(
  'ALPHAX_DEVICE_ARCH',
  defaultValue: 'runtime-unspecified',
);
const _flutterVersion = String.fromEnvironment(
  'ALPHAX_FLUTTER_VERSION',
  defaultValue: 'runtime-unspecified',
);
const _gitCommit = String.fromEnvironment(
  'ALPHAX_GIT_COMMIT',
  defaultValue: 'runtime-unspecified',
);

const _reportFileName = 'alphax-phase1f-h3-release.json';
const _h3DiscoveryDelay = Duration(seconds: 1);
const _androidNetworkChannel = MethodChannel('alphax_mobile_gate/network');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = ValueNotifier<String>(
    Platform.isAndroid && _networkMode == 'cellular'
        ? 'Selecting cellular data, then running the two H3 checks…'
        : 'Running the two H3 checks…',
  );
  runApp(_H3SelfCheckApp(status: status));

  try {
    final result = await _runH3SelfCheck();
    final persisted = await _persistReport(result);
    final reportPath = persisted.appPath;
    final reportLocation = _reportLocation(persisted);
    final statusText = switch (result['status']) {
      'passed' => 'H3 checks passed. $reportLocation',
      'blocked_environment' =>
        'H3 checks need another network path. $reportLocation',
      _ => 'H3 checks failed. $reportLocation',
    };
    status.value = statusText;
    _emitReport(result, reportPath);
  } catch (error, stackTrace) {
    final result = <String, Object?>{
      'status': 'failed',
      'error': error.toString(),
      'stack': stackTrace.toString(),
    };
    final persisted = await _persistReport(result);
    final reportPath = persisted.appPath;
    status.value = 'H3 runner failed. ${_reportLocation(persisted)}';
    _emitReport(result, reportPath);
  }
}

final class _H3SelfCheckApp extends StatelessWidget {
  const _H3SelfCheckApp({required this.status});

  final ValueNotifier<String> status;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('AlphaX H3 release check')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, value, child) => SelectableText(value),
          ),
        ),
      ),
    ),
  );
}

Future<Map<String, Object?>> _runH3SelfCheck() async {
  final metadata = <String, Object?>{
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'device_model': _deviceModel,
    'architecture': _deviceArchitecture,
    'dart_version': Platform.version,
    'flutter_version': _flutterVersion,
    'build_mode': 'profile/release-equivalent focused validation',
    'git_commit': _gitCommit,
    'network_type_configured': _networkType,
    'network_selection_mode': _networkMode,
    'endpoints': <String>[_primaryUrl, _secondaryUrl],
    'diagnostic_quic_hint': false,
    'tls_policy': 'platform trust defaults; no trust-all override',
  };

  final networkSelection = await _selectNetworkPath();
  metadata['network_selection'] = networkSelection;
  final runtimeNetwork = _asObjectMap(networkSelection['runtime']);
  final networkReady =
      networkSelection['status'] == 'bound' &&
      runtimeNetwork['active'] == true &&
      runtimeNetwork['validated'] == true &&
      runtimeNetwork['internet'] == true &&
      runtimeNetwork['not_restricted'] == true;
  if (Platform.isAndroid && _networkMode != 'system' && !networkReady) {
    await _restoreNetworkPath();
    return <String, Object?>{
      'status': 'blocked_environment',
      'metadata': metadata,
      'checks': <Map<String, Object?>>[],
      'blockers': <String>[
        'The requested Android network path was not active, validated, and unrestricted; no H3 probe was run.',
      ],
    };
  }

  AlphaXTransport? transport;
  try {
    transport = await _createTransport();
    metadata['provider'] = transport.capabilities.transportName;
    metadata['provider_version'] = transport.capabilities.transportVersion;
    metadata['capabilities'] = <String, String>{
      for (final capability in AlphaXCapability.values)
        capability.name: transport.capabilities.supportFor(capability).name,
    };
  } catch (error, stackTrace) {
    return <String, Object?>{
      'status': 'failed',
      'metadata': metadata,
      'checks': <Map<String, Object?>>[],
      'blockers': <String>[
        'Transport initialization failed: ${_describe(error)}',
      ],
      'stack': stackTrace.toString(),
    };
  }

  try {
    final preference = await _runPreferenceCheck(transport);
    final verifiedEndpoint = preference['verified_endpoint'] as String?;
    final requirement = await _runRequirementCheck(
      transport,
      verifiedEndpoint == null
          ? Uri.parse(_primaryUrl)
          : Uri.parse(verifiedEndpoint),
      hasVerifiedH3: verifiedEndpoint != null,
    );

    final checks = <String, Object?>{
      'h3_preference': preference,
      'h3_requirement': requirement,
    };
    final preferencePassed = preference['status'] == 'passed';
    final requirementPassed = requirement['status'] == 'passed';
    final environmentBlocked =
        preference['status'] == 'blocked_environment' ||
        requirement['status'] == 'blocked_environment';
    return <String, Object?>{
      'status': preferencePassed && requirementPassed
          ? 'passed'
          : environmentBlocked
          ? 'blocked_environment'
          : 'failed',
      'metadata': metadata,
      'checks': checks,
      'blockers': <String>[
        if (!preferencePassed && environmentBlocked)
          'No tested endpoint negotiated HTTP/3 after an Alt-Svc prewarm/retry sequence on this network path.',
        if (!requirementPassed && environmentBlocked)
          'HTTP/3 requirement could not be proven without actual HTTP/3 negotiation.',
      ],
    };
  } finally {
    await _closeWithDeadline(transport);
    await _restoreNetworkPath();
  }
}

Future<Map<String, Object?>> _selectNetworkPath() async {
  if (!Platform.isAndroid) {
    return <String, Object?>{
      'status': 'not_applicable',
      'requested': _networkMode,
    };
  }
  if (_networkMode == 'system') {
    try {
      return <String, Object?>{
        'status': 'observed',
        'requested': 'system',
        'runtime': _asObjectMap(
          await _androidNetworkChannel.invokeMethod<Object?>('activeNetwork'),
        ),
      };
    } catch (error, stackTrace) {
      return <String, Object?>{
        'status': 'failed',
        'requested': 'system',
        'error': _describe(error),
        'stack': stackTrace.toString(),
      };
    }
  }
  if (_networkMode != 'cellular') {
    return <String, Object?>{
      'status': 'failed',
      'requested': _networkMode,
      'error': 'Unsupported Android network selection mode: $_networkMode',
    };
  }
  try {
    return <String, Object?>{
      'status': 'bound',
      'requested': 'cellular',
      'runtime': _asObjectMap(
        await _androidNetworkChannel.invokeMethod<Object?>('bindCellular'),
      ),
    };
  } on PlatformException catch (error, stackTrace) {
    return <String, Object?>{
      'status': 'failed',
      'requested': 'cellular',
      'error_code': error.code,
      'error': error.message ?? error.toString(),
      'details': error.details,
      'stack': stackTrace.toString(),
    };
  } catch (error, stackTrace) {
    return <String, Object?>{
      'status': 'failed',
      'requested': 'cellular',
      'error': _describe(error),
      'stack': stackTrace.toString(),
    };
  }
}

Future<void> _restoreNetworkPath() async {
  if (!Platform.isAndroid || _networkMode != 'cellular') return;
  try {
    await _androidNetworkChannel.invokeMethod<Object?>('restoreDefault');
  } catch (_) {
    // The process is ending after a focused disposable check; report retention
    // is more important than a best-effort network restoration call here.
  }
}

Future<AlphaXTransport> _createTransport() {
  if (Platform.isAndroid) {
    return AndroidCronetTransport.create();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return AppleUrlSessionTransport.create();
  }
  throw UnsupportedError(
    'The self-contained H3 runner supports Android, iOS, and macOS only.',
  );
}

Future<Map<String, Object?>> _runPreferenceCheck(
  AlphaXTransport transport,
) async {
  final probes = <Map<String, Object?>>[];
  String? verifiedEndpoint;
  for (final endpoint in <Uri>[
    Uri.parse(_primaryUrl),
    Uri.parse(_secondaryUrl),
  ]) {
    final probe = await _probePreferredH3(transport, endpoint);
    probes.add(probe);
    if (probe['actual_protocol'] == AlphaXProtocol.http3.name) {
      verifiedEndpoint = endpoint.toString();
      break;
    }
  }
  return <String, Object?>{
    'status': verifiedEndpoint == null ? 'blocked_environment' : 'passed',
    'probes': probes,
    'verified_endpoint': verifiedEndpoint,
    'required_actual_protocol': AlphaXProtocol.http3.name,
  };
}

Future<Map<String, Object?>> _runRequirementCheck(
  AlphaXTransport transport,
  Uri endpoint, {
  required bool hasVerifiedH3,
}) async {
  try {
    final response = await transport
        .send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: endpoint,
            protocolPreference: AlphaXProtocolPreference.http3,
            protocolRequirement: AlphaXProtocolRequirement.http3,
            timeouts: const AlphaXTimeouts(overall: Duration(seconds: 40)),
          ),
        )
        .timeout(const Duration(seconds: 50));
    final body = await response.readAsBytes().timeout(
      const Duration(seconds: 50),
    );
    final completion = await response.completionMetrics.timeout(
      const Duration(seconds: 10),
    );
    final actual = completion.negotiatedProtocol;
    if (actual != AlphaXProtocol.http3) {
      return <String, Object?>{
        'status': 'failed',
        'endpoint': endpoint.toString(),
        'required_protocol': AlphaXProtocolRequirement.http3.name,
        'actual_protocol': actual.name,
        'alphax_reported_protocol': actual.name,
        'body_bytes': body.length,
        'error': 'A lower protocol was accepted for an HTTP/3 requirement.',
      };
    }
    return <String, Object?>{
      'status': 'passed',
      'endpoint': endpoint.toString(),
      'required_protocol': AlphaXProtocolRequirement.http3.name,
      'actual_protocol': actual.name,
      'alphax_reported_protocol': actual.name,
      'body_bytes': body.length,
    };
  } on AlphaXProtocolRequirementException catch (error) {
    return <String, Object?>{
      'status': hasVerifiedH3 ? 'failed' : 'blocked_environment',
      'endpoint': endpoint.toString(),
      'required_protocol': error.requiredProtocol.name,
      'actual_protocol': error.actualProtocol.name,
      'error_type': error.runtimeType.toString(),
      'error': _describe(error),
    };
  } catch (error, stackTrace) {
    return <String, Object?>{
      'status': hasVerifiedH3 ? 'failed' : 'blocked_environment',
      'endpoint': endpoint.toString(),
      'error_type': error.runtimeType.toString(),
      'error': _describe(error),
      'stack': stackTrace.toString(),
    };
  }
}

Future<Map<String, Object?>> _probePreferredH3(
  AlphaXTransport transport,
  Uri endpoint,
) async {
  try {
    final prewarm = await _readProtocolProbe(transport, endpoint);
    await Future<void>.delayed(_h3DiscoveryDelay);
    final retry = await _readProtocolProbe(
      transport,
      endpoint,
      preference: AlphaXProtocolPreference.http3,
    );
    return <String, Object?>{
      'endpoint': endpoint.toString(),
      'status_code': retry['status_code'],
      'body_bytes': retry['body_bytes'],
      'requested_protocol': AlphaXProtocolPreference.http3.name,
      'initial_protocol': retry['initial_protocol'],
      'actual_protocol': retry['actual_protocol'],
      'alphax_reported_protocol': retry['actual_protocol'],
      'protocol_fallback': retry['protocol_fallback'],
      'alt_svc': retry['alt_svc'],
      'discovery': <String, Object?>{
        'prewarm': prewarm,
        'retry_delay_ms': _h3DiscoveryDelay.inMilliseconds,
        'retry': retry,
      },
    };
  } catch (error, stackTrace) {
    return <String, Object?>{
      'endpoint': endpoint.toString(),
      'requested_protocol': AlphaXProtocolPreference.http3.name,
      'error_type': error.runtimeType.toString(),
      'error': _describe(error),
      'stack': stackTrace.toString(),
    };
  }
}

Future<Map<String, Object?>> _readProtocolProbe(
  AlphaXTransport transport,
  Uri endpoint, {
  AlphaXProtocolPreference? preference,
}) async {
  final response = await transport
      .send(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: endpoint,
          protocolPreference: preference ?? AlphaXProtocolPreference.auto,
          timeouts: const AlphaXTimeouts(overall: Duration(seconds: 40)),
        ),
      )
      .timeout(const Duration(seconds: 50));
  final body = await response.readAsBytes().timeout(
    const Duration(seconds: 50),
  );
  final completion = await response.completionMetrics.timeout(
    const Duration(seconds: 10),
  );
  final actual = completion.negotiatedProtocol;
  return <String, Object?>{
    'status_code': response.statusCode,
    'body_bytes': body.length,
    'initial_protocol': response.negotiatedProtocol.name,
    'actual_protocol': actual.name,
    'protocol_fallback': response.protocolFallback == null
        ? null
        : <String, Object?>{
            'requested': response.protocolFallback!.requested.name,
            'negotiated': response.protocolFallback!.negotiated.name,
            'reason': response.protocolFallback!.reason.name,
          },
    'alt_svc': response.headers['alt-svc'],
  };
}

Future<_PersistedReport> _persistReport(Map<String, Object?> result) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$_reportFileName');
  final report = <String, Object?>{
    ...result,
    'report_file_name': _reportFileName,
    'report_path': file.path,
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  await file.writeAsString(encoded, flush: true);
  String? downloadsPath;
  String? downloadsError;
  if (Platform.isAndroid) {
    try {
      final export = _asObjectMap(
        await _androidNetworkChannel.invokeMethod<Object?>(
          'exportReport',
          <String, Object?>{
            'fileName': _downloadFileName(),
            'content': encoded,
          },
        ),
      );
      final relativePath = export['relativePath']?.toString();
      final displayName = export['displayName']?.toString();
      if (relativePath != null && displayName != null) {
        downloadsPath = '$relativePath/$displayName';
      }
    } catch (error) {
      downloadsError = _describe(error);
    }
  }
  return _PersistedReport(
    appPath: file.path,
    downloadsPath: downloadsPath,
    downloadsError: downloadsError,
  );
}

String _downloadFileName() {
  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9TZ]'),
    '',
  );
  return 'alphax-phase1f-h3-release-$timestamp.json';
}

String _reportLocation(_PersistedReport persisted) {
  final downloadsPath = persisted.downloadsPath;
  if (downloadsPath != null) {
    return 'Report saved at ${persisted.appPath}; Downloads copy at $downloadsPath';
  }
  final downloadsError = persisted.downloadsError;
  if (downloadsError != null) {
    return 'Report saved at ${persisted.appPath}; Downloads export unavailable: $downloadsError';
  }
  return 'Report saved at ${persisted.appPath}';
}

void _emitReport(Map<String, Object?> result, String reportPath) {
  final encoded = const JsonEncoder.withIndent('  ').convert(result);
  stdout.writeln('ALPHAX_PHASE1F_H3_REPORT_PATH:$reportPath');
  stdout.writeln('ALPHAX_PHASE1F_H3_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_PHASE1F_H3_RESULT_END');
}

Future<void> _closeWithDeadline(AlphaXTransport transport) async {
  try {
    await transport.close().timeout(const Duration(seconds: 10));
  } on TimeoutException {
    // Preserve the report even if a platform teardown is slow.
  }
}

String _describe(Object error) => error is AlphaXException
    ? '${error.runtimeType} (${error.kind.name}): ${error.message}'
    : '${error.runtimeType}: $error';

Map<String, Object?> _asObjectMap(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

final class _PersistedReport {
  const _PersistedReport({
    required this.appPath,
    this.downloadsPath,
    this.downloadsError,
  });

  final String appPath;
  final String? downloadsPath;
  final String? downloadsError;
}
