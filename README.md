# AlphaX

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/branding/alphax-logo-light.svg">
    <img src="assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="340">
  </picture>
</p>

<p align="center"><strong>Transport-independent HTTP for Dart and Flutter.</strong><br>
One request, response, streaming, file-transfer, cancellation, policy, and
protocol model across the transports that each platform can actually provide.</p>

<p align="center">
  <a href="docs/ALPHAX_1_0_SCOPE.md">1.0 scope</a> ·
  <a href="docs/USAGE_AND_CUSTOMIZATION.md">Usage and customization</a> ·
  <a href="examples/waypoint/README.md">Waypoint example</a> ·
  <a href="docs/MIGRATION.md">Migration guide</a> ·
  <a href="LICENSE">Apache-2.0</a>
</p>

## At a glance

| Area | AlphaX 1.0 RC |
| --- | --- |
| API | One typed, transport-neutral client for requests, responses, streams, files, cancellation, timeouts, redirects, and normalized errors |
| Transports | Dart IO fallback, Android Cronet/HttpEngine, Apple URLSession, and a separate browser Fetch adapter |
| Protocols | H1/H2/H3 where the Android or Apple provider negotiates them; H1 on Dart IO; browser protocol remains unknown to Dart |
| Policies | Opt-in authentication, replay-aware retries, cookies, private HTTP caching, and a generic circuit breaker |
| Security | Verified TLS defaults, platform-scoped SPKI pinning, proxy policy, capability checks, and fail-closed unsupported controls |

## Why AlphaX?

- Keep application request code independent of a particular transport engine.
- Inspect completion-time protocol metadata instead of assuming that a preferred
  protocol was negotiated.
- Compose application policies explicitly, with conservative defaults for
  retries, authentication, cookies, caching, and resilience.
- Stream response and file-transfer work with cancellation and bounded delivery
  where the selected platform transport supports it.

## Status

**The coordinated AlphaX candidate is `1.0.0-rc.4` and is prepared for
publication.** The five original packages remain published on pub.dev at
`1.0.0-rc.3`; `alphax_transform` is included in the coordinated candidate and
is not yet published. AlphaX remains a release candidate with its 1.0 public
API frozen; later contract changes may be breaking.

AlphaX makes no universal H3, speed, zero-copy, or “fastest client” claim.

## Install

Start with the published RC packages for your target:

```sh
# Android, iOS, macOS, Linux, or Windows
flutter pub add alphax alphax_native

# Browser Fetch
flutter pub add alphax alphax_web

# Existing Dio application
flutter pub add dio alphax alphax_native alphax_dio

# Optional one-shot large-payload JSON transform (after rc.4 publication)
dart pub add alphax alphax_transform
```

`alphax` has no Flutter SDK dependency. A pure-Dart application can use it with
its own `AlphaXTransport`; Flutter applications normally pair it with
`alphax_native`. Add `alphax_test` as a development dependency when you want
deterministic transport tests.

### Pin the coordinated RC explicitly

After the coordinated candidate is published, pin the versions together in
`pubspec.yaml`:

```yaml
dependencies:
  alphax: ^1.0.0-rc.4
  alphax_native: ^1.0.0-rc.4
  alphax_dio: ^1.0.0-rc.4
  alphax_web: ^1.0.0-rc.4
  alphax_transform: ^1.0.0-rc.4

dev_dependencies:
  alphax_test: ^1.0.0-rc.4
```

`alphax` has no Flutter SDK dependency. `alphax_native` is the Flutter plugin
that supplies Dart IO, Android Cronet/HttpEngine, and Apple URLSession adapters.
`alphax_web` supplies the browser Fetch adapter; browser protocol metadata is
intentionally unknown. `alphax_transform` is an optional package in the
prepared coordinated `rc.4` set; it remains separate from `alphax` core and
does not alter transport behavior. `rc.3` is the historical published set.

## Which package do I need?

Choose the package by the job you are doing:

