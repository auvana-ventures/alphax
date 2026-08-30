# AlphaX

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/branding/alphax-logo-light.svg">
    <img src="assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="340">
  </picture>
</p>

<p align="center"><strong>One client API. Native transport where it matters. Honest protocol reporting.</strong><br>
Cross-platform HTTP for Dart and Flutter, with streaming, files, policies, and
the transport each platform can actually provide.</p>

<p align="center">
  <a href="docs/ALPHAX_1_0_RELEASE_NOTES.md">AlphaX 1.0</a> ·
  <a href="docs/USAGE_AND_CUSTOMIZATION.md">Usage and customization</a> ·
  <a href="examples/waypoint/README.md">Waypoint example</a> ·
  <a href="docs/MIGRATION.md">Migration guide</a> ·
  <a href="LICENSE">Apache-2.0</a>
</p>

## What is AlphaX?

AlphaX is a cross-platform HTTP client and policy layer for Dart and Flutter.
It gives application code one request, response, streaming, file, cancellation,
timeout, middleware, and error model while the deployment package selects the
transport that belongs to the platform.

The stable `1.0.0` package family is published. AlphaX does not guarantee H3,
claim universal performance, or pretend that browser APIs expose native
controls they do not provide.

## At a glance

| Area | AlphaX 1.0 provides |
| --- | --- |
| Client API | Requests, responses, headers, bodies, streams, files, cancellation, timeouts, redirects, and normalized errors |
| Native transports | Android Cronet/HttpEngine, Apple URLSession, and Dart IO fallback through `alphax_native` |
| Browser transport | Fetch through `alphax_web`, with browser-owned TLS, CORS, proxy, cookie, and protocol behavior |
| Protocols | H1/H2/H3 where a native provider negotiates them; H1 Dart IO fallback; browser protocol metadata remains unknown to Dart |
| Policies | Opt-in authentication, replay-aware retries, cookies, private cache, and resilience middleware |
| Streaming protocols | Incremental SSE parsing and a separate text/binary WebSocket lifecycle; reconnect remains caller-owned |

## Quick start

For native Flutter, install one deployment package and use one entry import:

```sh
flutter pub add alphax_native
```

```dart
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = await createAlphaXClient();
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

The factory creates one reusable client and selects Cronet/HttpEngine on
Android, URLSession on iOS/macOS, or Dart IO on Linux/Windows. For Web, install
`alphax_web` and use the same-named synchronous factory:

```dart
import 'package:alphax_web/alphax_web.dart';

final client = createAlphaXClient();
```

### One Flutter project targeting native and Web

If one Flutter project ships to Android, iOS, desktop, and the browser, declare
both deployment packages and select the provider behind an app-local
conditional export. `alphax_native` is for native Flutter builds;
`alphax_web` is for Flutter Web. Do not import `alphax_native` from code that is
compiled for the browser.

```yaml
dependencies:
  alphax_native: ^1.0.0
  alphax_web: ^1.0.0
```

For example, keep the platform choice in a small application-owned layer:

```dart
// lib/networking/alpha_client.dart
export 'alpha_client_native.dart'
    if (dart.library.js_interop) 'alpha_client_web.dart';
```

```dart
// lib/networking/alpha_client_native.dart
import 'package:alphax_native/alphax_native.dart' as native;

Future<native.AlphaXClient> createAppClient() => native.createAlphaXClient();
```

```dart
// lib/networking/alpha_client_web.dart
import 'package:alphax_web/alphax_web.dart' as web;

