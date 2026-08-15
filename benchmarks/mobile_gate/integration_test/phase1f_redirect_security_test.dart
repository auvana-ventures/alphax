import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _redirectUri = String.fromEnvironment('ALPHAX_PHASE1F_REDIRECT_URL');

/// Verifies the shared cross-origin credential-stripping contract on a real
/// Android Cronet or Apple URLSession host.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cross-origin redirects strip sensitive request headers', (
    _,
  ) async {
    if (_redirectUri.isEmpty) {
      fail('ALPHAX_PHASE1F_REDIRECT_URL must point to the redirect fixture');
    }

    final transport = switch (defaultTargetPlatform) {
      TargetPlatform.android => await AndroidCronetTransport.create(),
      TargetPlatform.iOS ||
      TargetPlatform.macOS => await AppleUrlSessionTransport.create(),
      _ => throw UnsupportedError(
        'The Phase 1F redirect security test requires Android or Apple',
      ),
    };

    try {
      try {
        final response = await transport.send(
          AlphaXRequest(
            method: HttpMethod.get,
            uri: Uri.parse(_redirectUri),
            headers: AlphaXHeaders(<String, String>{
              'Authorization': 'Bearer phase1f-test-token',
              'Proxy-Authorization': 'Basic phase1f-test-credentials',
              'Cookie': 'session=phase1f-test-cookie',
            }),
          ),
        );
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;

        expect(response.statusCode, 200);
        expect(response.redirects, hasLength(1));
        expect(body['authorization_present'], isFalse);
        expect(body['proxy_authorization_present'], isFalse);
        expect(body['cookie_present'], isFalse);
      } on AlphaXRedirectException {
        // Cronet may conservatively reject a sensitive cross-origin redirect
        // because the selected provider does not expose pending-header
        // replacement. Rejection is a secure pass: no target request occurs.
      }
    } finally {
      await transport.close();
    }
  });
}
