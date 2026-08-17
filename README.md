# AlphaX

AlphaX is a transport-independent HTTP client API for Dart and Flutter. It
provides one request/response, streaming, file-transfer, cancellation,
capability, protocol, and error model over platform transports.

## Status

**`1.0.0-rc.1` is prepared for maintainer review.** AlphaX remains a release
candidate and is not published to pub.dev. Publication requires naming
clearance and maintainer approval after the RC review.

AlphaX makes no universal H3, speed, zero-copy, or “fastest client” claim.

## Installation during RC review

Until package naming clearance and publication approval are complete, consume
the candidate packages from the public repository:

```yaml
dependencies:
  alphax:
    git:
      url: https://github.com/auvana-ventures/alphax.git
      path: packages/alphax
  alphax_native:
    git:
      url: https://github.com/auvana-ventures/alphax.git
      path: packages/alphax_native
  alphax_dio:
    git:
      url: https://github.com/auvana-ventures/alphax.git
      path: packages/alphax_dio
  alphax_web:
    git:
      url: https://github.com/auvana-ventures/alphax.git
      path: packages/alphax_web
```

`alphax` has no Flutter SDK dependency. `alphax_native` is the Flutter plugin
that supplies Dart IO, Android Cronet/HttpEngine, and Apple URLSession adapters.
`alphax_web` supplies the browser Fetch adapter; browser protocol metadata is
intentionally unknown.

## Which package do I need?

Choose the package by the job you are doing:

| Package | Use it when you want to… | What you get |
| --- | --- | --- |
| [`alphax`](packages/alphax/README.md) | write request code once | transport-independent requests, responses, streams, files, cancellation, timeouts, errors, and protocol metadata |
| [`alphax_native`](packages/alphax_native/README.md) | run the same client on Flutter platforms | Dart IO on Linux/Windows, Cronet on Android, and URLSession on iOS/macOS |
| [`alphax_web`](packages/alphax_web/README.md) | run the same client in a browser | RC Fetch adapter for Web requests with truthful browser capability boundaries |
| [`alphax_dio`](packages/alphax_dio/README.md) | keep an existing Dio application | a Dio `HttpClientAdapter` backed by an injected AlphaX client and its configured transport/security policies |
| [`alphax_test`](packages/alphax_test/README.md) | test without a live server or device | deterministic fake transports, streams, failures, cancellation, files, and conformance helpers |

New Flutter applications normally use `alphax` with `alphax_native`. Existing
Dio applications can add `alphax_dio` instead of rewriting their request
layer. `alphax_test` is a development dependency, not a runtime transport.

## Basic request

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<void> main() async {
  final client = AlphaXClient(transport: DartIoTransport());
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

On Android, create `AndroidCronetTransport`; on iOS/macOS, create
`AppleUrlSessionTransport`. The request and response API remains unchanged.

## What is enabled by default?

AlphaX keeps application policy explicit:

| Behavior | Default |
| --- | --- |
| Transport | You inject one; `AlphaXClient` does not choose one automatically. |
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
| [`alphax`](packages/alphax) | Pure-Dart transport-neutral contracts | Required core |
| [`alphax_native`](packages/alphax_native) | Dart IO, Cronet, and URLSession adapters | Required platform boundary |
| [`alphax_test`](packages/alphax_test) | Fakes and shared conformance helpers | Required test support |
| [`alphax_dio`](packages/alphax_dio) | Focused Dio 5.x `HttpClientAdapter` boundary | Optional RC package; not full Dio compatibility |
| [`alphax_web`](packages/alphax_web) | Browser Fetch transport adapter | Optional separate Web package; publication requires maintainer approval |

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
      │
      ▼
alphax (pure-Dart contracts)
      │
      ├── Dart IO fallback
      ├── Android Cronet/HttpEngine
      ├── iOS/macOS URLSession
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
