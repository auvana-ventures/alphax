# AlphaX usage and customization

This is the user guide for the AlphaX source tree. The coordinated `1.0.0-rc.4`
release remains the published baseline; committed rc.5 feature work A–E and
bounded F/G/H resolution are complete under the
[1.0 feature freeze](ALPHAX_1_0_FEATURE_FREEZE.md). No rc.5 package is
published until the release-preparation task. `rc.3` is the historical
predecessor.

## 1. Choose the deployment path

Choose the package that owns the deployment boundary. The native and Web entry
points re-export the public core API, so an ordinary application needs only its
deployment package directly:

| Deployment path | Direct package | Ordinary entry |
| --- | --- | --- |
| Native Flutter | [`alphax_native`](../packages/alphax_native/README.md) | `createAlphaXClient()` |
| Browser Web | [`alphax_web`](../packages/alphax_web/README.md) | `createAlphaXClient()` |
| Pure Dart/custom transport | [`alphax`](../packages/alphax/README.md) | `AlphaXClient(transport: ...)` |

Supporting roles are opt-in:

- Existing Dio/Retrofit: [`alphax_dio`](../packages/alphax_dio/README.md) plus
  the platform deployment package and the application's Dio/Retrofit tooling.
- A library that expects `package:http`: [`alphax_http`](../packages/alphax_http/README.md)
  plus the platform deployment package and the application's framework/SDK.
- A new direct typed REST API: [`alphax_generator`](../packages/alphax_generator/README.md)
  as dev tooling plus the platform deployment package.
- Large buffered JSON after profiling: [`alphax_transform`](../packages/alphax_transform/README.md).
- Application tests: [`alphax_test`](../packages/alphax_test/README.md) as a
  dev dependency.

For native Flutter, the direct AlphaX declaration is sufficient because
`alphax_native` already depends on `alphax`:

```yaml
dependencies:
  alphax_native: ^1.0.0-rc.4
```

For browser Web, use the equivalent:

```yaml
dependencies:
  alphax_web: ^1.0.0-rc.4
```

## 2. The quickest start

### Flutter native

```dart
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = await createAlphaXClient();
  try {
    final response = await client.get(Uri.https('example.com', '/health'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

`createAlphaXClient()` delegates selection to the existing
`createAlphaXTransport()` logic: Android Cronet/HttpEngine, iOS/macOS URLSession,
or the reusable Dart IO fallback on other native Dart VM platforms. It
initializes exactly one transport before completing. Reuse the resulting client
for the lifetime of the feature or application scope.

### Web

```dart
import 'package:alphax_web/alphax_web.dart';

final client = createAlphaXClient();
```

This is synchronous because `WebFetchTransport` is constructed synchronously.
The package choice remains explicit: browser Fetch, CORS, TLS, proxy routing,
redirects, credentials, and protocol metadata remain browser-owned.

`alphax` itself still requires transport injection:

```dart
final client = AlphaXClient(
  transport: MyTransport(),
);
```

`AlphaXClient()` without a transport is not a supported constructor. This keeps
`alphax` pure Dart and transport-independent.

## 3. Choose your level of control

### Start simple

Use `createAlphaXClient()` from the package for the deployment path. The native
factory makes the production platform choice without `Platform.isAndroid`/
`Platform.isIOS` code in the application and uses verified platform TLS trust
plus the system proxy policy. The Web factory remains browser-backed and does
not claim native capabilities.

### Configure portable policies

Construct one native client with the existing ordered middleware and
transport-construction policies:

```dart
Future<AlphaXClient> createConfiguredClient() => createAlphaXClient(
  middleware: <AlphaXMiddleware>[AlphaXRetryMiddleware()],
  tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
  proxyPolicy: const AlphaXProxyPolicy.system(),
);
```

For Web, the supported factory options are middleware and browser credential
mode:

```dart
final webClient = createAlphaXClient(
  middleware: <AlphaXMiddleware>[AlphaXRetryMiddleware()],
  withCredentials: true,
);
```

Request-level timeout, cancellation, protocol preference/requirement, redirect,
and progress values remain on each request. Policies stay transport-neutral;
the selected provider or browser can reject a policy it cannot honor.

### Take control of the transport

Inject a concrete adapter when you need a deterministic or deliberate choice.
This is the unchanged explicit rc.4 path:

```dart
import 'package:alphax_native/alphax_native.dart';

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
`WebFetchTransport()` remain available for explicit provider control. The
Android and Apple constructors are asynchronous because provider/session
capabilities must be known before the first request.