Future<web.AlphaXClient> createAppClient() async => web.createAlphaXClient();
```

Shared application code then imports only the app-owned entry point:

```dart
final client = await createAppClient();
```

Both façades return the same `AlphaXClient` core type. The platform-specific
choice changes the provider, not the request code.

## Choose the package by deployment path

Install the direct package for the application boundary, then add only the
optional package for the job you need:

| Package | Purpose |
| --- | --- |
| [`alphax`](https://pub.dev/packages/alphax) | Core client, request/response contracts, policies, streaming, files, SSE, and WebSocket contract |
| [`alphax_native`](https://pub.dev/packages/alphax_native) | Native Flutter transports and automatic client factory |
| [`alphax_web`](https://pub.dev/packages/alphax_web) | Browser Fetch transport and browser WebSocket connector |
| [`alphax_dio`](https://pub.dev/packages/alphax_dio) | Focused Dio `HttpClientAdapter` for existing Dio/Retrofit applications |
| [`alphax_http`](https://pub.dev/packages/alphax_http) | `package:http` bridge for Chopper, GraphQL HTTP, and injectable SDKs |
| [`alphax_generator`](https://pub.dev/packages/alphax_generator) | Dev-time direct typed REST source generation |
| [`alphax_transform`](https://pub.dev/packages/alphax_transform) | Optional one-shot JSON transform for already-buffered payloads |
| [`alphax_test`](https://pub.dev/packages/alphax_test) | Development-only deterministic fakes and conformance helpers |

Native and Web deployment packages already depend on `alphax`, so ordinary
applications do not need to declare the core package directly. Pure Dart
applications choose `alphax` and provide an `AlphaXTransport` implementation.

## Platform and transport matrix

| Platform | Recommended transport | Protocol boundary |
| --- | --- | --- |
| Android | Cronet / supported HttpEngine provider | H1/H2/H3 where the provider, server, and network negotiate it |
| iOS | URLSession | H1/H2/H3 where the provider, server, and network negotiate it |
| macOS | URLSession | H1/H2/H3 where the provider, server, and network negotiate it |
| Linux | Dart IO | H1 fallback; H2/H3 are not advertised |
| Windows | Dart IO | H1 fallback; current-gate validation remains unverified |
| Web | Browser Fetch | Browser-managed TLS/proxy/protocol behavior; Dart cannot report the negotiated HTTP version authoritatively |

H3 is opportunistic, never guaranteed, and depends on the provider, server,
proxy, and network. A protocol preference may fall back; a protocol requirement
fails closed when the exact protocol cannot be observed or enforced.

## Why AlphaX?

- Keep request code independent of a particular transport engine.
- Use platform-native HTTP implementations where they are available.
- Inspect the protocol that actually completed a request instead of assuming H3.
- Compose opt-in authentication, retry, cookie, cache, and resilience policies.
- Stream responses and file transfers with cancellation and bounded delivery.
- Keep existing Dio, Retrofit, `package:http`, Chopper, and GraphQL HTTP code at
  its normal adapter seam.

## Choose a starting point

| If your goal is… | Start here |
| --- | --- |
| Send a normal request | [Quick start](#quick-start) |
| Stream or cancel work | [Streaming and cancellation](#streaming-and-cancellation) |
| Parse Server-Sent Events | [Server-Sent Events](#server-sent-events) |
| Open a WebSocket | [WebSocket](#websocket) |
| Upload or download a file | [Upload and download](#upload-and-download) |
| Inspect protocol completion | [Capabilities and protocol reporting](#capabilities-and-protocol-reporting) |
| Add retries, tokens, cookies, cache, or resilience | [Policy guide](docs/POLICIES.md) |
| Configure TLS, pins, or proxies | [Native transport guide](packages/alphax_native/README.md#configure-tls-and-proxy-behavior) |
| Keep an existing Dio application | [`alphax_dio`](https://pub.dev/packages/alphax_dio) |
| Test without a network | [`alphax_test`](https://pub.dev/packages/alphax_test) |
| Offload a profiled JSON transform | [`alphax_transform`](https://pub.dev/packages/alphax_transform) |

## Choose your level of control

### Start simple

Add `alphax_native`, import its entry point, and use `createAlphaXClient()`.
Normal request code does not need platform branching or manual transport
assembly. For Web, add `alphax_web` and use its same-named synchronous factory.

### Configure portable policies

Configure the existing client middleware and transport-construction policies at
the native façade:

```dart
Future<AlphaXClient> createConfiguredClient() => createAlphaXClient(
  middleware: <AlphaXMiddleware>[AlphaXRetryMiddleware()],
  tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
  proxyPolicy: const AlphaXProxyPolicy.system(),
);
```

Web accepts middleware and browser credential mode through
`createAlphaXClient(withCredentials: true)`. Timeout, cancellation, redirect,
progress, protocol preference, and protocol requirement remain request-level
settings. These controls express application intent while the selected
provider/browser decides which platform operations can honor it.

### Take control of the transport

Explicit transport construction remains available for troubleshooting, testing,
or a deliberate provider choice:

```dart
Future<void> main() async {
final client = AlphaXClient(
  transport: await createAlphaXTransport(),
);

final dartIoClient = AlphaXClient(
  transport: DartIoTransport(),
);
await client.close();
await dartIoClient.close();
}
```

`AndroidCronetTransport.create()`, `AppleUrlSessionTransport.create()`, and
the browser equivalent `WebFetchTransport()` remain available from their
integration packages.

### Bring your own transport

Implement the public `AlphaXTransport` contract and pass it to
`AlphaXClient(transport: ...)`. The contract keeps provider types out of core;
custom implementations must preserve cancellation, streaming, completion
metrics, capability reporting, and close semantics. See the
[customization guide](docs/USAGE_AND_CUSTOMIZATION.md#bring-your-own-transport).

## Using a package that expects `package:http`?

Install the optional [`alphax_http`](packages/alphax_http/README.md) seam (and
keep the platform package that creates your AlphaX client):

```sh
flutter pub add alphax_http
```

This lets Chopper, GraphQL HTTP clients, generated clients with an injectable
`http.Client`, and ordinary `package:http` SDKs use one configured AlphaX client:

```dart
import 'package:alphax_http/alphax_http.dart';
import 'package:alphax_native/alphax_native.dart';

