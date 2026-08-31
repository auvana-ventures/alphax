import 'package:alphax/alphax.dart';
import 'package:alphax/app_client.dart';

import 'alpha_x_client_factory.dart';

/// Creates an application-facing client with the native platform transport.
///
/// This helper delegates transport selection and initialization to the
/// existing [createAlphaXClient] factory, then gives the facade ownership of
/// that client. [timeout] is the facade's default overall request timeout;
/// [tlsPolicy] and [proxyPolicy] retain the existing transport-construction
/// controls.
Future<AlphaXAppClient> createAlphaXAppClient({
  required String baseUrl,
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
  Duration? timeout,
}) async {
  final client = await createAlphaXClient(
    middleware: middleware,
    tlsPolicy: tlsPolicy,
    proxyPolicy: proxyPolicy,
  );
  try {
    return AlphaXAppClient.owned(
      client,
      baseUrl: baseUrl,
      timeout: timeout,
    );
  } catch (error, stackTrace) {
    await client.close();
    Error.throwWithStackTrace(error, stackTrace);
  }
}
