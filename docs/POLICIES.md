# AlphaX policy defaults and customization

This guide answers two questions:

1. What does AlphaX do if I do nothing?
2. What do I add when my application needs retries, login tokens, cookies,
   caching, resilience, a proxy, protocol rules, or certificate pinning?

The examples use only AlphaX 1.0 APIs. Replace the example hosts, token
functions, proxy values, and pin values with your application's configuration.
Never copy real credentials or production pin material into source control or
logs.

## Start with a transport

`AlphaXClient` is intentionally transport-independent. It does not choose a
native or Dart IO transport for you, so a transport is required when the client
is created:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

final transport = DartIoTransport();
final client = AlphaXClient(transport: transport);
```

Use `AndroidCronetTransport.create()` on Android,
`AppleUrlSessionTransport.create()` on iOS/macOS, and `DartIoTransport()` for
the Dart IO fallback. The [native transport guide](../packages/alphax_native/README.md)
shows platform selection. The separate `alphax_web` package provides the
browser Fetch transport.

Close the client when the owning feature or application is finished with it:

```dart
try {
  final response = await client.get(Uri.https('api.example.com', '/health'));
  print(await response.readAsString());
} finally {
  await client.close();
}
```

## Defaults at a glance

These are the defaults for a newly created transport and client. “Off” means
AlphaX will not add that behavior unless you add the corresponding middleware.

| Area | Default | What that means |
| --- | --- | --- |
| Transport | No client default | You choose and inject an `AlphaXTransport`. |
| Middleware | None | Requests go through only the transport unless you add middleware. |
| TLS | Verified platform trust | Certificate chain, hostname, and validity checks remain enabled. |
| Proxy | System proxy policy | The selected platform/provider manages normal proxy routing. |
| Protocol preference | `auto` | The provider, server, proxy, and network negotiate the actual protocol. |
| Retries | Off | A failed request is not repeated automatically. |
| Authentication | Off | AlphaX does not invent credentials or tokens. |
| Cookies | Off in the core | Add a cookie jar, or use browser-managed cookies on Web. |
| Cache | Off | A response is not stored unless you add cache middleware. |
| Circuit breaker | Off | Requests are not rejected by a resilience circuit unless you add it. |
| SPKI pinning | Off | Normal TLS validation is used unless you configure pins. |
| H3 | Never guaranteed | A preference may fall back; only completion metadata proves what ran. |

The core package does not include a native transport, and `AlphaXClient()`
without a transport is not a supported construction. This is deliberate: an
application should know which platform/provider capability it is selecting.

## Add policies deliberately

Create one client and list only the policies your application needs:

```dart
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(
      accessToken: currentAccessToken,
      refreshAccessToken: refreshAccessToken,
    ),
    AlphaXCookieMiddleware(cookieJar),
    AlphaXRetryMiddleware(policy: retryPolicy),
    AlphaXCacheMiddleware(store: cacheStore),
    AlphaXResilienceMiddleware(policy: resiliencePolicy),
  ],
);
```

Middleware is entered in the order listed and unwinds in reverse order. Start
with one policy, confirm its behavior, and then add the next one. Keep request
bodies replayable before enabling a policy that may send a request again.

When combining authentication or cookies with caching, put the authentication
and cookie middleware before `AlphaXCacheMiddleware` in the list. That lets the
cache see AlphaX-visible request headers before it decides whether a response
may be reused. A cache hit short-circuits middleware that appears after it.

### 1. Automatic retries

Retries are not enabled by default. Add `AlphaXRetryMiddleware` when your
server contract permits retrying a request:

```dart
final retryPolicy = AlphaXRetryPolicy(
  maxAttempts: 3, // Total attempts, including the first request.
  initialDelay: const Duration(milliseconds: 100),
  maxDelay: const Duration(seconds: 5),
  backoffMultiplier: 2,
  retryNonIdempotent: false,
);