final alpha = await createAlphaXClient();
final httpClient = AlphaXHttpClient(alpha);
```

The bridge is an ecosystem escape hatch, not part of the ordinary AlphaX
installation. It preserves package:http request/response streaming and
standard error/status behavior, while AlphaX middleware, TLS, proxy, and
transport selection remain below the bridge. AlphaX-only capabilities such as
protocol metadata, completion metrics, progress, native file paths, and rich
request controls require direct AlphaX usage.

## Typed REST with AlphaX

For a new typed API declaration, the optional dev-time
[`alphax_generator`](packages/alphax_generator/README.md) package emits a
client that calls `AlphaXClient` directly:

```text
AlphaX annotations → alphax_generator → AlphaXClient → AlphaX transport
```

Native setup remains one deployment dependency and one entry import; the
generator belongs in development tooling:

```yaml
dependencies:
  alphax_native: ^1.0.0

dev_dependencies:
  alphax_generator: ^1.0.0
  build_runner: ^2.16.0
```

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

Future<void> main() async {
  final alpha = await createAlphaXClient();
  final users = UsersApi(alpha);
  // Reuse `users` for requests, then close `alpha` with the application scope.
  await alpha.close();
}
```

Run `dart run build_runner build`. Serialization stays caller-owned through
decoder expressions such as `User.fromJson`; middleware, retries, auth,
cookies, cache, resilience, TLS, proxy, cancellation, timeouts, and protocol
options remain AlphaX concerns. The generated service borrows the supplied
client and never closes it. The complete compile-tested fixture is in
[`examples/typed_rest`](examples/typed_rest).

If an existing application already uses Retrofit, keep its generated Dio path
and use [`alphax_dio`](packages/alphax_dio/README.md). The direct generator is
an additional AlphaX-owned choice, not a Retrofit replacement.

## Ecosystem compatibility

These compatibility paths use the existing library injection seams; they do not
transfer ownership of that library's protocol or serialization semantics to
AlphaX.