### Bring your own transport

`AlphaXTransport` is an implementable public contract. Supply an implementation
to `AlphaXClient(transport: ...)` without forking AlphaX. A custom transport is
responsible for `capabilities`, `send`, `sendStreaming`, and `close`; it may
override `download` and `upload` when it can provide a specialized file path.
It must preserve cancellation, single-consumption stream behavior, bounded
delivery/backpressure where it offers streaming, accurate completion metrics,
protocol requirement semantics, normalized errors, and deterministic close
behavior. The default file methods can be inherited when a transport can use
the generic Dart stream path.

`AlphaXTransport` exposes only AlphaX types. Do not put Cronet, URLSession,
Flutter channel, native handle, or browser types in a custom transport's public
contract. Use [`alphax_test`](../packages/alphax_test/README.md) and its
conformance helper when validating an implementation.

## 3a. Using a package that expects `package:http`

Use the optional `alphax_http` compatibility seam when an existing library takes
an injected `package:http` client. The normal path remains one long-lived
AlphaX client wrapped once:

```dart
import 'package:alphax_http/alphax_http.dart';
import 'package:alphax_native/alphax_native.dart';

final alpha = await createAlphaXClient(
  middleware: <AlphaXMiddleware>[/* AlphaX policies */],
  tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
  proxyPolicy: const AlphaXProxyPolicy.system(),
);
final httpClient = AlphaXHttpClient(alpha);
```

Pass `httpClient` to Chopper, a GraphQL HTTP link, a generated client, or any
SDK that accepts `http.Client`. The compatibility package does not depend on
those frameworks and does not create an AlphaX client or transport inside
`send`.

The adapter borrows `alpha`: `httpClient.close()` is idempotent and blocks new
requests, but leaves the underlying AlphaX client and active response streams
usable. The owner of `alpha` must call `await alpha.close()` when its scope ends.
The adapter maps `AbortableRequest.abortTrigger` to AlphaX cancellation, but
`package:http` has no general contract for AlphaX cancellation reasons,
timeout phases, progress callbacks, protocol preference/requirement, actual
protocol, fallback metadata, completion metrics, native file paths, or rich
TLS/proxy construction controls. Configure the underlying AlphaX client first
for policies that belong below the compatibility boundary, and use AlphaX
directly when those request-level facts or controls are required.

For a streamed request body, the AlphaX transport receives the cancellation
token, but the adapter cannot independently cancel the body subscription because
`BaseClient` exposes no separate body-cancellation hook. Response-subscription
cancellation is forwarded to the underlying AlphaX stream when that stream
supports cancellation.

`followRedirects` and `maxRedirects` map to AlphaX's follow/manual redirect
policy. AlphaX still applies its credential-stripping and secure TLS/proxy
behavior. AlphaX has no authoritative reason phrase, persistent-connection
flag, or package:http redirect-hop field, so the bridge preserves unknowns as
unknown/default interface values.

### Configuration scope at a glance

| Scope | Examples | Lifetime/ownership |
| --- | --- | --- |
| Request | Timeout, cancellation token, redirect mode, protocol preference/requirement, progress callbacks, request body | One operation; supplied by the caller |
| Client | Middleware, retry/auth/cookie/cache/resilience state | Shared by the long-lived client; closed with the client |
| Transport/provider | TLS policy, proxy policy, provider/session construction, native file capability | Selected transport lifetime; enforced or rejected by that provider |

Portable policy types express caller intent, but they do not turn provider-owned
behavior into a portable guarantee. Check capabilities before dispatch when a
policy is optional, and inspect completion metrics for facts learned only after
the request runs.

## 4. What happens automatically?

| Target | Automatic selection from `alphax_native` | Protocol and authority |
| --- | --- | --- |
| Android API 24+ | Provider-selected Cronet/HttpEngine transport | H1/H2/H3 capability and actual negotiation depend on provider, server, proxy, and network. |
| iOS 15+ | URLSession transport | URLSession/OS, server, proxy, and network determine H1/H2/H3. |
| macOS 12+ | URLSession transport | Same URLSession family behavior as iOS. |
| Linux | Reusable Dart IO `HttpClient` | H1 only in AlphaX's truthful capability model. |
| Windows | Reusable Dart IO `HttpClient` | H1 only in AlphaX's truthful capability model. |
| Web | Explicit `createAlphaXClient()` from `alphax_web` | Fetch and the browser own protocol, TLS, proxy, CORS, and connection policy. Dart sees protocol `unknown`. |

