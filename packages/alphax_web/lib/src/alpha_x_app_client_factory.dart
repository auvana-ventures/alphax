import 'package:alphax/alphax.dart';
import 'package:alphax/app_client.dart';

import 'alpha_x_client_factory.dart';

/// Creates an application-facing client backed by browser Fetch.
///
/// The returned facade owns the underlying client. Browser TLS, proxy,
/// redirects, CORS, credential handling, and protocol metadata remain under
/// browser control. [timeout] is the facade's default overall request timeout.
Future<AlphaXAppClient> createAlphaXAppClient({
  required String baseUrl,
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  bool withCredentials = false,
  Duration? timeout,
}) async {
  final client = createAlphaXClient(
    middleware: middleware,
    withCredentials: withCredentials,
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
