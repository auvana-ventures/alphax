import 'dart:convert';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

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
  runApp(const _H3ProbeApp());

  final report = await _runProbe();
  final encoded = jsonEncode(report);
  final resultFile = File(
    '${Directory.systemTemp.path}/alphax-phase1c-h3-result.json',
  );
  await resultFile.writeAsString(encoded, flush: true);
  stdout.writeln('ALPHAX_PHASE1C_H3_RESULT_FILE:${resultFile.path}');
  stdout.writeln('ALPHAX_PHASE1C_H3_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_PHASE1C_H3_RESULT_END');
}

final class _H3ProbeApp extends StatelessWidget {
  const _H3ProbeApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('AlphaX focused HTTP/3 probe is running.')),
    ),
  );
}

Future<Map<String, Object?>> _runProbe() async {
  final report = <String, Object?>{
    'status': 'unverified',
    'metadata': <String, Object?>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'device_model': _deviceModel,
      'architecture': _deviceArchitecture,
      'dart_version': Platform.version,
      'flutter_version': _flutterVersion,
      'build_mode': 'profile device build; focused protocol probe',
      'git_commit': _gitCommit,
      'endpoint': _h3Url,
      'tls_policy': 'Cronet platform trust defaults; no trust-all override',
    },
  };
  if (!Platform.isAndroid) {
    report['error'] = 'This probe requires Android.';
    return report;
  }

  AndroidCronetTransport? transport;
  try {
    transport = await AndroidCronetTransport.create();
    report['capabilities'] = <String, Object?>{
      'transport_name': transport.capabilities.transportName,
      'transport_version': transport.capabilities.transportVersion,
      'http2': transport.capabilities.supportFor(AlphaXCapability.http2).name,
      'http3': transport.capabilities.supportFor(AlphaXCapability.http3).name,
      'negotiated_protocol_reporting': transport.capabilities
          .supportFor(AlphaXCapability.negotiatedProtocolReporting)
          .name,
    };

    final uri = Uri.parse(_h3Url);
    final prewarm = await transport.send(
      AlphaXRequest(method: HttpMethod.get, uri: uri),
    );
    final prewarmBody = await prewarm.readAsBytes();
    await Future<void>.delayed(const Duration(seconds: 1));
    final response = await transport.send(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: uri,
        protocolPreference: AlphaXProtocolPreference.http3,
      ),
    );
    final body = await response.readAsBytes();
    report['probe'] = <String, Object?>{
      'requested_protocol': AlphaXProtocolPreference.http3.name,
      'prewarm_protocol': prewarm.protocol.name,
      'prewarm_status': prewarm.statusCode,
      'prewarm_body_bytes': prewarmBody.length,
      'status_code': response.statusCode,
      'body_bytes': body.length,
      'negotiated_protocol': response.protocol.name,
      'fallback': response.protocolFallback == null
          ? null
          : <String, Object?>{
              'requested': response.protocolFallback!.requested.name,
              'negotiated': response.protocolFallback!.negotiated.name,
              'reason': response.protocolFallback!.reason.name,
            },
      'alt_svc': response.headers['alt-svc'],
    };
    report['status'] = response.protocol == AlphaXProtocol.http3
        ? 'verified'
        : 'unverified';
  } catch (error, stackTrace) {
    report['error'] = error.toString();
    report['stack'] = stackTrace.toString();
  } finally {
    await transport?.close();
  }
  return report;
}