Automatic means provider selection only. It does not turn on retries, cache,
cookies, authentication, resilience, JSON isolation, or unsafe security
overrides. A preference is not a requirement: request completion metadata is
the authority for the protocol that ran.

## 5. Client lifecycle and reuse

Create one client per useful application or feature scope and close it when that
scope ends. The adapters retain a reusable Dart `HttpClient`, Cronet engine, or
URLSession-backed native session. Reuse allows the provider to make its own
connection-pooling, multiplexing, TLS/session-resumption, and protocol choices.

```dart
final client = await createAlphaXClient();

try {
  // Reuse client for all requests in this scope.
  final first = await client.get(Uri.https('example.com', '/first'));
  final second = await client.get(Uri.https('example.com', '/second'));
  print('${first.statusCode}, ${second.statusCode}');
} finally {
  await client.close();
}
```

Do not create and close a transport for every request if the requests belong to
the same scope. A fresh client can fragment provider pools and discard reusable
session state. `close()` is idempotent.

## 6. Requests, bodies, streams, and files

The convenience methods are `get`, `post`, `put`, `patch`, `delete`, `head`,
and `options`. Use `AlphaXRequest` with `client.send` for complete control.
Bodies include `AlphaXBody.bytes`, `AlphaXBody.text`, `AlphaXBody.json`,
`AlphaXStreamBody`, `AlphaXFileBody`, and multipart bodies.

```dart
final response = await client.post(
  Uri.https('example.com', '/users'),
  body: AlphaXBody.json(<String, Object?>{
    'name': 'Ada',
    'active': true,
  }),
  headers: const AlphaXHeaders({'accept': 'application/json'}),
);
final body = await response.readAsJson();
print(body);
```

Response bodies can be read as bytes, strings, or JSON, or consumed once as a
stream. Native mobile adapters use bounded delivery for streamed responses.
The core does not make a second subscription or silently buffer a streamed
body.

For files, use the transport-neutral interfaces. `alphax_native` supplies
`AlphaXLocalFileSource` and `AlphaXLocalFileTarget`; native Android and Apple
paths can keep payload bytes in the provider/file path instead of routing every
byte through Dart. This is a minimal-copy implementation detail, not a
universal zero-copy claim.

```dart
final result = await client.download(
  Uri.https('example.com', '/archive.bin'),
  to: AlphaXLocalFileTarget('/tmp/archive.bin'),
);
print('${result.bytesTransferred} bytes downloaded');

final uploaded = await client.upload(
  Uri.https('example.com', '/archive'),
  from: AlphaXLocalFileSource('/tmp/archive.bin'),
);
print('${uploaded.bytesTransferred} bytes uploaded');
```

### Server-Sent Events

SSE is a parser sub-library over the existing AlphaX response stream. It uses
the same request, middleware, timeout, cancellation, transport, and bounded
streaming contracts; it does not add a transport or a reconnect loop.

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

`AlphaXSseParser` incrementally decodes strict UTF-8, handles LF/CRLF/CR
boundaries split across chunks, joins multiple `data` fields, ignores comments
and unknown fields, and exposes `id` plus a valid non-negative `retry` hint in
wire milliseconds. An absent ID remains `null`; an empty `id:` remains `''`.
The parser does not require a content-type header, automatically reconnect, or
send `Last-Event-ID`; retain those choices in the caller. The parser has
generous line and event-data limits to avoid unbounded memory growth; limit
violations and malformed UTF-8 are terminal errors.

On native platforms the selected AlphaX transport owns TLS, proxy policy,
connection behavior, and bounded delivery. On Web, Fetch, CORS, TLS, proxy
routing, and browser connection behavior remain authoritative. Browser SSE is
not EventSource parity. See the [compile-tested example](../packages/alphax/example/sse.dart).

### WebSocket

WebSocket uses a separate full-duplex connector/session contract; it is not
forced through `AlphaXTransport.send()` or `AlphaXClient`:

