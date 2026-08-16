# alphax

`alphax` is the small, transport-independent API used to create HTTP requests,
read responses, stream data, transfer files, cancel work, set timeouts, and
inspect the protocol that was actually negotiated.

`alphax` contains the contracts and client facade. It does not open a network
connection by itself. A normal application also installs `alphax_native` and
chooses a platform transport.

## Start in three steps

### 1. Add the packages

After the RC is published, add the core and platform packages to a Flutter
application:

```sh
flutter pub add alphax alphax_native
```

While this RC is unpublished, use the repository dependencies shown in the
[root README](../../README.md).

### 2. Send a first request

This is the smallest working example using the Dart IO fallback:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: DartIoTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

`DartIoTransport` is the simple H1 fallback. For Android, iOS, or macOS,
follow the platform setup in [`alphax_native`](../alphax_native/README.md) to
use the native provider available on that platform.

### 3. Keep the client lifecycle simple

Create one client for the work that should share a connection pool, reuse it
for requests, and call `await client.close()` when that work is finished.

## What this package includes

The public API includes request and response types, headers and bodies,
streaming, file-transfer contracts, cancellation, timeouts, redirects,
middleware, capabilities, protocol preference and requirement, metrics, TLS
and proxy policy models, and normalized errors.

Response protocol metadata may be incomplete until the body finishes. Await
`AlphaXResponse.completionMetrics` and `completionProtocolFallback` for the
authoritative final values when a platform reports negotiation at completion.
`AlphaXProtocol.unknown` is never an implicit HTTP/1.1 or fallback result.

This package has no Flutter SDK dependency and does not implement Dart IO,
Cronet, or URLSession. The `1.0.0-rc.1` candidate is prepared for maintainer
review and is not published until naming clearance and release approval are
complete.
