# alphax_native

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_native/assets/branding/alphax-logo-light.svg">
    <img src="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_native/assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="300">
  </picture>
</p>

<p align="center"><strong>Platform transports for the AlphaX API.</strong><br>
Use the platform networking stack where it is supported, with a truthful Dart IO fallback.</p>

<p align="center">
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/ALPHAX_1_0_RELEASE_NOTES.md">Release notes</a> ·
  <a href="https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint">Waypoint example</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/LICENSE">Apache-2.0</a>
</p>

## At a glance

| Target | Transport supplied |
| --- | --- |
| Android API 24+ | Cronet/HttpEngine provider with H1/H2/H3 capability where the provider and network permit it |
| iOS 15+ / macOS 12+ | URLSession with platform-negotiated H1/H2/H3 and completion-time metadata |
| Linux / Windows | Dart IO fallback with H1 support and no authoritative H2/H3 reporting |
| Web | Not supplied here; use the separate `alphax_web` Fetch adapter |

## Start here

1. Add `alphax_native` to the application. Its runtime dependency supplies the
   core AlphaX API transitively.
2. Use [`createAlphaXAppClient`](#simple-native-client) for the normal
   application path.
3. Keep the request code shared across platforms.
4. Read [TLS and proxy behavior](#configure-tls-and-proxy-behavior) before
   enabling optional security or routing controls.

`alphax_native` gives an AlphaX application the platform transport selected for
each supported target while keeping the same Dart request code everywhere. It
supplies Dart IO, Android Cronet/HttpEngine, and Apple URLSession adapters
behind the transport-neutral [`alphax`](https://pub.dev/packages/alphax) API. The
package entry point re-exports that public API, so ordinary native users need
only this package import.

## Why use it?

Use `alphax_native` when you want to:

- use Android's supported Cronet provider for H1/H2/H3-capable networking;
- use Foundation URLSession on iOS and macOS;
- keep an H1 Dart IO fallback for Linux and Windows;
- stream responses and file transfers with cancellation and progress;
- inspect the protocol that actually completed each request;
- keep TLS, proxy, redirect, and error behavior behind AlphaX contracts.

H3 is opportunistic. The selected provider, server, proxy, and network decide
whether an individual request uses H3. AlphaX reports the actual result and
fails closed when an explicit protocol requirement cannot be met.

## When should I choose this package?

Choose `alphax_native` for a new Flutter application or when an existing
AlphaX application needs the platform transport implementations. Use
[`alphax`](https://pub.dev/packages/alphax) alone for transport contracts and a custom
transport, or use [`alphax_dio`](https://pub.dev/packages/alphax_dio) if your application
already uses Dio. Add [`alphax_test`](https://pub.dev/packages/alphax_test) for
deterministic test transports.

## Install

Install `alphax_native` for a native Flutter application:

```sh
flutter pub add alphax_native
```

Do not add `alphax` directly just to use the ordinary native API; it is already
declared by `alphax_native` and is available through its public entry import.
The `1.1.0` release adds the application-facing `createAlphaXAppClient(...)`
factory while retaining the lower-level client and transport APIs.

The Android provider is resolved through Gradle and Apple packaging uses
CocoaPods. No copied Cronet binary is bundled in the pub package. Swift
Package Manager integration is not part of the current package.

## Simple native client

The recommended setup creates one reusable `AlphaXAppClient` and selects the
native transport for the current platform:

```dart
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = await createAlphaXAppClient(
    baseUrl: 'https://example.com',
  );
  try {
    final response = await client.get('/');
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

The application facade owns the underlying client created by the factory.
Reuse it for all requests in the owning scope and close it when that scope
ends. See the [application client guide](https://github.com/auvana-ventures/alphax/blob/main/docs/app-client.md)
for base URLs, query parameters, headers, JSON data, cancellation, and the
borrowed-client alternative.

The same one-import flow is kept in the compile-tested
[`example/main.dart`](example/main.dart). The advanced
[`example/recipes.dart`](example/recipes.dart) retains explicit transport and
policy construction.

## Configured native client

The factory accepts the existing client middleware and transport-construction
TLS/proxy policies:

```dart
import 'package:alphax_native/alphax_native.dart';

Future<AlphaXAppClient> createConfiguredClient() => createAlphaXAppClient(
  baseUrl: 'https://api.example.com',
  middleware: <AlphaXMiddleware>[AlphaXRetryMiddleware()],
  tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
  proxyPolicy: const AlphaXProxyPolicy.system(),
);
```

Timeouts, cancellation, redirects, protocol preference/requirement, and
progress remain request-level settings. The browser has its own authority for
TLS and proxy behavior; this native factory only configures native transports.

## Direct typed REST generation

For a new typed API, add `alphax_generator` and `build_runner` as development
dependencies. This package re-exports the lightweight AlphaX annotations, so
the declaration can keep the native one-import experience:

```dart
import 'package:alphax_native/alphax_native.dart';

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
client; it does not use Dio or Retrofit. See
[`alphax_generator`](../alphax_generator/README.md) and the
[compile-tested native fixture](../../examples/typed_rest).

## Automatic transport selection

For native Dart VM and Flutter targets, `createAlphaXTransport` selects the recommended
AlphaX adapter without application-level `Platform.is...` branching:

```dart
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: await createAlphaXTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

The automatic mapping is Android → Cronet/HttpEngine, iOS/macOS → URLSession,
and Linux/Windows → Dart IO. Web is intentionally separate; use
`WebFetchTransport` from [`alphax_web`](../alphax_web/README.md). The factory
only selects and initializes a transport. It does not enable retries, cookies,
cache, authentication, resilience, or background JSON parsing. The direct
factory is retained for callers who need to assemble `AlphaXClient` explicitly.

## Explicit selection

Construct a concrete adapter when troubleshooting, testing, or a controlled
rollout needs a deliberate provider:

```dart
Future<List<AlphaXTransport>> explicitTransports() async => <AlphaXTransport>[
  DartIoTransport(),
  await AndroidCronetTransport.create(),
  await AppleUrlSessionTransport.create(),
];
```

Pass one of these values to `AlphaXClient(transport: ...)`. The request API is
the same for every adapter. `DartIoTransport` is the supported fallback on
Linux and Windows; Android and Apple adapters must be initialized on their
corresponding platforms.

## Platform support

| Platform | Adapter | Protocol boundary |
| --- | --- | --- |
| Android API 24+ | Cronet/HttpEngine provider | H1/H2/H3 where the selected non-fallback provider and network negotiate it |
| iOS 15+ | URLSession | H1/H2/H3 where the OS, server, proxy, and network negotiate it |
| macOS 12+ | URLSession | H1/H2/H3 where the OS, server, proxy, and network negotiate it |
| Linux | Dart IO | H1 only; H2/H3 are not advertised |
| Windows | Dart IO | H1 only; H2/H3 are not advertised |
| Web | Not provided by this native plugin | Add [`alphax_web`](https://pub.dev/packages/alphax_web) for browser Fetch |

## Common jobs

### Stream and cancel a response

```dart
final token = AlphaXCancellationToken();
final response = await client.get(
  Uri.https('example.com', '/large-response'),
  cancellationToken: token,
);

await for (final chunk in response.stream) {
  // Process bounded chunks as they arrive.
}

// Call token.cancel('screen closed') when the UI no longer needs the response.
```

Native adapters use bounded response delivery. Pausing or cancelling a Dart
stream does not require the native layer to buffer the entire response.

### Server-Sent Events

The native entry point re-exports the small `AlphaXSseParser`, so this remains
one import while using the selected native response stream:

```dart
import 'package:alphax_native/alphax_native.dart';

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

The parser is incremental and does not reconnect or send `Last-Event-ID`.
Cancellation remains the normal `AlphaXCancellationToken` on the request, and
the selected transport continues to enforce its TLS, proxy, and bounded
streaming behavior. See the [core SSE example](../alphax/example/sse.dart) for
the parser contract and field semantics.

### WebSocket

Use the separate WebSocket connector from the same native deployment import:

```dart
import 'package:alphax_native/alphax_native.dart';

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

The connector adapts the maintained `package:web_socket` Dart IO provider. It
is intentionally independent of whether HTTP selected Dart IO, Cronet, or
URLSession; those HTTP providers do not implicitly own this full-duplex
session. Text and binary messages remain distinct, subprotocol negotiation is
reported by the provider, and `socket.done` provides terminal close
information. There is no automatic reconnect, retry, replay, or resend queue.

The portable connector has no arbitrary header parameter. The maintained
provider boundary does not provide consistent custom-header support, so
`connector.capabilities.customHeaders` is `AlphaXSupport.unsupported` rather
than silently dropping authentication headers. Use an application-supported
cookie, URL, subprotocol, or protocol-level authentication mechanism as
appropriate; AlphaX never converts authorization headers into query parameters.
Use `wss:` for a secure connection; the Dart IO provider keeps its verified
platform TLS defaults. The HTTP `AlphaXTlsPolicy`/proxy settings configure the
HTTP transport factory and are not silently applied to a separate WebSocket
provider. No trust-all or certificate-bypass path is added.
The compile-tested example is
[`example/websocket.dart`](example/websocket.dart).

### Download directly to a platform file

```dart
final result = await client.download(
  Uri.https('example.com', '/archive.bin'),
  to: AlphaXLocalFileTarget('/tmp/archive.bin'),
  onDownloadProgress: (progress) {
    print('${progress.bytesTransferred} bytes received');
  },
);
print('actual protocol: ${result.protocol.name}');
```

`AlphaXLocalFileSource` and `AlphaXLocalFileTarget` keep platform file paths
out of the core `alphax` package. The Dart IO fallback remains stream-based
when native file paths are unavailable.

### Inspect the actual protocol

```dart
final response = await client.get(
  Uri.https('example.com', '/health'),
  protocolPreference: AlphaXProtocolPreference.http3,
);
final metrics = await response.completionMetrics;
print('negotiated protocol: ${metrics.negotiatedProtocol.name}');
```

If H3 is mandatory, pass
`protocolRequirement: AlphaXProtocolRequirement.http3`. A preference may
fall back to H2 or H1; a requirement fails closed when H3 is not negotiated.

## Configure TLS and proxy behavior

The transport constructors use secure, system-managed defaults:

- certificate-chain, hostname, and validity checks are enabled;
- the system proxy policy is used; and
- SPKI pinning, explicit proxy routing, and custom trust anchors are off until
  you configure them.

Configure these controls when the transport is created, before passing it to
`AlphaXClient`:

```dart
Future<AlphaXClient> createPinnedClient({
  required String apiHost,
  required String primarySpkiSha256Base64,
  required DateTime primaryPinExpiry,
  required String backupSpkiSha256Base64,
  required DateTime backupPinExpiry,
  required String proxyHost,
  required int proxyPort,
}) async {
  return createAlphaXClient(
    tlsPolicy: AlphaXTlsPolicy(
      pins: <AlphaXSpkiPin>[
        AlphaXSpkiPin(
          host: apiHost,
          sha256SpkiBase64: primarySpkiSha256Base64,
          expiresAt: primaryPinExpiry,
        ),
        AlphaXSpkiPin(
          host: apiHost,
          sha256SpkiBase64: backupSpkiSha256Base64,
          expiresAt: backupPinExpiry,
        ),
      ],
    ),
    proxyPolicy: AlphaXProxyPolicy.http(
      host: proxyHost,
      port: proxyPort,
    ),
  );
}
```

The same progressive path applies to explicit transports:

```dart
final client = AlphaXClient(
  transport: await createAlphaXTransport(),
);

final customClient = AlphaXClient(
  transport: MyTransport(),
);
```

The pin variables must come from your secure release configuration. A pin is a
base64 SHA-256 digest of the certificate's DER SubjectPublicKeyInfo. Keep a
primary and backup pin, give both an expiry, and rotate before expiry. Pinning
adds to normal certificate validation; it never makes an expired, untrusted, or
wrong-host certificate valid.

Check `client.capabilities` before selecting an optional control. If the
selected provider cannot honor a configured TLS or proxy policy, initialization
fails with a normalized unsupported-policy error instead of silently changing
the route or trust behavior.

| Control | Dart IO | Android Cronet | Apple URLSession |
| --- | --- | --- | --- |
| Platform trust | Supported by default | Supported by default | Supported by default |
| SPKI pinning | Unsupported; fails closed | Supported by the selected provider | Supported |
| Custom trust anchors | Supported where Dart IO can load them | Unsupported by the selected provider | Supported through platform trust APIs |
| `system()` proxy | Supported | Provider/system managed | Supported |
| `direct()` proxy | Supported | Unsupported by the selected provider | Supported |
| Explicit `http(...)` proxy | Supported, including Basic auth | Unsupported by the selected provider | Supported, including HTTPS CONNECT where CFNetwork permits |
| Explicit `https(...)` proxy endpoint | Unsupported | Unsupported | Unsupported by the shared mapping |
| mTLS/client identity | Unsupported | Unsupported in the selected provider | Unsupported |

An HTTP proxy endpoint can carry an HTTPS destination through CONNECT; that is
different from configuring an HTTPS proxy endpoint. Never use trust-all
configuration, log proxy credentials, or put real pin material in examples.
For retry, authentication, cookies, caching, resilience, protocol preference,
and custom application policies, follow the [policy defaults and customization
guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md).

## What this package does not promise

- It does not guarantee H3 on every request or every network.
- It does not provide the browser transport; use the separate
  [`alphax_web`](https://pub.dev/packages/alphax_web) package for Web.
- It does not expose Cronet, URLSession, Flutter channel, FFI, C++, Rust, or
  libcurl types through the core API.
- It does not make unsupported TLS or proxy policies silently succeed.
- It makes no universal performance, zero-copy, or “fastest client” claim.

Authentication, cookies, caching, retries, and generic resilience are opt-in
pure-Dart middleware from [`alphax`](https://pub.dev/packages/alphax). This package only
selects and implements native/Dart IO transports; it does not enable those
policies automatically.

## Continue learning

- [Core AlphaX API](https://pub.dev/packages/alphax)
- [Browser Fetch transport](https://pub.dev/packages/alphax_web)
- [Dio adapter](https://pub.dev/packages/alphax_dio)
- [package:http bridge](https://pub.dev/packages/alphax_http)
- [Testing helpers](https://pub.dev/packages/alphax_test)
- [Waypoint reference app](https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint)
- [Migration guide](https://github.com/auvana-ventures/alphax/blob/main/docs/MIGRATION.md)
- [Usage and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md)
- [1.0 release notes](https://github.com/auvana-ventures/alphax/blob/main/docs/ALPHAX_1_0_RELEASE_NOTES.md)

The `1.1.0` release adds the application-facing native factory. Android, iOS,
and macOS support remains provider/platform dependent, while Dart IO is the
truthful fallback on Linux and Windows. The facade is additive and the
explicit transport APIs remain available for controlled provider selection.
