/// AlphaX browser transport adapter.
library;

export 'src/web_fetch_transport_stub.dart'
    if (dart.library.js_interop) 'src/web_fetch_transport.dart';