```dart
import 'package:alphax_native/alphax_native.dart';

Future<void> useSocket(Uri uri) async {
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

Use the same call shape with `package:alphax_web/alphax_web.dart` in a browser
deployment. The session preserves text/binary messages, reports the
provider-selected subprotocol, exposes terminal close information through
`done`, and performs no reconnect, replay, or retry. Connect cancellation also
cancels an active built-in session; cancelling the message subscription only
stops receiving, so the caller still closes the session.

The common contract intentionally has no arbitrary connection-header
parameter. The maintained `package:web_socket` abstraction and browser API do
not provide safe, consistent header support; built-in capabilities report
headers as unsupported. Use browser-managed cookies/origin or a protocol-level
authentication message where appropriate. Do not move authorization values into
query parameters automatically. Browser TLS, cookies, origin, CSP, and network
policy remain browser-owned; native WebSocket provider behavior is separate
from native HTTP transport selection. See the [compile-tested native example](../packages/alphax_native/example/websocket.dart)
and [Web example](../packages/alphax_web/example/websocket.dart).

## 7. Cancellation, timeouts, and progress

Cancellation is explicit and normalized:

```dart
final token = AlphaXCancellationToken();
final pending = client.get(
  Uri.https('example.com', '/large-response'),
  cancellationToken: token,
);

