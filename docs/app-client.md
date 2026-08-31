# Application client

`AlphaXAppClient` is the high-level application-facing layer for the AlphaX
1.1 line. It removes repetitive URL, query, header, JSON-body, and overall
timeout conversion while delegating requests and responses to the existing
`AlphaXClient`.

It is a convenience layer, not a transport. The lower-level
[`AlphaXClient`](../packages/alphax/README.md) remains available for custom
transports, phase-specific timeouts, file operations, streaming operations,
protocol controls, and other advanced AlphaX APIs.

## Create a client

Native Flutter applications use `alphax_native`:

```dart
import 'package:alphax_native/alphax_native.dart';

final client = await createAlphaXAppClient(
  baseUrl: 'https://api.example.com',
);
```

The native helper selects the existing platform transport and returns an owned
facade. Android, Apple, Linux, and Windows keep their existing provider
selection and capability boundaries.

Browser applications use `alphax_web`:

```dart
import 'package:alphax_web/alphax_web.dart';

final client = await createAlphaXAppClient(
  baseUrl: 'https://api.example.com',
);
```

The Web helper uses browser Fetch. TLS, CORS, proxy routing, redirects,
credentials, and protocol metadata remain browser-owned.

Both helpers return `Future<AlphaXAppClient>` so application code can use the
same creation shape across deployment targets.

## Common requests

Relative paths resolve against the base URL:

```dart
final response = await client.get(
  '/users',
  queryParameters: <String, Object?>{
    'page': 2,
    'active': true,
  },
  headers: <String, String>{
    'Authorization': 'Bearer token',
  },
);

print(await response.readAsString());

final created = await client.post(
  '/users',
  data: <String, Object?>{
    'name': 'Example',
  },
);
```

Responses are the raw `AlphaXResponse`, so callers retain access to
`readAsBytes`, `readAsString`, `readAsJson`, streaming, headers, status, and
transport metadata. Model serialization is caller-owned; call `toJson()`
before passing a custom model as `data`.

Every method accepts the same optional request controls:

```dart
await client.get(
  '/slow',
  timeout: const Duration(seconds: 30),
  cancellationToken: cancellationToken,
);
```

The facade timeout is the existing overall AlphaX timeout. A request timeout
overrides the facade default; `null` inherits the default. Phase-specific
timeout control remains available through `AlphaXRequest`.

`get`, `post`, `put`, `patch`, `delete`, and `head` are available. Body-bearing
methods accept either JSON-safe `data` or an explicit `AlphaXBody`, never both:

```dart
await client.post(
  '/upload-metadata',
  body: AlphaXBody.text('plain text'),
);
```

## URL rules

`baseUrl` must be an absolute `http` or `https` URL with a host. It cannot
contain a fragment or user information. Its path is treated as a directory:

- `https://api.example.com` + `users` resolves to
  `https://api.example.com/users`.
- `https://api.example.com/v1` + `/users` resolves to
  `https://api.example.com/users`.
- `https://api.example.com/v1/` + `users/1` resolves to
  `https://api.example.com/v1/users/1`.
- `https://api.example.com/v1/` + `../users` resolves to
  `https://api.example.com/users`.

URL resolution uses Dart `Uri` semantics. A target may be a relative path or an
absolute HTTP(S) URL. An absolute target bypasses the base URL. Network-path
references such as `//other.example/items`, non-HTTP schemes, fragments, URL
userinfo, and invalid targets are rejected rather than silently rewritten.

Absolute URLs are an explicit cross-origin escape hatch, not an authentication
boundary. Middleware still sees the resolved request, and an origin-agnostic
authentication middleware could apply credentials to it. Use absolute targets
only when they are trusted and intentional; use separately scoped clients for
untrusted or unrelated origins.

## Query parameters

`queryParameters` accepts `String`, `int`, `double`, `bool`, `null`, and
iterables of those scalar values. Values are encoded by Dart `Uri`:

- `null` removes that key;
- an empty iterable removes that key;
- an iterable produces repeated keys in its iteration order;
- a request value replaces all values for the same key from the base URL or
  target query; and
- non-finite doubles and nested/non-scalar values are rejected.

Base query values are applied first, target query values replace matching base
keys, and `queryParameters` has final precedence. Map and iterable iteration
order determines the order of newly supplied values; servers should not depend
on query ordering.

## Ownership and close

Factory-created facades own their underlying `AlphaXClient`:

```dart
try {
  // use client
} finally {
  await client.close();
}
```

For a client supplied by another owner, use the borrowed constructor:

```dart
final alpha = AlphaXClient(transport: myTransport);
final client = AlphaXAppClient.borrowed(
  alpha,
  baseUrl: 'https://api.example.com',
);

await client.close(); // closes only this facade
await alpha.close();  // the caller closes the underlying client
```

`AlphaXAppClient.owned` closes the supplied client. Both constructors make
`close()` idempotent, reject new facade requests after close, and avoid global
singletons or hidden provider caches. A generated or other application layer
that receives an `AlphaXClient` should likewise borrow it unless it explicitly
owns its lifecycle.

## Advanced escape hatch

Use `AlphaXClient` directly when you need a `Uri`, explicit
`AlphaXRequest`, multi-value `AlphaXHeaders`, file upload/download, streaming
operations, protocol preference or requirement, TLS/proxy construction policy,
or provider-specific capability handling. The application facade does not
change those lower-level contracts; it only constructs ordinary requests for
them.

This page describes the additive 1.1 application facade. The published
AlphaX 1.0.0 package family remains documented by the stable
[usage guide](USAGE_AND_CUSTOMIZATION.md).
