# alphax_web

`alphax_web` adds a browser Fetch transport for AlphaX. Use it when the same
transport-independent request code must run in a Flutter Web application or a
Dart application compiled for the browser.

## What you get

- ordinary browser HTTP requests through Fetch;
- AlphaX headers, bodies, response streams, cancellation, timeouts, redirects,
  and normalized errors;
- browser-managed credential mode through `withCredentials`; and
- the same middleware layer as native AlphaX transports for authentication,
  cookies, caching, retries, and resilience policies.

The browser controls TLS, proxies, connection reuse, CORS, and the negotiated
HTTP version. Fetch does not expose authoritative H1/H2/H3 metadata to Dart, so
the transport reports the protocol as `unknown`. A concrete protocol
requirement fails closed instead of guessing.

## Install

```sh
flutter pub add alphax alphax_web
```

## First request

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_web/alphax_web.dart';

Future<void> loadHealth() async {
  final client = AlphaXClient(transport: WebFetchTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/health'));
    print('${response.statusCode}: ${await response.readAsString()}');
    print('protocol: ${(await response.completionMetrics).negotiatedProtocol.name}');
  } finally {
    await client.close();
  }
}
```

The target server must allow the browser origin with the appropriate CORS
headers. AlphaX cannot bypass browser security rules.

## Cookies and browser credentials

For browser-managed cookies, opt in deliberately:

```dart
final client = AlphaXClient(
  transport: WebFetchTransport(withCredentials: true),
);
```

`withCredentials` is a browser Fetch setting. Cross-origin servers must also
return compatible CORS and credential headers. If the application needs an
explicit, transport-neutral in-memory cookie jar, add
`AlphaXCookieMiddleware(AlphaXCookieJar())` from `alphax` instead.

## Browser boundaries

- H3 is not guaranteed; provider, server, proxy, and network conditions decide
  the actual protocol.
- Fetch cannot authoritatively report H1/H2/H3, so `protocolRequirement` is
  rejected with `AlphaXProtocolRequirementException`.
- Native file paths, custom trust anchors, SPKI pinning, mTLS, explicit proxy
  endpoints, and upload progress are unavailable in this adapter.
- Request bodies are buffered before Fetch dispatch because browser Fetch does
  not provide the AlphaX native streaming-upload contract here.
- Redirect behavior and credential handling remain subject to browser Fetch and
  CORS rules.

Use [`alphax_native`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native) for Android, iOS, macOS,
Linux, and Windows transport adapters. Use [`alphax`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax)
directly when you provide another transport.

The package is licensed under Apache-2.0 and is prepared as a separate Web
adapter; it is not silently added to the native RC publication set.