token.cancel('screen closed');
try {
  await pending;
} on AlphaXCancellationException {
  print('cancelled');
}
```

Use `AlphaXTimeouts(connect: ..., request: ..., read: ..., overall: ...)` on a
request. A transport may not expose every timing phase with equal precision;
unavailable precision remains unavailable rather than fabricated.

Upload and download progress are optional request callbacks. If no observer is
provided, native adapters retain byte accounting but do not construct or send
progress events across their Dart/native boundary. When requested, progress is
per provider read in this release, is monotonic, and is an observation stream;
completion metrics remain authoritative. Unsupported transports do not invent
progress.

## 8. Protocol preference, requirement, capabilities, and fallback

Use a preference when fallback is acceptable:

```dart
final response = await client.get(
  Uri.https('example.com', '/health'),
  protocolPreference: AlphaXProtocolPreference.http3,
);
final metrics = await response.completionMetrics;
print('actual: ${metrics.negotiatedProtocol.name}');
final fallback = await response.completionProtocolFallback;
print('fallback: ${fallback?.reason.name ?? 'none'}');
```

Use a requirement when the request must fail closed unless that exact protocol
is observed:

```dart
try {
  final response = await client.get(
    Uri.https('example.com', '/health'),
    protocolPreference: AlphaXProtocolPreference.http3,
    protocolRequirement: AlphaXProtocolRequirement.http3,
  );
  await response.readAsBytes();
} on AlphaXProtocolRequirementException {
  print('H3 was not authoritatively negotiated');
}
```

Capabilities are available from `client.capabilities` before dispatch. For
example, `client.capabilities.supportFor(AlphaXCapability.http3)` tells you
what the selected provider advertises. A capability does not prove that a
particular request used the capability; inspect completion metrics afterward.
`unknown` is a real state, especially on Web and at the beginning of native
streaming responses.

Unsupported security, proxy, protocol-requirement, and provider controls fail
closed with normalized AlphaX errors. The application should distinguish
`AlphaXUnsupportedCapabilityException`, `AlphaXTlsException` (including
pinning failures), `AlphaXTimeoutException`, `AlphaXCancellationException`,
`AlphaXProtocolRequirementException`, and `AlphaXProxyException` rather than
matching native NSError or Cronet exception types.

For example, keep cancellation and policy failures separate from ordinary
transport failures:

```dart
try {
  final response = await client.get(Uri.https('example.com', '/health'));
  await response.readAsBytes();
} on AlphaXCancellationException {
  print('caller cancelled the operation');
} on AlphaXProtocolRequirementException {
  print('the required protocol was not negotiated');
} on AlphaXTlsException {
  print('TLS validation or pinning failed');
} on AlphaXUnsupportedCapabilityException {
  print('the selected provider cannot honor the requested policy');
} on AlphaXTimeoutException {
  print('the request exceeded its configured timeout');
} on AlphaXProxyException {
  print('proxy setup or proxy authentication failed');
}
```

## 9. Defaults reference

These values come from the public constructors and constants in `alphax`.

| Feature | Default | Scope | Opt-in / limitation |
| --- | --- | --- | --- |
| Native transport selection | `createAlphaXClient()` delegates to `createAlphaXTransport()` | Transport setup | Web uses its explicit `createAlphaXClient()` facade; `alphax` core always requires injection. |
| TLS | Verified platform trust | Transport | Trust anchors, pins, and client identity are explicit and provider-dependent. |
| Proxy | `AlphaXProxyPolicy.system()` | Transport | Direct and explicit proxy modes are provider-dependent. |
| Protocol preference | `AlphaXProtocolPreference.auto` | Request | Actual protocol is provider/server/network-owned. |
| Protocol requirement | None | Request | Concrete requirements fail closed when unsupported or unobserved. |
| Redirects | Follow, maximum 5 | Request | Use `AlphaXRedirectPolicy` to reject or handle manually. |
| Timeouts | All unset | Request | Add `AlphaXTimeouts` explicitly. |
| Middleware | Empty list | Client | Nothing retries, authenticates, stores cookies/cache, or opens a circuit automatically. |
| Retry | Off; policy default is 3 total attempts when added | Client | Only replayable, eligible requests are retried; unsafe/non-replayable work is not silently replayed. |
| Authentication | Off | Client | Add `AlphaXAuthenticationMiddleware`; token ownership stays with the caller. |
| Cookies | Off in core | Client | Add `AlphaXCookieMiddleware(AlphaXCookieJar())` or a caller-owned store. Web browser cookies use `withCredentials` separately. |
| Cache | Off | Client | Add `AlphaXCacheMiddleware`; the built-in store is private in-memory with 100 entries/10 MiB defaults. |
| Resilience | Off | Client | Add `AlphaXResilienceMiddleware`; default threshold is 5 failures and 30 seconds open. |
| Progress | No callback | Request | Native progress traffic is suppressed when unused; requested progress is per provider read. |
| JSON decoding | Caller-side synchronous `readAsJson()` | Response/caller | `alphax_transform` is explicit, buffered, one-shot, and native-only. |

## 10. Portable configuration matrix

| Feature | Automatic/default behavior | Portable customization | Provider-dependent boundary | Unsupported behavior |
| --- | --- | --- | --- | --- |
| Transport selection | Native factory chooses Android, Apple, or Dart IO | Inject any `AlphaXTransport` | Web package selection is explicit | No hidden cross-package Web selection |
| HTTP protocol | `auto` preference | `AlphaXProtocolPreference` | Provider/server/proxy/network negotiate | A requirement fails closed |
| TLS verification | Platform trust on | `AlphaXTlsPolicy` | Trust-anchor and identity support varies | Unsupported policy throws |
| Custom trust | No custom anchors | `AlphaXTlsPolicy` anchors | Provider and OS support varies | Unsupported trust policy throws |
| SPKI pinning | Off | Host-scoped `AlphaXSpkiPin` | Android/Apple support; Dart IO/Web do not | Pin failure or unsupported policy fails |
| Proxy | System policy | `system()`, `direct()`, `http()`, `https()` | Provider and OS proxy support | Unsupported proxy mode throws |
| Redirects | Follow up to 5 | `AlphaXRedirectPolicy` | Header/security handling remains adapter-owned | Reject/manual modes are explicit |
| Retries | Off | `AlphaXRetryMiddleware` and `AlphaXRetryPolicy` | Replayability and HTTP safety | Non-replayable/unsafe work is not silently retried |
| Authentication | Off | `AlphaXAuthenticationMiddleware` | Token refresh is caller-supplied and buffered/replayable | No token is invented |
| Cookies | Off in core | `AlphaXCookieMiddleware` + `AlphaXCookieStore` | Browser-managed cookies are opaque to AlphaX | No persistence is assumed |
| Cache | Off | `AlphaXCacheMiddleware` + `AlphaXCacheStore` | Storage durability/permissions are caller-owned | Credentialed reuse needs an identity scope |
| Streaming | Single-consumption response stream | `sendStreaming`, pause/resume, body APIs | Bounded delivery is adapter-owned | Unsupported stream capability fails |
| File transfer | Generic Dart file abstraction | `download`/`upload` with `AlphaXFileSource/Target` | Native file paths are available in selected native adapters | Web/native-file claims are not made |
| Progress | No observer, no native progress event | Request progress callbacks | Provider callback granularity varies | Unsupported progress is not fabricated |
| Cancellation | Caller token and client close | `AlphaXCancellationToken` | Provider cancellation mapping | Cancellation remains distinct from timeout |
| Timeouts | Unset | `AlphaXTimeouts` | Phase precision varies | No fabricated phase timing |
| Resilience | Off | `AlphaXResilienceMiddleware` | Policy is generic, not provider-specific | Circuit state is client-owned |
| JSON transformation | Synchronous caller-side decode | Explicit `alphax_transform.decodeJson` | Native isolate availability | Web helper fails closed |
| Metrics/capabilities | Honest available fields only | `client.capabilities`, response completion metrics | Provider reporting differs | Unknown/null remains visible |

## 11. What AlphaX controls versus the platform

AlphaX controls the transport contract, request/response/body abstractions,
portable protocol preference and requirement semantics, capability and fallback
reporting, middleware composition, normalized errors, bounded stream contract,
file abstraction, and its opt-in retry/authentication/cookie/cache/resilience
policies.

The selected provider or platform controls the network route, QUIC availability,
TLS session resumption, underlying connection pool, OS proxy behavior, some
trust and client-identity capabilities, actual protocol negotiation, and native
file scheduling. On Web, the browser also controls CORS, TLS, proxy, cookie,
redirect, connection, and protocol authority. AlphaX reports those boundaries;
it does not turn a provider capability into a negotiation fact.

Provider-specific controls intentionally remain narrow. AlphaX currently exposes
portable TLS and proxy policy, not Cronet engine construction, URLSession
configuration objects, raw provider handles, DoH, QUIC 0-RTT, migration, or
provider logging. Those controls are either provider-managed, not portable, or
not part of the 1.0 contract.

## 12. Policies: retries, auth, cookies, cache, and resilience

Policies are ordered middleware and are disabled unless added. A client can
compose them without changing its transport:

```dart
Future<String?> currentAccessToken() async => 'token-from-app';