| Ecosystem | Classification | Path |
| --- | --- | --- |
| Dio / Retrofit | `SUPPORTED_VIA_ADAPTER` | Dio → `AlphaXDioAdapter` → AlphaX |
| `package:http` / Chopper | `SUPPORTED_VIA_ADAPTER` | `http.Client` → `AlphaXHttpClient` → AlphaX |
| GraphQL HTTP | `SUPPORTED_VIA_ADAPTER` | `HttpLink` → `AlphaXHttpClient` → AlphaX |
| OpenAPI direct output | `PROOF_ONLY` | Official template → `alphax_generator` → AlphaX |
| OpenAPI generated Dio/http clients | `SUPPORTED_VIA_ADAPTER` | Injectable generated client → existing adapter |
| Protobuf | `COMPATIBLE_CALLER_LAYER` | `writeToBuffer`/`mergeFromBuffer` with AlphaX bytes |
| GraphQL WebSocket | `PROOF_ONLY` | Caller bridge → AlphaX WebSocket session |
| gRPC | `DEFERRED_POST_1_0` | Separate RPC/runtime boundary |

See the compile-tested [OpenAPI](examples/openapi_template_proof/README.md) and
[Protobuf](examples/protobuf_interop/README.md) recipes. These results do not
add GraphQL, OpenAPI, Protobuf, or gRPC runtime packages to AlphaX.

## Using Retrofit

Retrofit generated clients are supported through the existing Dio boundary:

```text
retrofit generated client → Dio → AlphaXDioAdapter → AlphaX
```

Keep the normal Retrofit annotations and generated constructor. Configure the
Dio instance with an AlphaX client once, then pass that Dio instance to the
generated API:

```dart
import 'package:alphax_dio/alphax_dio.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'users_api.g.dart'; // generated by retrofit_generator

@RestApi(baseUrl: 'https://example.com/')
abstract class UsersApi {
  factory UsersApi(Dio dio, {String? baseUrl}) = _UsersApi;

  @GET('/health')
  Future<String> health();
}

Future<void> main() async {
  final alphaClient = await createAlphaXClient();
  final dio = Dio()
    ..httpClientAdapter = AlphaXDioAdapter(alphaClient);
  try {
    final api = UsersApi(dio);
    print(await api.health());
  } finally {
    dio.close(force: true);
  }
}
```

Add `retrofit` to the application and `retrofit_generator` plus `build_runner`
to its development tooling, then run the generator to create
`users_api.g.dart`. The API shape above is compile-tested against the
maintained generator; the concrete DTO and endpoint annotations remain owned
by the application.

