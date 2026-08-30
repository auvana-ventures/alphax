import 'package:alphax/alphax.dart';

import 'alpha_x_transport_factory.dart';

/// Creates one AlphaX client using the transport selected for the current
/// native platform.
///
/// The selected transport is initialized before this future completes. The
/// returned client owns that transport and must be reused for the owning
/// application or feature scope, then closed when that scope ends.
///
/// [middleware] is shared by the returned client. [tlsPolicy] and
/// [proxyPolicy] are passed to the existing native transport-selection
/// factory and are enforced or rejected by the selected provider.
Future<AlphaXClient> createAlphaXClient({
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
}) async {
  final transport = await createAlphaXTransport(
    tlsPolicy: tlsPolicy,
    proxyPolicy: proxyPolicy,
  );
  try {
    return AlphaXClient(
      transport: transport,
      middleware: middleware,
    );
  } catch (error, stackTrace) {
    await transport.close();
    Error.throwWithStackTrace(error, stackTrace);
  }
}
