# alphax_web

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_web/assets/branding/alphax-logo-light.svg">
    <img src="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_web/assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="300">
  </picture>
</p>

<p align="center"><strong>Run AlphaX through browser Fetch.</strong><br>
Keep the request API while respecting the browser's security and networking controls.</p>

<p align="center">
  <a href="https://github.com/auvana-ventures/alphax/tree/main/packages/alphax">Core API</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md">Usage and customization</a> ·
  <a href="https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native">Native transports</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/LICENSE">Apache-2.0</a>
</p>

## At a glance

| Browser concern | `alphax_web` behavior |
| --- | --- |
| Transport | Fetch, exposed as an AlphaX transport |
| Protocol metadata | `unknown`; Fetch does not expose authoritative H1/H2/H3 information to Dart |
| Browser controls | CORS, TLS, proxy routing, connection reuse, redirects, and cookie credentials remain browser-owned |
| AlphaX policies | Authentication, replay-aware retries, in-memory cookies/cache, and generic resilience remain opt-in |
| Native controls | File paths, SPKI pinning, custom trust anchors, mTLS, explicit proxies, and upload progress are unavailable here |

## Start here

1. Add `alphax_web`. Its runtime dependency supplies the core AlphaX API
   transitively.
2. Create one client with `createAlphaXClient()`.
3. Configure CORS and browser credentials on the server/application boundary.
4. Treat protocol metadata as `unknown`; browser controls remain browser-owned.

`alphax_web` adds a browser Fetch transport for AlphaX. Use it when the same
transport-independent request code must run in a Flutter Web application or a
Dart application compiled for the browser. Its entry point re-exports the
public AlphaX API, so ordinary browser users need only this package import.

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
flutter pub add alphax_web
```

Do not add `alphax` directly just to use the ordinary Web API; it is already a
runtime dependency of `alphax_web`. The coordinated package version remains
governed by the release task.

## First request

```dart
import 'package:alphax_web/alphax_web.dart';

