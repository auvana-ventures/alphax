/// AlphaX browser transport adapter.
library;

export 'package:alphax/alphax.dart';

export 'src/alpha_x_client_factory.dart';
export 'src/web_fetch_transport_stub.dart'
    if (dart.library.js_interop) 'src/web_fetch_transport.dart';