Retrofit remains the API/code-generation layer, Dio remains the application
client, and AlphaX owns the injected transport and policy boundary. Add
`retrofit` and `retrofit_generator` to the application/tooling package; they
are not dependencies of AlphaX. The maintained generator fixture covers typed
JSON, nullable and wrapped responses,
streaming, cancellation, multipart file upload, errors, redirects, and
progress through this same adapter path. See [Using Retrofit in the full user
guide](docs/USAGE_AND_CUSTOMIZATION.md#using-retrofit).

## Defaults are explicit

AlphaX keeps application policy explicit:

| Behavior | Default |
| --- | --- |
| Transport | Native `createAlphaXClient()` delegates to `createAlphaXTransport()`; Web `createAlphaXClient()` constructs browser Fetch; `alphax` core still requires injection. |
| Retry, authentication, cookies, cache, resilience | Off until middleware is added. |
| TLS | Verified platform trust. |
| Proxy | System-managed routing on the selected transport. |
| Protocol | Provider/server/proxy/network negotiation; H3 is not guaranteed. |

When you need one of these behaviors, add the corresponding middleware or
configure the selected transport before creating the client. The [policy
defaults and customization guide](docs/POLICIES.md) provides beginner-friendly
steps and examples for retries, token refresh, cookie/cache store seams,
authenticated-cache identity scoping, circuit breaking, protocol requirements,
proxy routing, and SPKI pin rotation.

## What AlphaX controls vs what the platform controls

AlphaX controls the transport contract, request/response/body model, policy
composition, protocol preference versus fail-closed requirement, capability and
fallback reporting, normalized errors, bounded streaming, and transport-neutral
file operations. Its retry, authentication, cookies, cache, and resilience
policies are opt-in.

Cronet/HttpEngine, URLSession, Dart IO, or the browser control the actual route,
provider pools, QUIC availability, TLS session resumption, OS/browser proxy and
cookie behavior, and protocol negotiation. AlphaX reports what the provider
knows and does not turn capability into proof that one request used H3. See the
[full customization matrix](docs/USAGE_AND_CUSTOMIZATION.md#10-portable-configuration-matrix)
for defaults and unsupported behavior.

## Streaming and cancellation

Response streams are single-consumption and support Dart pause/resume
semantics. Native adapters use bounded delivery windows.

```dart
final token = AlphaXCancellationToken();
final pending = client.get(
  Uri.https('example.com', '/large-response'),
  cancellationToken: token,
);
token.cancel('screen closed');

try {
  final response = await pending;
  await for (final chunk in response.stream) {
    // Process each chunk without requiring a complete-body buffer.
    print('received ${chunk.length} bytes');
  }
} on AlphaXCancellationException {
  // Cancellation is distinct from transport failure.
}
```

## Server-Sent Events

Use the dedicated `package:alphax/sse.dart` parser on the existing bounded
AlphaX response stream. It incrementally decodes UTF-8 and recognizes LF,
CRLF, and CR line endings without buffering the complete response.

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax/sse.dart';

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

`AlphaXSseEvent.retry` is the valid non-negative wire value in milliseconds;
`id` preserves the distinction between an absent and empty field. The parser
does not reconnect, send `Last-Event-ID`, or require a particular HTTP
`Content-Type`; the caller owns those decisions and cancellation. Native
transports retain their TLS/proxy and bounded-streaming behavior. On Web, the
request uses browser Fetch, so CORS, TLS, proxy routing, and connection
behavior remain browser-owned. See the [compile-tested core example](packages/alphax/example/sse.dart).

## WebSocket

WebSocket is a separate full-duplex lifecycle, not an `AlphaXTransport.send()`
request. Native and browser entry packages expose the same small connector and
session contract through their deployment import:

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
    final message = await firstMessage;
    print(message);
  } finally {
    await socket.close();
  }
}
```

`AlphaXWebSocketMessage` preserves text and binary messages, and
`socket.negotiatedSubprotocol` reports the provider's authoritative result.
`socket.done` reports the terminal close code, reason, and origin. The
connector performs no automatic reconnect, retry, backoff, replay, or resend.

The browser connector uses the browser WebSocket API. Browser TLS, origin,
cookies, CSP, network policy, and arbitrary connection headers remain
browser-owned; the portable AlphaX contract therefore does not accept custom
headers and reports that capability as unsupported. Native uses the maintained
`package:web_socket` Dart IO path rather than assuming the selected HTTP
transport also owns WebSockets. See the compile-tested native and Web examples:
[`alphax_native/example/websocket.dart`](packages/alphax_native/example/websocket.dart)
and [`alphax_web/example/websocket.dart`](packages/alphax_web/example/websocket.dart).

## Upload and download

The public API is the same whether a platform uses a Dart stream or a native
file-backed task. `AlphaXLocalFileSource` and `AlphaXLocalFileTarget` are
provided by `alphax_native`.

```dart
final download = await client.download(
  Uri.https('example.com', '/archive.bin'),
  to: AlphaXLocalFileTarget('/tmp/archive.bin'),
);

