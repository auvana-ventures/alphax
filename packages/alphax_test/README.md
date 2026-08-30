# alphax_test

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_test/assets/branding/alphax-logo-light.svg">
    <img src="https://github.com/auvana-ventures/alphax/raw/main/packages/alphax_test/assets/branding/alphax-logo-dark.svg" alt="AlphaX" width="300">
  </picture>
</p>

<p align="center"><strong>Deterministic tests for AlphaX clients and transports.</strong><br>
Exercise requests, streams, failures, policies, and file transfers without a live network.</p>

<p align="center">
  <a href="https://github.com/auvana-ventures/alphax/tree/main/packages/alphax">Core API</a> ·
  <a href="https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint">Waypoint example</a> ·
  <a href="https://github.com/auvana-ventures/alphax/blob/main/LICENSE">Apache-2.0</a>
</p>

## At a glance

| Test concern | What you can control |
| --- | --- |
| Requests | Methods, headers, bodies, protocol preferences, and recorded calls |
| Responses | Status, headers, bytes, streams, delays, cancellation, and failures |
| Files | In-memory upload sources and download targets |
| Adapters | Shared transport-conformance helpers for package-level validation |
| Runtime | Development dependency only; it never replaces a production transport |

## Start here

1. Add `alphax_test` as a development dependency.
2. Replace the production transport with `FakeAlphaXTransport`.
3. Assert the response, failure, stream, request, or file behavior you need.
4. Use the conformance helpers when validating a transport package.

`alphax_test` lets you test AlphaX applications and transports without a live
server, network connection, native device, or real file system. Replace the
transport with a deterministic fake, describe the response or failure you
need, and assert how your application behaves.

## Why use it?

Use `alphax_test` to:

- test success and HTTP-error handling deterministically;
- simulate delays, cancellation, timeouts, and streamed response events;
- test upload/download code with in-memory file sources and targets;
- record requests and verify methods, headers, bodies, and protocol policies;
- run the shared transport-conformance suite against an adapter;
- keep ordinary unit tests independent of Flutter plugins and native engines.

## When should I choose this package?

Add `alphax_test` as a development dependency whenever your application uses
`alphax` and needs predictable tests. It is not a runtime HTTP client and is
not required in a production dependency list.

## Install

The coordinated `1.0.0-rc.5` release is published on pub.dev; rc.4 is a
historical baseline:

```sh
dart pub add --dev alphax_test
```

## Your first fake response

This test never contacts `example.com`; the fake transport returns the bytes
you provide.

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

void main() {
  test('uses a fake response without a network connection', () async {
    final client = AlphaXClient(
      transport: FakeAlphaXTransport(
        response: AlphaXResponse(
          statusCode: 200,
          bodyBytes: <int>[1, 2, 3],
        ),
      ),
    );
    addTearDown(client.close);

    final response = await client.get(Uri.https('example.com', '/test'));

    expect(await response.readAsBytes(), <int>[1, 2, 3]);
  });
}
```

## Common test scenarios

### Exercise cancellation and delays

```dart
test('stops a request when its screen closes', () async {
  final token = AlphaXCancellationToken();
  final client = AlphaXClient(
    transport: FakeAlphaXTransport(
      delay: const Duration(milliseconds: 100),
    ),
  );
  addTearDown(client.close);

  final pending = client.get(
    Uri.https('example.com', '/slow'),
    cancellationToken: token,
  );
  token.cancel('screen closed');

  await expectLater(
    pending,
    throwsA(isA<AlphaXCancellationException>()),
  );
});
```

`FakeAlphaXTransport` also supports configured failures, request recording,
stream builders, protocol/capability values, and deterministic timing.

## Test optional policies without a network

`alphax_test` does not turn on retries, authentication, cookies, caching, or
resilience for you. Add the same middleware to the fake-backed client that the
production client will use, then configure the fake response or failure you
want to exercise:

```dart
var attempts = 0;
final client = AlphaXClient(
  transport: FakeAlphaXTransport(
    responseBuilder: (_) {
      attempts++;
      return AlphaXResponse(
        statusCode: attempts == 1 ? 503 : 200,
        bodyBytes: attempts == 1 ? const <int>[] : const <int>[1, 2, 3],
      );
    },
  ),
  middleware: <AlphaXMiddleware>[
    AlphaXRetryMiddleware(
      policy: AlphaXRetryPolicy(
        initialDelay: Duration.zero,
      ),
    ),
  ],
);
addTearDown(client.close);

final response = await client.get(Uri.https('example.com', '/retry-test'));
// The fake returns 503 once, then 200; GET is replayable by default.
print(response.statusCode);
```

Use request recording to confirm which headers, bodies, and protocol controls
your custom policy produces. Keep retry tests focused on replayable requests,
and add separate tests for token refresh, cookie clearing, cache invalidation,
and circuit-open behavior. The [policy defaults and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/POLICIES.md)
explains the production boundaries; this package lets you verify them without
real credentials, servers, proxies, or certificates.

### Test file transfers without files

```dart
final transport = FakeAlphaXTransport(
  response: AlphaXResponse(
    statusCode: 200,
    bodyBytes: <int>[10, 20, 30],
  ),
);
final client = AlphaXClient(transport: transport);
final target = InMemoryAlphaXFileTarget();
addTearDown(client.close);

await client.download(
  Uri.https('example.com', '/file'),
  to: target,
);

expect(target.bytes, <int>[10, 20, 30]);
```

The package also provides `InMemoryAlphaXFileSource` for upload tests and
helpers for inspecting deterministic request/response behavior.

## Conformance tests for adapters

Adapter packages can run the reusable contract suite against their own
transport. The suite covers methods, headers, bodies, redirects, cancellation,
timeouts, streams, files, progress, protocol metadata, and normalized errors.
See the package's existing `test/conformance_test.dart` for the integration
pattern.

## What this package does not do

- It does not open network connections or replace a production transport.
- It does not test real DNS, TLS, proxies, Cronet, URLSession, or device
  behavior; use the platform release tests for those boundaries.
- It does not make performance claims or provide benchmark fixtures for
  marketing comparisons.

## Continue learning

- [Core AlphaX API](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax)
- [Usage and customization guide](https://github.com/auvana-ventures/alphax/blob/main/docs/USAGE_AND_CUSTOMIZATION.md)
- [Native platform transports](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_native)
- [Dio adapter](https://github.com/auvana-ventures/alphax/tree/main/packages/alphax_dio)
- [Waypoint reference app](https://github.com/auvana-ventures/alphax/tree/main/examples/waypoint)
- [1.0 testing and conformance scope](https://github.com/auvana-ventures/alphax/blob/main/docs/ALPHAX_1_0_SCOPE.md)

The coordinated `1.0.0-rc.5` package is a development dependency only and does
not provide a production transport.