Future<void> loadHealth() async {
  final client = createAlphaXClient();
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

The compile-tested one-import example is
[`example/main.dart`](example/main.dart); explicit `WebFetchTransport()`
construction remains covered in the compatibility section below.

## Configured Web client

Web configuration remains limited to options the browser-backed transport can
actually expose:

```dart
final client = createAlphaXClient(
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(
      accessToken: () async => 'token-from-app',
    ),
  ],
  withCredentials: true,
);
```

TLS, proxy routing, CORS, redirects, connection reuse, and protocol negotiation
remain browser-owned. `withCredentials` controls browser-managed credential
mode; it is not a native TLS, proxy, or cookie policy.

For explicit assembly and custom transports, the rc.4 path remains available:

```dart
final client = AlphaXClient(
  transport: WebFetchTransport(),
);

final customClient = AlphaXClient(
  transport: MyTransport(),
);
```

## Direct typed REST generation

For a new typed API, add `alphax_generator` and `build_runner` as development
dependencies. The Web entry point re-exports the lightweight AlphaX
annotations, so a declaration can use one deployment import:

```dart
import 'package:alphax_web/alphax_web.dart';

part 'users_api.g.dart';

@AlphaXApi(baseUrl: 'https://example.com')
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXGet('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<User> getUser(@AlphaXPath('id') String id);
}
```

The generated implementation calls `AlphaXClient` directly and borrows the
client. Fetch, CORS, browser credentials, TLS, proxy routing, redirects, and
protocol negotiation remain browser-owned; the generator does not add native
capabilities. See [`alphax_generator`](../alphax_generator/README.md) and the
[compile-tested Web fixture](../../examples/typed_rest_web).

## Defaults and optional policies

`WebFetchTransport` follows browser security and has these defaults:

| Behavior | Default in Web |
| --- | --- |
| TLS and proxy | Controlled by the browser; AlphaX cannot replace them. |
| Protocol metadata | `unknown`; Fetch does not expose authoritative H1/H2/H3 to Dart. |
| Retries | Off until `AlphaXRetryMiddleware` is added. |
| Authentication | Off until authentication middleware or browser credentials are configured. |
| Cookies | Browser-managed cookies are off for cross-origin requests until `withCredentials: true`; an AlphaX in-memory jar is separately opt-in. |
| Cache and resilience | Off until the corresponding AlphaX middleware is added. |

The same AlphaX middleware can be added to Web for policies that do not require
native controls:

```dart
final client = createAlphaXClient(
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(
      accessToken: () async => 'token-from-app',
    ),
    AlphaXRetryMiddleware(),
    AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
  ],
);
```

Retries still require replayable bodies, cache behavior is in-memory unless you
provide another store, and browser CORS rules still apply. The Web adapter
cannot add certificate pins or an explicit proxy because those controls belong
to the browser. See the [policy defaults and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md)
for the general policy rules.

Do not combine `AlphaXCacheMiddleware` with
`createAlphaXClient(withCredentials: true)` unless the application supplies a
stable, non-secret cache `identityKey` for the browser session and changes it or
clears the store on logout/account change. Browser-managed cookies are opaque to
AlphaX, so the cache cannot discover that identity itself. If browser identity
can change without the application observing it, leave AlphaX caching off for
those requests.

## Cookies and browser credentials

For browser-managed cookies, opt in deliberately:

```dart
final client = createAlphaXClient(withCredentials: true);
```

`withCredentials` is a browser Fetch setting. Cross-origin servers must also
return compatible CORS and credential headers. If the application needs an
explicit, transport-neutral in-memory cookie jar, add
`AlphaXCookieMiddleware(AlphaXCookieJar())` from `alphax` instead.

## Server-Sent Events with Fetch

The Web entry point re-exports `AlphaXSseParser`, so an SSE response can use
the same one-import deployment path:

```dart
import 'package:alphax_web/alphax_web.dart';

Future<void> consumeSse(AlphaXClient client, Uri uri) async {
  final response = await client.send(
    AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: AlphaXHeaders({'accept': 'text/event-stream'}),
    ),
  );

  await for (final event in response.stream.transform(AlphaXSseParser())) {
    print('${event.event ?? 'message'}: ${event.data}');
  }
}
```

This uses Fetch response streaming, not the browser `EventSource` API. CORS,
TLS, proxy routing, connection behavior, and browser protocol selection remain
browser-owned. The parser exposes IDs and retry hints but never reconnects or
sends `Last-Event-ID`; cancellation remains the normal AlphaX request token.
See the [core SSE example](../alphax/example/sse.dart) for the parser contract.

## WebSocket

Use the browser connector from the same Web deployment import:

```dart
import 'package:alphax_web/alphax_web.dart';

Future<void> useWebSocket(Uri uri) async {
  final connector = createAlphaXWebSocketConnector();
  final socket = await connector.connect(
    uri,
    protocols: <String>['alpha.v1'],
  );
  try {
    final firstMessage = socket.messages.first;
    await socket.send(const AlphaXWebSocketMessage.text('hello'));
    print(await firstMessage);
  } finally {
    await socket.close();
  }
}
```

The connector uses the browser WebSocket API through the maintained
`package:web_socket` abstraction. Text and binary messages remain distinct,
the negotiated subprotocol is reported by the browser, and `socket.done`
provides terminal close information. There is no EventSource-style automatic
reconnect, retry, replay, or resend queue.

Browser WebSocket does not permit arbitrary request headers, so the portable
connector intentionally has no header parameter and reports
`connector.capabilities.customHeaders` as `AlphaXSupport.unsupported`. Browser
TLS, origin, cookies, CSP, proxy/network policy, and connection behavior remain
browser-owned. Use browser-managed cookies, a supported subprotocol, or an
application-level authentication message where appropriate; AlphaX never
transforms authorization headers into query parameters. Use `wss:` when the
browser connection must be secure; AlphaX does not add a trust-all or
certificate-bypass path. The compile-tested example is
[`example/websocket.dart`](example/websocket.dart).

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

If a browser limitation is unacceptable, move that operation to a native
transport and check its reported capabilities before configuring TLS, proxy, or
protocol requirements. AlphaX will fail closed rather than pretending that the
browser can enforce a control it cannot observe.

The package is licensed under Apache-2.0. The rc.5 façade is additive to the
existing Web transport and explicit rc.4 construction path; publication and
coordinated versioning remain release-task work.