final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXRetryMiddleware(policy: retryPolicy),
  ],
);
```

With the default policy, AlphaX retries:

- replayable buffered `GET`, `HEAD`, `OPTIONS`, `PUT`, and `DELETE` requests;
- selected temporary HTTP statuses such as `408`, `429`, `500`, `502`, `503`,
  and `504`; and
- normalized DNS, connection, timeout, and transport failures.

It honors a bounded `Retry-After` delay and stops when the cancellation token
is cancelled. `POST` and `PATCH` are not retried by default. Set
`retryNonIdempotent: true` only when the server operation is safe to repeat and
the request body is replayable. Streaming responses, streamed request bodies,
and file transfers are not implicitly replayed because they may already be
partially consumed.

To make the policy narrower, supply `shouldRetry`. For example, an application
that only wants to retry status `503` can make that decision explicitly:

```dart
final retryPolicy = AlphaXRetryPolicy(
  shouldRetry: ({required request, response, error, required attempt}) =>
      response?.statusCode == 503,
);
```

The hook can reduce retries; it should not be used to hide an unsafe replay.

### 2. Authentication and token refresh

Authentication is not automatic. The application owns the token store and
decides how a token is obtained or refreshed:

```dart
String? currentAccessToken() => tokenStore.readAccessToken();

Future<String?> refreshAccessToken() => authService.refreshAccessToken();

final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXAuthenticationMiddleware(
      accessToken: currentAccessToken,
      refreshAccessToken: refreshAccessToken,
    ),
  ],
);
```

The defaults are:

- the `Authorization: Bearer <token>` header is used;
- an existing caller-supplied authorization header is preserved;
- a `401` response triggers at most one refresh attempt for the request;
- concurrent challenges share one refresh operation; and
- refresh/replay is limited to replayable buffered requests.

For an API key or another header, customize the header name and scheme:

```dart
AlphaXAuthenticationMiddleware(
  accessToken: () => tokenStore.readApiKey(),
  headerName: 'x-api-key',
  scheme: '',
)
```

This middleware is not an OAuth client, credential database, login UI, or
vendor-specific authentication framework. The application remains responsible
for secure token storage, logout, scopes, refresh failures, and user-facing
authentication state.

### 3. Cookies

Cookies are not stored by default in the core. Add the in-memory jar when the
application needs host/path/secure/expiry, host-only, and HttpOnly handling:

```dart
final cookieJar = AlphaXCookieJar();
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXCookieMiddleware(cookieJar),
  ],
);
```

The middleware reads `Set-Cookie` responses and sends matching cookies on later
requests. Clear the jar on logout when the session should end:

```dart
await cookieJar.clear();
```

`AlphaXCookieMiddleware` accepts the asynchronous `AlphaXCookieStore` seam.
`AlphaXCookieJar` is the default in-memory implementation and serializes
concurrent `Set-Cookie` updates, including updates made through another client
sharing the same store. It preserves domain/path/expiry/Secure/
HttpOnly/host-only/replacement/deletion behavior, and store failures are
surfaced rather than treated as an empty jar.

Persistence is caller/extension-owned. If cookies must survive a restart,
implement `AlphaXCookieStore` over encrypted storage, a database, a file, or a
platform secure store. The application owns serialization, encryption,
restore-after-login, logout clearing, and access control; AlphaX does not add a
storage dependency or format. Do not add SameSite to native code to imitate a
browser. On Web, browser-managed cookies use
`WebFetchTransport(withCredentials: true)` and remain subject to browser CORS
and credential rules.

Your custom store must serialize concurrent writes and must never log cookie or
token values. A minimal store implementation has these operations:

```dart
final class MyCookieStore implements AlphaXCookieStore {
  @override
  Future<List<AlphaXCookie>> readCookies() async => loadParsedCookies();

  @override
  Future<void> writeCookies(Iterable<AlphaXCookie> cookies) async =>
      saveParsedCookies(cookies);

  @override
  Future<void> updateCookies(
    Iterable<AlphaXCookie> Function(List<AlphaXCookie> cookies) transform,
  ) async {
    // Run this read/transform/write inside your store's transaction or lock.
    final current = await loadParsedCookies();
    await saveParsedCookies(transform(List<AlphaXCookie>.from(current)));
  }

