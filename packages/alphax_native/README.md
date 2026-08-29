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
  <a href="https://github.com/auvana-ventures/alphax/blob/main/docs/ALPHAX_1_0_RELEASE_GATE.md">Platform matrix</a> ·
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

1. Add `alphax` and `alphax_native` to the application.
2. Follow [choose a transport](#choose-a-transport) for the platform branch.
3. Keep the request code shared across platforms.
4. Read [TLS and proxy behavior](#configure-tls-and-proxy-behavior) before
   enabling optional security or routing controls.

`alphax_native` gives an AlphaX application the platform transport selected for
each supported target while keeping the same Dart request code everywhere. It
supplies Dart IO, Android Cronet/HttpEngine, and Apple URLSession adapters
behind the transport-neutral [`alphax`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax) API.

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
[`alphax`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax) alone for transport contracts and a custom
transport, or use [`alphax_dio`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio) if your application
already uses Dio.

## Install

The previous `1.0.0-rc.3` is published on pub.dev. The coordinated
`1.0.0-rc.4` candidate is prepared for publication:

```sh
flutter pub add alphax alphax_native
```

The Android provider is resolved through Gradle and Apple packaging uses
CocoaPods. No copied Cronet binary is bundled in the pub package. Swift
Package Manager integration is deferred for 1.0.

## Choose a transport

This is the only platform-specific decision in your application setup. The
rest of your request code can stay the same.

```dart
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

Future<AlphaXTransport> createTransport() async {
  if (Platform.isAndroid) {
    return AndroidCronetTransport.create();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return AppleUrlSessionTransport.create();
  }
  return DartIoTransport();
}

Future<void> main() async {
  final client = AlphaXClient(transport: await createTransport());
  try {
    final response = await client.get(Uri.https('example.com', '/'));
    print('${response.statusCode}: ${await response.readAsString()}');
  } finally {
    await client.close();
  }
}
```

## Platform support

| Platform | Adapter | Protocol boundary |
| --- | --- | --- |
| Android API 24+ | Cronet/HttpEngine provider | H1/H2/H3 where the selected non-fallback provider and network negotiate it |
| iOS 15+ | URLSession | H1/H2/H3 where the OS, server, proxy, and network negotiate it |
| macOS 12+ | URLSession | H1/H2/H3 where the OS, server, proxy, and network negotiate it |
| Linux | Dart IO | H1 only; H2/H3 are not advertised |
| Windows | Dart IO | H1 only; H2/H3 are not advertised |
| Web | Not provided by this native plugin | Add [`alphax_web`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web) for browser Fetch |

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
final transport = await AppleUrlSessionTransport.create(
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
final client = AlphaXClient(transport: transport);
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
| Explicit `https(...)` proxy endpoint | Unsupported | Unsupported | Unsupported by the shared 1.0 mapping |
| mTLS/client identity | Unsupported in 1.0 | Unsupported in the selected provider | Unsupported in 1.0 |

An HTTP proxy endpoint can carry an HTTPS destination through CONNECT; that is
different from configuring an HTTPS proxy endpoint. Never use trust-all
configuration, log proxy credentials, or put real pin material in examples.
For retry, authentication, cookies, caching, resilience, protocol preference,
and custom application policies, follow the [policy defaults and customization
guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md).

## What this package does not promise

- It does not guarantee H3 on every request or every network.
- It does not provide the browser transport; use the separate
  [`alphax_web`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_web) package for Web.
- It does not expose Cronet, URLSession, Flutter channel, FFI, C++, Rust, or
  libcurl types through the core API.
- It does not make unsupported TLS or proxy policies silently succeed.
- It makes no universal performance, zero-copy, or “fastest client” claim.

Authentication, cookies, caching, retries, and generic resilience are opt-in
pure-Dart middleware from [`alphax`](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax). This package only
selects and implements native/Dart IO transports; it does not enable those
policies automatically.

## Continue learning

- [Core AlphaX API](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax)
- [Dio adapter](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio)
- [Testing helpers](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_test)
- [Waypoint reference app](https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint)
- [Migration guide](https://github.com/auvana-ventures/alphax/blob/main/docs/MIGRATION.md)
- [1.0 platform and protocol matrix](https://github.com/auvana-ventures/alphax/blob/main/docs/ALPHAX_1_0_RELEASE_GATE.md)

The coordinated `1.0.0-rc.4` candidate is prepared for publication; the
previous `1.0.0-rc.3` package remains the currently published release. Android,
iOS, and macOS support remains provider/platform dependent; Dart IO is the
truthful fallback on Linux and Windows.