final client = AlphaXClient(
  transport: await createAlphaXTransport(),
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(accessToken: currentAccessToken),
    AlphaXCookieMiddleware(AlphaXCookieJar()),
    AlphaXRetryMiddleware(),
    AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
    AlphaXResilienceMiddleware(),
  ],
);
```

`currentAccessToken` in that example is an application-owned
`Future<String?> Function()`. Authentication state, durable cookie storage,
and durable cache storage remain application responsibilities. Place auth/cookie
middleware before cache middleware when the cache must see the effective
identity headers. The cache is private and buffered; credential-bearing reuse
requires a stable non-secret `identityKey`.

The default retry policy is bounded and replay-aware: three total attempts,
100 ms initial delay, exponential multiplier 2, five-second maximum delay, and
only selected statuses/errors for replayable eligible methods. It does not
silently retry a non-replayable stream or unsafe mutation. See
[`docs/POLICIES.md`](POLICIES.md) for the full policy guide.

## 13. TLS, pinning, and proxy recipes

Configure transport policy before constructing the client:

```dart
import 'package:alphax_native/alphax_native.dart';

Future<AlphaXClient> createPinnedClient({
  required String host,
  required String spkiSha256Base64,
  required DateTime pinExpiry,
}) async {
  final transport = await createAlphaXTransport(
    tlsPolicy: AlphaXTlsPolicy(
      pins: <AlphaXSpkiPin>[
        AlphaXSpkiPin(
          host: host,
          sha256SpkiBase64: spkiSha256Base64,
          expiresAt: pinExpiry,
        ),
      ],
    ),
    proxyPolicy: const AlphaXProxyPolicy.system(),
  );
  return AlphaXClient(transport: transport);
}
```

Pins add to normal certificate validation; they never make an invalid or
wrong-host certificate acceptable. Keep a primary and backup pin, expire both,
and obtain the digest from secure release configuration. Never use a trust-all
callback. Check `client.capabilities` or let initialization fail closed when a
selected provider cannot honor custom trust, pinning, identity, or proxy mode.

## 14. Large JSON and `alphax_transform`

Core JSON decoding remains explicit and synchronous:

```dart
final response = await client.get(Uri.https('example.com', '/profile'));
final decoded = await response.readAsJson();
```

For a profiled large buffered payload, opt in to the separate package:

```dart
import 'dart:typed_data';

import 'package:alphax_transform/alphax_transform.dart';

Map<String, Object?> userFromJson(Object? value) {
  final json = value! as Map<Object?, Object?>;
  return <String, Object?>{
    'id': json['id'],
    'name': json['name'],
  };
}

Future<Map<String, Object?>> decodeUser(List<int> bodyBytes) => decodeJson(
  bytes: Uint8List.fromList(bodyBytes),
  transform: userFromJson,
  debugName: 'user-json',
);
```

The helper needs already-buffered bytes, invokes one fresh `Isolate.run` on
native Dart VM targets, and requires a sendable transform and sendable result.
Cancellation after dispatch discards the worker result; it does not hard-kill
the worker or cancel the network read. Web background execution is unsupported
and fails closed. There is no automatic byte threshold, persistent worker, or
streaming JSON parser. See [`alphax_transform`](../packages/alphax_transform/README.md)
for measured guidance from the retained parsing study.

## 15. Dio interoperability

Dio remains a good client with its own methods, interceptors, transformers,
`FormData`, `CancelToken`, and response model. `alphax_dio` is a focused
`HttpClientAdapter` bridge; it does not claim full Dio API compatibility:

```dart
import 'package:alphax_dio/alphax_dio.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:dio/dio.dart';

