import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _h1Url = String.fromEnvironment('ALPHAX_PHASE1F_H1_URL');
const _h2Url = String.fromEnvironment('ALPHAX_PHASE1F_H2_URL');
const _h3Url = String.fromEnvironment('ALPHAX_PHASE1F_H3_URL');

/// Runs the small release-oriented H1/H2/H3 and fallback acceptance probe on
/// a physical Android or Apple host. It is not a performance benchmark.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('release protocol and fallback acceptance', (_) async {
    if (_h1Url.isEmpty || _h2Url.isEmpty || _h3Url.isEmpty) {
      fail('ALPHAX_PHASE1F_H1_URL, H2_URL, and H3_URL are required');
    }
    final transport = switch (defaultTargetPlatform) {
      TargetPlatform.android => await AndroidCronetTransport.create(),
      TargetPlatform.iOS ||
      TargetPlatform.macOS => await AppleUrlSessionTransport.create(),
      _ => throw UnsupportedError('Android or Apple is required'),
    };

    try {
      await _probe(
        transport,
        name: 'h1',
        uri: Uri.parse(_h1Url),
        preference: AlphaXProtocolPreference.auto,
        expected: AlphaXProtocol.http11,
      );
      await _probe(
        transport,
        name: 'h2',
        uri: Uri.parse(_h2Url),
        preference: AlphaXProtocolPreference.auto,
        expected: AlphaXProtocol.http2,
      );
      await _probe(
        transport,
        name: 'h3',
        uri: Uri.parse(_h3Url),
        preference: AlphaXProtocolPreference.http3,
        expected: AlphaXProtocol.http3,
      );
      await _probe(
        transport,
        name: 'h3_fallback_to_h1',
        uri: Uri.parse(_h1Url),
        preference: AlphaXProtocolPreference.http3,
        expected: AlphaXProtocol.http11,
        requiresFallback: true,
      );
    } finally {
      await transport.close();
    }
  });
}

Future<void> _probe(
  AlphaXTransport transport, {
  required String name,
  required Uri uri,
  required AlphaXProtocolPreference preference,
  required AlphaXProtocol expected,
  bool requiresFallback = false,
}) async {
  final response = await transport.send(
    AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      protocolPreference: preference,
      timeouts: const AlphaXTimeouts(overall: Duration(seconds: 30)),
    ),
  );
  await response.readAsBytes();
  final metrics = await response.completionMetrics;
  final actual = metrics.negotiatedProtocol;
  // Completion metadata is authoritative for URLSession and also provides a
  // consistent assertion point for providers that report earlier.
  expect(actual, expected, reason: '$name negotiated ${actual.name}');
  expect(actual, isNot(AlphaXProtocol.unknown));
  final fallback = await response.completionProtocolFallback;
  if (requiresFallback) {
    expect(fallback, isNotNull, reason: '$name did not report fallback');
    expect(fallback!.requested, AlphaXProtocolPreference.http3);
    expect(fallback.negotiated, expected);
  } else {
    expect(fallback, isNull, reason: '$name unexpectedly reported fallback');
  }
  // Keep the case name visible in device logs without including credentials.
  debugPrint('AlphaX Phase 1F protocol probe $name: ${actual.name}');
}