  @override
  Future<void> clear() async {
    // Clear the session on logout.
  }
}
```

`AlphaXCookieMiddleware` performs header production and `Set-Cookie` parsing
using the same AlphaX rules for every store; your adapter only loads and saves
parsed `AlphaXCookie` values.

### 4. Response caching

Caching is not enabled by default. The supplied store is private, bounded
in-memory storage for buffered `GET` and `HEAD` responses:

```dart
final cacheStore = AlphaXMemoryCacheStore(maxEntries: 100, maxBytes: 10 * 1024 * 1024);
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXCacheMiddleware(
      store: cacheStore,
      policy: const AlphaXCachePolicy(
        defaultMaxAge: Duration(minutes: 5),
        revalidateStale: true,
      ),
    ),
  ],
);
```

The middleware owns HTTP cache selection and freshness semantics. It matches
the method and URI plus response-declared `Vary` fields such as
`Accept-Language` and `Accept`, rejects `Vary: *`, honors quoted
`Cache-Control` directives (`no-store`, `no-cache`, `private`, `public`,
`must-revalidate`, `max-age`, and shared-scope `s-maxage`), and uses `Date`,
`Age`, and `Expires` conservatively. ETag and Last-Modified validators are
sent for revalidation, and 304 metadata is merged before the entry is stored
again. POST, PUT, PATCH, and DELETE invalidate GET and HEAD variants.

Requests carrying `Authorization` or `Cookie` bypass the cache by default.
Responses that set cookies are not cached by the bundled middleware. To cache
a private authenticated session intentionally, give the policy a stable,
non-secret identity key and change it or clear the store when the identity
changes:

```dart
const cachePolicy = AlphaXCachePolicy(identityKey: 'account-42');
```

On Web, `WebFetchTransport(withCredentials: true)` can send browser-managed
cookies that AlphaX cannot read or include in an AlphaX cache key. Do not
combine that transport mode with AlphaX cache middleware unless the application
supplies a stable, non-secret `identityKey` for the browser session and changes
it or clears the store on logout/account change. If browser identity can change
without the application observing it, leave AlphaX caching off for those
requests. Browser HTTP caching remains browser-owned.

The identity key is a scope label, not a token. Proxy-authenticated requests
always bypass this application cache. AlphaX refuses sensitive response
variants that would require storing `Authorization`, `Cookie`, or proxy
credentials in a cache key. The bundled store evicts in insertion order
when `maxEntries` or `maxBytes` is exceeded and skips oversized entries. It
does not coalesce concurrent misses, provide stale-while-revalidate, or create
an offline queue.

For disk, database, encrypted, or intentionally shared storage, implement the
variant-aware `AlphaXCacheStore` with application-owned durability, encryption,
access control, corruption handling, and serialized writes. The store uses
`AlphaXCacheKey` and `AlphaXCacheEntry`; it is not a URI-only API. Do not put
credentials or private response data into an unprotected shared cache.

### 5. Generic resilience and circuit breaking

Resilience is not enabled by default. Add the generic circuit breaker when the
feature should stop sending requests to a failing service for a short period:

```dart
final resiliencePolicy = AlphaXResiliencePolicy(
  failureThreshold: 5,
  openDuration: const Duration(seconds: 30),
  retryPolicy: AlphaXRetryPolicy(
    maxAttempts: 2,
    initialDelay: const Duration(milliseconds: 200),
  ),
);

final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    AlphaXResilienceMiddleware(policy: resiliencePolicy),
  ],
);
```

The circuit moves from closed to open after the configured failures, fails fast
while open, and allows one half-open probe after `openDuration`. Its retry
option is still replay-aware. It covers buffered operations; it does not replay
partially consumed streams or file transfers.

This is intentionally a transport-neutral policy, not a Google, AWS, Azure,
Cloudflare, or other vendor resilience product. For vendor-specific rules,
write an application `AlphaXMiddleware` or keep that policy in the service
layer so it can use the vendor's official SDK and current service contract.

## Protocol preference, requirement, and actual result

Use a preference when fallback is acceptable:

```dart
final response = await client.get(
  Uri.https('api.example.com', '/health'),
  protocolPreference: AlphaXProtocolPreference.http3,
);
final metrics = await response.completionMetrics;
print('actual protocol: ${metrics.negotiatedProtocol.name}');
```

The selected provider, server, proxy, and network path decide the result. A
preference for H3 can complete over H2 or H1 and should be treated as a normal
successful fallback when the application allows it.

Use a requirement when fallback is not acceptable:

```dart
try {
  final response = await client.get(
    Uri.https('api.example.com', '/h3-only-operation'),
    protocolRequirement: AlphaXProtocolRequirement.http3,
  );
  print(await response.readAsString());
} on AlphaXProtocolRequirementException {
  // The provider could not prove that H3 was actually negotiated.
}
```

Capabilities describe what a provider may support; they do not prove what one
request used. Use `client.capabilities` before choosing an optional behavior,
then use completion metrics for the actual protocol. Dart IO cannot
authoritatively report H2/H3, and Web Fetch reports protocol as unknown.

## Proxy routing

Proxy policy is configured on the transport, not on `AlphaXClient` middleware.
The default is system-managed routing. Configure it before constructing the
client:

```dart
final proxyPolicy = AlphaXProxyPolicy.http(
  host: proxyHost,
  port: proxyPort,
  credentials: AlphaXProxyCredentials.basic(
    username: proxyUsername,
    password: proxyPassword,
  ),
);