| Package | Use it when you want to… | What you get |
| --- | --- | --- |
| [`alphax`](packages/alphax/README.md) | write request code once | transport-independent requests, responses, streams, files, cancellation, timeouts, errors, and protocol metadata |
| [`alphax_native`](packages/alphax_native/README.md) | run the same client on Flutter platforms | Dart IO on Linux/Windows, Cronet on Android, and URLSession on iOS/macOS |
| [`alphax_web`](packages/alphax_web/README.md) | run the same client in a browser | RC Fetch adapter for Web requests with truthful browser capability boundaries |
| [`alphax_dio`](packages/alphax_dio/README.md) | keep an existing Dio application | a Dio `HttpClientAdapter` backed by an injected AlphaX client and its configured transport/security policies |
| [`alphax_test`](packages/alphax_test/README.md) | test without a live server or device | deterministic fake transports, streams, failures, cancellation, files, and conformance helpers |
| [`alphax_transform`](packages/alphax_transform/README.md) | explicitly offload a profiled large buffered JSON payload | one-shot native `Isolate.run` decoding with caller-supplied sendable transformation; Web fails closed |

New Flutter applications normally use `alphax` with `alphax_native`. Existing
Dio applications can add `alphax_dio` instead of rewriting their request
layer. `alphax_test` is a development dependency, not a runtime transport.

## Choose a starting point

