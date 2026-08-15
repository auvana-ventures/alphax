import 'package:alphax_native/alphax_native.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:integration_test/integration_test.dart';

const _requestUri = String.fromEnvironment('ALPHAX_PHASE1D_CONFORMANCE_URL');

/// Runs the shared AlphaX transport contract inside a real Flutter host.
///
/// This file intentionally lives in the benchmark/integration runner rather
/// than in `alphax` or `alphax_test`. The platform plugin must be attached by
/// the Flutter application for URLSession channel calls to work.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (_requestUri.isEmpty) {
    throw StateError(
      'ALPHAX_PHASE1D_CONFORMANCE_URL must point to the deterministic fixture',
    );
  }
  final requestUri = Uri.parse(_requestUri);

  defineAlphaXTransportConformanceTests(
    'Apple URLSession (Flutter integration)',
    AppleUrlSessionTransport.create,
    baseUriProvider: () => requestUri,
  );
}