final transport = await AppleUrlSessionTransport.create(
  proxyPolicy: proxyPolicy,
);
final client = AlphaXClient(transport: transport);
```

The supported 1.0 boundary is:

| Policy | Dart IO | Selected Android provider | Apple URLSession |
| --- | --- | --- | --- |
| `system()` | Supported | Provider/system managed | Supported |
| `direct()` | Supported | Not supported by the selected provider | Supported |
| `http(...)` | Supported, including Basic auth | Not supported by the selected provider | Supported, including HTTP CONNECT to HTTPS destinations where CFNetwork permits |
| `https(...)` endpoint | Unsupported | Unsupported | Unsupported by the shared 1.0 mapping |

An unsupported policy throws a normalized unsupported-policy error. AlphaX does
not silently switch to a direct or system route. Proxy credentials are
hop-by-hop: never print them, put them in origin `Authorization`, or include
them in diagnostics. H3 remains dependent on what the proxy and network allow.

## TLS and SPKI pinning

Normal certificate verification is on by default. Pinning adds a stricter
host-scoped check; it does not replace hostname, certificate validity, or trust
chain verification. Configure a primary pin and a backup pin for planned key
rotation:

```dart
final tlsPolicy = AlphaXTlsPolicy(
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
);

final transport = await AppleUrlSessionTransport.create(
  tlsPolicy: tlsPolicy,
);
final client = AlphaXClient(transport: transport);
```

`sha256SpkiBase64` is the base64-encoded SHA-256 digest of the certificate's
DER SubjectPublicKeyInfo. Pin values must come from your secure release
configuration; the placeholder variables above are not real pins. Set an
expiry and rotate before it passes.

SPKI pinning is supported by Android Cronet and Apple URLSession. Dart IO and
Web Fetch cannot provide the required authoritative pin check in this release;
configuring pins there fails closed. Android's selected provider also does not
support custom trust anchors, while Dart IO and Apple support custom anchors
where their capability reports it. AlphaX has no trust-all configuration and no
raw private-key API; mTLS is not implemented in the 1.0 adapters.

## Add your own application policy

Built-in middleware is optional. For a rule that belongs to your application,
you can write a small transport-independent middleware and keep the transport
unchanged:

```dart
final class TenantHeaderMiddleware extends AlphaXMiddleware {
  const TenantHeaderMiddleware(this.tenantId);

  final String tenantId;

  @override
  Future<AlphaXResponse> intercept(
    AlphaXRequest request,
    AlphaXNext next,
  ) => next(
    request.copyWith(
      headers: request.headers.set('x-tenant-id', tenantId),
    ),
  );
}

final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[
    TenantHeaderMiddleware(currentTenantId),
  ],
);
```

Use the same seam for organization headers, request correlation, feature
flags, vendor SDK decisions, or application-specific error handling. Do not
put raw credentials into logs or make a custom middleware replay a body that is
not replayable.

## If your requirement is not supported

Follow these steps instead of silently changing security or routing behavior:

1. Inspect `client.capabilities` for the relevant capability, such as
   `certificatePinning`, `explicitHttpProxy`, or `protocolRequirement`.
2. Select a transport/provider that reports the needed capability.
3. Configure TLS or proxy policy when the transport is created.
4. Add only the middleware required by the application.
5. Catch the normalized `AlphaXUnsupportedCapabilityException` or policy
   subtype and show a useful configuration error.
6. If the built-in policy is not a fit, implement an application middleware or
   `AlphaXCacheStore`; keep credentials, persistence, and vendor behavior in
   application-owned code.

The safe failure is intentional. AlphaX will not claim H3 because a provider
supports it, retry a non-replayable mutation, accept an invalid certificate
because a pin matches, or route around an unsupported proxy policy.

For package-specific setup, see [`alphax_native`](../packages/alphax_native/README.md),
[`alphax_dio`](../packages/alphax_dio/README.md), and
[`alphax_web`](../packages/alphax_web/README.md). For migration from
`package:http` or Dio, see [`MIGRATION.md`](MIGRATION.md).