| If your goal is… | Start here |
| --- | --- |
| Send a normal request | [Quick start](#quick-start) |
| Stream or cancel work | [Streaming and cancellation](#streaming-and-cancellation) |
| Upload or download a file | [Upload and download](#upload-and-download) |
| Prefer H3 and see what completed | [Capabilities and protocol reporting](#capabilities-and-protocol-reporting) |
| Add retries, tokens, cookies, cache, or resilience | [Policy guide](docs/POLICIES.md) |
| Configure TLS, pins, or proxies | [Native transport guide](packages/alphax_native/README.md#configure-tls-and-proxy-behavior) |
| Understand every configuration boundary | [Usage and customization guide](docs/USAGE_AND_CUSTOMIZATION.md) |
| Keep an existing Dio application | [`alphax_dio`](packages/alphax_dio/README.md) |
| Test without a network | [`alphax_test`](packages/alphax_test/README.md) |
| Offload a profiled large JSON transform | [`alphax_transform`](packages/alphax_transform/README.md) |

## Quick start

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: await createAlphaXTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');

    // A transport may learn the protocol only after the body completes.
    final finalMetrics = await response.completionMetrics;
    print('negotiated protocol: ${finalMetrics.negotiatedProtocol.name}');
  } finally {
    await client.close();
  }
}
```

`createAlphaXTransport()` selects Cronet/HttpEngine on Android, URLSession on
iOS/macOS, and Dart IO on Linux/Windows. Web is a separate package boundary:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_web/alphax_web.dart';

final webClient = AlphaXClient(transport: WebFetchTransport());
```

Create one configured client for an API or session and reuse it; the client
owns its transport and middleware state. Close it when that scope ends. The
factory does not enable retries, cookies, cache, authentication, resilience,
or background JSON parsing.

## Choose your level of control

### Start simple

Add `alphax` and `alphax_native`, then use `createAlphaXTransport()`. Normal
request code does not need platform branching.

### Configure portable policies

Pass `AlphaXMiddleware` to the client and set request-level timeout, redirect,
cancellation, progress, protocol preference, and protocol requirement values.
These settings express application intent while the selected provider decides
which platform operations can honor it.

### Take control of the transport

Inject `DartIoTransport()`, `AndroidCronetTransport.create()`, or
`AppleUrlSessionTransport.create()` when a deliberate provider choice is useful.
The browser equivalent is `WebFetchTransport()` from `alphax_web`.

### Bring your own transport

Implement the public `AlphaXTransport` contract and pass it to
`AlphaXClient(transport: ...)`. The contract keeps provider types out of core;
custom implementations must preserve cancellation, streaming, completion
metrics, capability reporting, and close semantics. See the
[customization guide](docs/USAGE_AND_CUSTOMIZATION.md#bring-your-own-transport).

## Using Retrofit

Retrofit generated clients are supported through the existing Dio boundary:

```text
retrofit generated client → Dio → AlphaXDioAdapter → AlphaX
```

Keep the normal Retrofit annotations and generated constructor. Configure the
Dio instance with an AlphaX client once, then pass that Dio instance to the
generated API:

```dart
import 'package:alphax/alphax.dart';
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
  final alphaClient = AlphaXClient(
    transport: await createAlphaXTransport(),
  );
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
are not dependencies of AlphaX. The maintained Retrofit fixture used for this
RC review generated and exercised typed JSON, nullable and wrapped responses,
streaming, cancellation, multipart file upload, errors, redirects, and
progress through this same adapter path. See [Using Retrofit in the full user
guide](docs/USAGE_AND_CUSTOMIZATION.md#using-retrofit).

## Defaults are explicit

AlphaX keeps application policy explicit:

| Behavior | Default |
| --- | --- |
| Transport | `alphax_native` selects Android Cronet/HttpEngine, Apple URLSession, or Dart IO with `createAlphaXTransport()`; `alphax` core still requires injection and Web uses `WebFetchTransport()`. |
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
| Windows | Dart IO fallback | H1 only |
| Web | `alphax_web` Browser Fetch transport | H1/H2/H3 may be used by the browser, but Dart cannot authoritatively report the negotiated protocol; H3 requirements fail closed |

H3 preference may legitimately negotiate H2 or H1. The actual protocol and
fallback metadata must be inspected for each completed request. A protocol
requirement fails closed when the exact protocol is not observed. Dart IO
cannot authoritatively report H2/H3 and therefore does not advertise them.

## Packages

| Package | Purpose | 1.0 status |
| --- | --- | --- |
| [`alphax`](packages/alphax) | Pure-Dart transport-neutral contracts | PUBLISH_RC; coordinated rc.4 candidate |
| [`alphax_native`](packages/alphax_native) | Dart IO, Cronet, and URLSession adapters | PUBLISH_RC; coordinated rc.4 candidate |
| [`alphax_test`](packages/alphax_test) | Fakes and shared conformance helpers | PUBLISH_RC; coordinated rc.4 candidate |
| [`alphax_dio`](packages/alphax_dio) | Focused Dio 5.x `HttpClientAdapter` boundary | PUBLISH_RC; coordinated rc.4 candidate |
| [`alphax_web`](packages/alphax_web) | Browser Fetch transport adapter | PUBLISH_RC; coordinated rc.4 candidate |
| [`alphax_transform`](packages/alphax_transform) | Explicit one-shot isolate JSON transform for buffered payloads | PUBLISH_RC; coordinated rc.4 candidate |

There is no AlphaX-owned C++ engine, production Rust transport, libcurl
dependency, telemetry SDK, GraphQL layer, REST generator, or WebSocket/SSE API
in the 1.0 architecture. Retry, authentication, cookie, cache, and generic
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
demonstrates the packages in a travel-planning interface. The minimal smoke
test remains
[`examples/basic`](examples/basic/README.md) and its source is in
[`examples/basic/lib/main.dart`](examples/basic/lib/main.dart).

## Architecture and evidence

The public contract stays in `alphax`; platform processing is isolated in
`alphax_native`:

```text
Dart application
      ├── alphax (pure-Dart contracts)
      │     └── AlphaXClient(transport: ...)
      ├── alphax_native automatic factory
      │     ├── Dart IO fallback
      │     ├── Android Cronet/HttpEngine
      │     └── iOS/macOS URLSession
      └── alphax_web Browser Fetch (separate package)
```

See the [1.0 scope](docs/ALPHAX_1_0_SCOPE.md),
[accepted transport ADR](docs/decisions/0004-platform-native-mobile-transports.md),
the [1.0 requirements audit](docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md),
and [Phase 1E validation report](docs/phase1e-cross-transport-validation.md).
Historical Phase 0 benchmark results remain evidence for measured HTTP/1.1
workloads; see the [historical benchmark documentation](docs/benchmarks.md) and
its linked result summaries. They were not rewritten as H2/H3 performance
claims.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md),
and the relevant architecture documents before changing a transport or public
contract. AlphaX is licensed under Apache-2.0; see [LICENSE](LICENSE).