Future<void> main() async {
  final alphaClient = await createAlphaXClient();
  final dio = Dio()..httpClientAdapter = AlphaXDioAdapter(alphaClient);
  try {
    final response = await dio.get<String>('https://example.com/health');
    print('${response.statusCode}: ${response.data}');
  } finally {
    dio.close(force: true);
  }
}
```

Dio owns its interceptor and transformer pipeline. AlphaX supplies the
transport, portable policy, normalized error, capability, protocol, and file
boundary below the adapter. Dio's current default transformer may decode large
JSON in an isolate; that is Dio response-processing behavior, not evidence that
one transport is faster. AlphaX core intentionally does not do this
automatically.

## 15A. Typed REST with AlphaX

New typed API declarations can use the optional dev-time
[`alphax_generator`](../packages/alphax_generator/README.md) package. It emits
ordinary Dart code that calls `AlphaXClient` directly; it does not use Dio,
Retrofit, or `package:http` at runtime.

```yaml
dependencies:
  alphax_native: ^1.0.0-rc.4

dev_dependencies:
  alphax_generator: ^1.0.0-rc.4
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

Future<UsersApi> createUsersApi() async => UsersApi(await createAlphaXClient());
```

Run `dart run build_runner build`. The complete native and Web declarations
and generated output are compile-tested in
[`examples/typed_rest`](../examples/typed_rest) and
[`examples/typed_rest_web`](../examples/typed_rest_web). An API declaration
uses AlphaX-owned annotations for common methods, path/query/header bindings,
JSON/text/bytes/stream/file/multipart bodies, typed decoders, cancellation,
and the existing request options bundle. `AlphaXBodyParam` is deliberately
distinct from the existing `AlphaXBody` runtime type.

Generated services borrow their `AlphaXClient`; the caller closes that client.
AlphaX middleware continues to own authentication, retry, cookies, cache,
resilience, and other transport/request policy. Non-2xx responses remain
AlphaX responses rather than becoming generated transport exceptions. Model
serialization remains caller-owned, so json_serializable and Freezed can be
used without becoming AlphaX runtime dependencies.

This is a bounded direct-generator foundation. OpenAPI templates and other
schema/generator integrations are separate follow-up decisions. Existing
Retrofit applications should continue to use the unchanged
`retrofit → Dio → AlphaXDioAdapter → AlphaX` path documented below.

### Using Retrofit

Retrofit remains the generated API layer and continues to use its ordinary
annotations and generated Dio constructor. The integration path is:

```text
retrofit generated client → Dio → AlphaXDioAdapter → AlphaX
```

The following wiring uses the public APIs verified by the Task 45 generated
fixture (the `UsersApi` type is produced by `retrofit_generator` from the
application's annotated interface):

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
to its development tooling, then run `dart run build_runner build` to create
the generated part. The annotated interface and DTOs remain application code.

Keep `retrofit`, `retrofit_generator`, and any DTO generator such as
`json_serializable` or Freezed in the application/tooling package. Retrofit
annotations, `RequestOptions`, `FormData`, `CancelToken`, response wrappers,
and generated progress/cancellation parameters remain Dio/Retrofit concerns;
AlphaX supplies the transport and policy boundary below the adapter. The
fixture validated GET path/query/header mapping, POST JSON, ordinary and
Freezed JSON DTOs, nullable responses, `HttpResponse`, response streams, Dio
errors, cancellation, redirect metadata, multipart file upload, and generated
progress callbacks. This does not claim that every generator-specific Dio
extension has been validated.

### Interoperability at a glance

| Ecosystem | AlphaX relationship |
| --- | --- |
| Dio | `SUPPORTED_VIA_ADAPTER` through `alphax_dio`. |
| Retrofit | `SUPPORTED_VIA_ADAPTER` through Dio; generated code remains unchanged. |
| `json_serializable` / Freezed | `COMPATIBLE_CALLER_LAYER`; fixture-validated model hooks. |
| OpenAPI-generated Dio clients | `SUPPORTED_VIA_ADAPTER` when Dio is injectable. |
| Chopper | `SUPPORTED_VIA_ADAPTER` through `alphax_http`. |
| GraphQL HTTP links | `SUPPORTED_VIA_ADAPTER` through `alphax_http`; GraphQL semantics remain caller-owned. |
| OpenAPI-generated `package:http` clients | `SUPPORTED_VIA_ADAPTER` when the generated client exposes injectable `http.Client`. |
| Protobuf | `COMPATIBLE_CALLER_LAYER` through existing AlphaX byte bodies; no Protobuf package. |
| GraphQL WebSocket/subscriptions | `PROOF_ONLY` through a caller-owned `WebSocketChannel` bridge. |
| gRPC | `DEFERRED_POST_1_0`; Protobuf serialization does not imply gRPC. |
| WebSocket | `FIRST_CLASS` `package:alphax/websocket.dart` lifecycle contract; no automatic reconnect. |
| SSE | `FIRST_CLASS` `package:alphax/sse.dart` parser; reconnect remains caller-owned. |

AlphaX does not replace `retrofit_generator`, provide a Retrofit-specific
package, or claim universal OpenAPI-generator compatibility.

The official OpenAPI template result is a bounded proof, not a mature SDK
generator. See the [OpenAPI proof](../examples/openapi_template_proof/README.md),
the [Protobuf recipe](../examples/protobuf_interop/README.md), and the
[complete rc.5 matrix](ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md).

## 16. `package:http` comparison

`package:http` provides a deliberately small `BaseClient`/`Client` abstraction
and separate clients such as `cronet_http`'s `CronetClient` and
`cupertino_http`'s `CupertinoClient`. Those are sound choices when a common
HTTP client API is all an application needs.

AlphaX's distinct seam is the transport contract plus normalized capabilities,
protocol preference versus fail-closed requirement, completion-time protocol and
fallback facts, a portable policy layer, bounded streaming/file contracts, and
shared conformance/test helpers. This is a difference in contract and control,
not a claim that AlphaX is universally faster or that `dart:io` lacks connection
reuse. Reuse the same long-lived client for either architecture when pooling
matters.

## 17. Testing

Use `alphax_test` as a dev dependency for deterministic application tests:

```dart
final client = AlphaXClient(
  transport: FakeAlphaXTransport(
    response: AlphaXResponse(statusCode: 200, bodyBytes: <int>[1, 2, 3]),
  ),
);
try {
  final response = await client.get(Uri.https('example.com', '/test'));
  print(await response.readAsBytes());
} finally {
  await client.close();
}
```

The fake can model response bytes, streams, delays, failures, cancellation,
protocol values, and in-memory files. Transport authors can run the shared
conformance helper against their implementation.

## 18. Platform limitations

- Dart IO is an H1-only AlphaX fallback and does not authoritatively report H2/H3.
- Android Cronet/HttpEngine and Apple URLSession capabilities depend on the
  provider, OS, server, proxy, and network.
- Custom trust, SPKI pinning, client identity, and explicit proxy modes are
  capability-dependent; unsupported security policy fails closed.
- Web Fetch cannot expose authoritative protocol metadata to Dart and cannot
  provide native file paths, certificate pins, custom trust, or an explicit
  proxy. CORS and browser credentials remain browser-owned.
- AlphaX core has no automatic background JSON parsing. `alphax_transform`
  requires a buffered body and has one-shot result-discard cancellation.
- There is no common AlphaX API for DoH, QUIC 0-RTT, connection migration,
  background URLSession transfers, or universal zero-copy buffers.
- CocoaPods is the Apple packaging path for this release; Swift Package
  Manager support remains deferred.

## 19. References

- [Core API](../packages/alphax/README.md)
- [Native transport package](../packages/alphax_native/README.md)
- [Browser Fetch package](../packages/alphax_web/README.md)
- [Dio adapter](../packages/alphax_dio/README.md)
- [Testing package](../packages/alphax_test/README.md)
- [Transform package](../packages/alphax_transform/README.md)
- [Policy defaults](POLICIES.md)
- [Migration guide](MIGRATION.md)
- [Transport contract](architecture/transport_contract.md)
- [Dart `HttpClient` connection reuse](https://api.dart.dev/dart-io/HttpClient-class.html)
- [`package:http` client selection](https://pub.dev/packages/http)
- [`cronet_http`](https://pub.dev/packages/cronet_http)
- [`cupertino_http`](https://pub.dev/packages/cupertino_http)
- [Dio](https://pub.dev/packages/dio)
- [Apple URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Nitro runtime (not an AlphaX HTTP client)](https://pub.dev/packages/nitro)