final upload = await client.upload(
  Uri.https('example.com', '/upload'),
  from: AlphaXLocalFileSource('/tmp/archive.bin'),
  onUploadProgress: (progress) => print(progress.bytesTransferred),
);
print('${download.bytesTransferred} downloaded, ${upload.bytesTransferred} uploaded');
```

Native file-backed transfer is a minimal-copy implementation detail; AlphaX
does not call it zero-copy.

## Capabilities and protocol reporting

These concepts are deliberately separate:

- **Capability**: what the current provider can support.
- **Preference**: what a request asks the provider to prefer.
- **Negotiated protocol**: what the completed operation actually used.
- **Fallback**: metadata explaining why a preferred protocol was not used.

```dart
final request = AlphaXRequest(
  method: HttpMethod.get,
  uri: Uri.https('example.com', '/'),
  protocolPreference: AlphaXProtocolPreference.http3,
);
final response = await client.send(request);
final finalMetrics = await response.completionMetrics;
final fallback = await response.completionProtocolFallback;
print('capability: ${client.capabilities.http3.name}');
print('actual: ${finalMetrics.negotiatedProtocol.name}');
print('fallback: ${fallback?.reason.name ?? 'none'}');
```

`unknown` is a valid protocol state. It never means HTTP/1.1 and never proves
fallback. URLSession may report the authoritative protocol only through
completion metrics.

To fail closed instead of allowing protocol fallback, set
`protocolRequirement`. A Dart IO fallback rejects H2/H3 requirements because
`dart:io` cannot prove the final negotiated protocol:

```dart
final response = await client.send(
  AlphaXRequest(
    method: HttpMethod.get,
    uri: Uri.https('example.com', '/sensitive-operation'),
    protocolPreference: AlphaXProtocolPreference.http3,
    protocolRequirement: AlphaXProtocolRequirement.http3,
  ),
);
```

## Platform and protocol support

| Target | Transport | 1.0 protocol boundary |
| --- | --- | --- |
| Android API 24+ | Supported non-fallback Cronet/HttpEngine provider | H1/H2/H3; the provider and network determine whether an individual request uses H3 |
| iOS 15+ | URLSession | H1/H2/H3; the OS, provider, server, and network determine the negotiated protocol |
| macOS 12+ | URLSession | H1/H2/H3; the OS, provider, server, and network determine the negotiated protocol |
| Linux | Dart IO fallback | H1 only |
| Windows | Dart IO fallback | H1 only; `WINDOWS_SUPPORTED_UNVERIFIED_IN_CURRENT_GATE` |
| Web | `alphax_web` Browser Fetch transport | H1/H2/H3 may be used by the browser, but Dart cannot authoritatively report the negotiated protocol; H3 requirements fail closed |

H3 preference may legitimately negotiate H2 or H1. The actual protocol and
fallback metadata must be inspected for each completed request. A protocol
requirement fails closed when the exact protocol is not observed. Dart IO
cannot authoritatively report H2/H3 and therefore does not advertise them.

## Supporting package roles

| Package | Purpose | 1.0 status |
| --- | --- | --- |
| [`alphax`](packages/alphax) | Pure-Dart transport-neutral HTTP and WebSocket contracts | Published `1.0.0` |
| [`alphax_native`](packages/alphax_native) | Native entry façade, HTTP adapters, and Dart IO WebSocket connector | Published `1.0.0` |
| [`alphax_test`](packages/alphax_test) | Fakes and shared conformance helpers | Published `1.0.0` |
| [`alphax_dio`](packages/alphax_dio) | Focused Dio 5.x `HttpClientAdapter` boundary | Published `1.0.0` |
| [`alphax_http`](packages/alphax_http) | Optional `package:http` `BaseClient` compatibility seam | Published `1.0.0` |
| [`alphax_web`](packages/alphax_web) | Web entry façade, browser Fetch adapter, and browser WebSocket connector | Published `1.0.0` |
| [`alphax_transform`](packages/alphax_transform) | Explicit one-shot isolate JSON transform for buffered payloads | Published `1.0.0` |
| [`alphax_generator`](packages/alphax_generator) | Dev-time direct AlphaX typed REST source generator | Published `1.0.0` |

There is no AlphaX-owned C++ engine, production Rust transport, libcurl
dependency, telemetry SDK, GraphQL client, or WebSocket engine in the 1.0
architecture. The direct typed REST generator is dev-time tooling, not a second
runtime. The SSE parser is a small `alphax` sub-library over the
existing HTTP stream, and the WebSocket contract is a separate lifecycle seam
adapted by the deployment packages. The optional `alphax_http` package is only an
`http.Client` compatibility seam; GraphQL and Chopper remain caller-owned.
Retry, authentication, cookie, cache, and generic
resilience policies are opt-in pure-Dart middleware. Browser support is a
separate `alphax_web` Fetch adapter rather than a native transport in the core.

## Capability boundaries and known limitations

Capability is not actual negotiation: it describes what the selected provider
can support, while completion metadata describes what one request used.
Preference is not requirement: preference permits fallback, while a requirement
fails closed. Dart IO cannot authoritatively report H2/H3. Provider-limited TLS
or proxy controls fail closed with normalized errors.

TLS certificate verification uses platform defaults and is enabled by default.
`AlphaXTlsPolicy` can add or replace trust anchors where the transport supports
it and can configure multiple host-scoped SPKI SHA-256 pins on Android and
Apple. Dart IO reports pinning unsupported and fails explicitly rather than
using a trust-all callback. `AlphaXProxyPolicy` supports system/direct/HTTP
routes where each provider can honor them; the separate HTTPS-proxy endpoint
scheme is unsupported by the selected transports. Unsupported modes fail
explicitly.
The selected Android Cronet API is system-proxy-only, while Apple uses
URLSession/CFNetwork proxy configuration and rejects explicit HTTPS-proxy
configuration. `AlphaXClientIdentity` is an opaque security-reference model;
mTLS is not implemented by the 1.0 adapters.

Known 1.0 limitations are Linux/Windows H1-only fallback, browser protocol
metadata being unavailable, unimplemented mTLS, unavailable explicit HTTPS-
proxy endpoint parity, Android custom trust anchors being unsupported by the
selected provider, Dart IO and browser SPKI pinning being unsupported, and
Swift Package Manager packaging being deferred; CocoaPods is the Apple
packaging path. Policy middleware uses a queued in-memory cookie store and a
private bounded in-memory cache by default; credential-bearing cache reuse is
opt-in by identity scope and responses that set cookies are not cached;
caller-owned stores may provide persistence, automatic retries remain limited to safe replayable buffered
operations, and token storage/application-specific authentication remains
caller-owned.

The Apple adapter strips `Authorization`, `Proxy-Authorization`, and `Cookie`
on cross-origin redirects. Android rejects a sensitive cross-origin redirect
when the selected Cronet provider cannot replace pending headers. The focused
physical-device assertion remains part of release validation.

Native/platform exceptions are retained only as diagnostic causes. Applications
should handle the public AlphaX error categories such as DNS, connection, TLS,
timeout, cancellation, redirect, request body, response body, unsupported
capability, and transport/internal errors.

Timeouts are AlphaX semantic timers. A transport may emulate a category, and
the API does not promise portable DNS/TCP/TLS phase precision.

## Migration and examples

See [migration guidance](docs/MIGRATION.md) for `package:http` and Dio mapping.
The beginner-friendly [Waypoint reference app](examples/waypoint/README.md)
demonstrates the packages in a travel-planning interface. The compile-tested
entry examples are [`alphax_native/example/main.dart`](packages/alphax_native/example/main.dart)
and [`alphax_web/example/main.dart`](packages/alphax_web/example/main.dart);
the existing [basic reference app](examples/basic/README.md) remains available
for the broader request-surface demonstration.

## Architecture and evidence

The public contract stays in `alphax`; deployment entry points are isolated in
the integration packages:

```text
Dart application
      ├── alphax (pure-Dart contracts)
      │     └── AlphaXClient(transport: ...)
      ├── alphax_native entry facade
      │     └── createAlphaXClient() → createAlphaXTransport()
      │     ├── Dart IO fallback
      │     ├── Android Cronet/HttpEngine
      │     ├── iOS/macOS URLSession
      │     └── WebSocket connector → maintained Dart IO provider
      └── alphax_web entry facade → Browser Fetch (separate package)
            └── WebSocket connector → browser WebSocket
```

See the [AlphaX 1.0 release notes](docs/ALPHAX_1_0_RELEASE_NOTES.md), the
[accepted transport ADR](docs/decisions/0004-platform-native-mobile-transports.md),
the [1.0 requirements audit](docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md),
and the [cross-transport validation report](docs/phase1e-cross-transport-validation.md).
Historical benchmark results remain evidence for measured HTTP/1.1
workloads; see the [historical benchmark documentation](docs/benchmarks.md) and
its linked result summaries. They were not rewritten as H2/H3 performance
claims.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md),
and the relevant architecture documents before changing a transport or public
contract. AlphaX is licensed under Apache-2.0; see [LICENSE](LICENSE).
