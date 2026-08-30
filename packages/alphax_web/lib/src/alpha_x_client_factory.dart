import 'dart:async';

import 'package:alphax/alphax.dart';

import 'web_fetch_transport_stub.dart' if (dart.library.js_interop) 'web_fetch_transport.dart';

/// Creates one AlphaX client backed by browser Fetch.
///
/// Browser TLS, proxy routing, CORS, redirects, connection reuse, and
/// negotiated protocol remain browser-owned. [withCredentials] controls the
/// browser Fetch credential mode; it does not provide native credential or
/// cookie behavior.
AlphaXClient createAlphaXClient({
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  bool withCredentials = false,
}) {
  final transport = WebFetchTransport(withCredentials: withCredentials);
  try {
    return AlphaXClient(
      transport: transport,
      middleware: middleware,
    );
  } catch (error, stackTrace) {
    unawaited(transport.close());
    Error.throwWithStackTrace(error, stackTrace);
  }
}
