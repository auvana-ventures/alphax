# AlphaX 1.0 capability-gap audit

**Review date:** 2026-08-17
**Review type:** read-only release audit
**Scope:** non-H3 capability boundaries only

**Follow-up status:** The two pre-freeze contract risks identified below were
approved and implemented in the subsequent policy-freeze task. See
[`ALPHAX_1_0_POLICY_FREEZE_REVIEW.md`](ALPHAX_1_0_POLICY_FREEZE_REVIEW.md) for
the final contract and validation outcome.

This report does not reassess HTTP/3 availability, negotiation, fallback, or
any limitation caused by an operating system, provider, network, or device.
Those constraints are accepted and intentionally excluded.

The audit reviewed the current implementations in
[`alphax`](../packages/alphax/lib/src), the native adapters in
[`alphax_native`](../packages/alphax_native/lib/src), the browser boundary in
[`alphax_web`](../packages/alphax_web/lib/src), the package documentation, and
the policy tests. It also compared the responsibility boundary with standards
and official documentation for the requested ecosystems.

## Executive decision

AlphaX does not need to become an OAuth SDK, a database, a browser session
manager, a vendor resilience framework, or a universal transport feature
parity layer for 1.0. The following are sound 1.0 boundaries when they remain
explicitly documented and fail closed where a requested security or routing
policy cannot be enforced:

- OAuth flow orchestration remains application or auth-library owned.
- Persistent cookie and cache implementations remain extension-owned.
- Explicit HTTPS proxy endpoints remain unsupported on the selected AlphaX
  transports until a provider can enforce TLS-to-proxy semantics.
- Dart IO SPKI pinning remains unsupported rather than weakening TLS validation.
- Safe, opt-in, replay-aware retries and a generic in-memory circuit breaker are
  appropriate primitives; advanced business resilience remains extension-owned.
- mTLS remains transport/provider-specific, with the existing opaque identity
  seam and explicit unsupported results.

At the time of this audit, two issues required a maintainer decision before
calling the policy APIs a stable 1.0 surface:

1. `AlphaXCookieMiddleware` is coupled to the concrete in-memory
   `AlphaXCookieJar`. Add a stable cookie-store seam before the public API is
   frozen, without adding a storage dependency.
2. `AlphaXCacheMiddleware` currently keys entries by URI only and does not
   model `Vary`, `Age`, `Expires`, authenticated-response policy, or private
   versus shared store scope. Either harden that contract before 1.0 or label
   the middleware as a deliberately limited application cache rather than a
   standards-aware HTTP cache. The recommended path is to harden it.

Therefore the transport-independent AlphaX core was not blocked by the
caller-owned and platform-owned features below. The approved follow-up now
resolves the two conditional policy-surface blockers without adding persistence
implementations or changing transports.

## Post-audit disposition

- `AlphaXCookieStore` now provides asynchronous `readCookies`, `writeCookies`,
  atomic `updateCookies`, and `clear` operations. Middleware retains all
  parsing/matching semantics; `AlphaXCookieJar` remains the queued in-memory
  implementation.
- `AlphaXCacheStore` now uses `AlphaXCacheKey` and `AlphaXCacheEntry` rather
  than a URI-only API. The middleware enforces method/URI/Vary selection,
  conservative freshness and validator handling, private-by-default scope,
  credential isolation, Set-Cookie exclusion, mutation invalidation, and
  bounded memory behavior.
- The changes are recorded in ADR 0009 and ADR 0010 and covered by
  `packages/alphax/test/policy_contract_test.dart`.

## Decision table

| Capability | Current Limitation | Why | 1.0 Classification | User Impact | Proposed 1.0 Action | Complexity | Breaking API? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Automatic retries | Opt-in middleware; replayable buffered requests only; safe/idempotent methods retry by default; POST/PATCH are excluded by default; streamed and file operations are not replayed. | Safety and body-replay architecture. HTTP semantics do not make every repeated operation safe. [`RFC 9110 §9.2.2`](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2) advises against automatic retry of non-idempotent requests without additional knowledge. | `ACCEPTABLE_1_0_LIMITATION` | A caller must explicitly opt in and design a replayable/idempotent mutation. Streaming uploads need an application-level resume protocol. | Keep the safe default. Document middleware ordering and the danger of `retryNonIdempotent`. Add conformance tests for POST, PUT, PATCH, streaming bodies, cancellation, and authentication composition. | Medium | No for the current contract. A future per-request idempotency API would be additive. |
| Advanced retry controls | No default jitter, HTTP-date `Retry-After` parsing, explicit retry deadline, or per-request idempotency declaration. A custom delay/decision hook exists. | These are policy and fleet-behavior controls, not required to make the safe default safe. | `SHOULD_SUPPORT_VIA_EXTENSION` | High-volume clients may synchronize retries or need server-supplied calendar retry times. Applications can currently provide narrower custom policy, but not every control cleanly. | Keep outside the frozen core unless production users demonstrate the need. Prefer a separate retry-policy extension or a future additive request retry disposition. | Medium | No if added as new hooks. Replacing the current policy fields would be breaking. |
| Token authentication | Token injection, 401 refresh callbacks, single-flight refresh, and one replay of a replayable buffered request are supported. Token storage and lifecycle are caller-owned. | Credential material, logout, scopes, rotation, and app identity state are security/application concerns. | `ACCEPTABLE_1_0_LIMITATION` | The caller must connect AlphaX to its own auth state and decide what to do after refresh failure or logout. | Keep the middleware. Document that it is credential injection and refresh coordination, not OAuth. | Low | No. |
| OAuth orchestration | No authorization-code or PKCE flow, browser/session launch, redirect receiver, discovery-document client, client-credentials manager, refresh-token storage, revocation, logout, or scope/user session model. | OAuth authorization is a multi-party protocol involving a resource owner, authorization server, redirect URI, external user agent, and secure storage. It is not an HTTP transport concern. [`RFC 6749`](https://www.rfc-editor.org/rfc/rfc6749.html), [`RFC 7636`](https://www.rfc-editor.org/rfc/rfc7636.html), and [`RFC 8252`](https://www.rfc-editor.org/rfc/rfc8252.html) define responsibilities outside a request client. | `NOT_ALPHA_X_RESPONSIBILITY` | AlphaX alone cannot log a user in or safely persist a refresh token. The application must use an auth package/platform flow and pass the resulting token to AlphaX. | Document the boundary and provide examples of callback wiring only. Do not add OAuth UI, browser, discovery, or token-database APIs to `alphax`. | Very high | Any later bundled OAuth framework would add a large new API and dependencies. |
| Cookie handling | Opt-in in-memory jar with name/value/domain/path/expiry/secure/HttpOnly/host-only handling. No SameSite model and no persistent lifecycle. | The current jar is a small transport-neutral HTTP cookie policy, not a browser cookie agent. Persistence has storage, encryption, migration, and concurrency concerns. | `ACCEPTABLE_1_0_LIMITATION` | Sessions disappear on process restart. SameSite browser behavior is not available in the non-browser core. | Keep in-memory behavior; explicitly state that Web uses browser credentials and that core AlphaX does not emulate a browser security context. | Medium | Adding a cookie store can be additive if the current jar constructor is preserved. |
| Cookie persistence implementation | `AlphaXCookieJar` owns a mutable list in memory. There is no file, database, secure-storage, or serialization implementation. | Avoids forcing a platform storage dependency and avoids defining unsafe token/cookie-at-rest policy in a transport package. | `SHOULD_SUPPORT_VIA_EXTENSION` | Persistent login sessions require application-owned storage and restore logic. | Do not ship a built-in persistence implementation. Allow applications to supply one through a stable store interface. | Medium | No if exposed through a new interface/constructor. |
| Cookie-store abstraction | `AlphaXCookieMiddleware` accepts concrete `AlphaXCookieJar`, so a persistent implementation cannot be injected without adapting or changing the middleware API. | Missing implementation seam; this is an API-evolution issue, not a reason to own storage. | `SHOULD_SUPPORT_IN_1_0` | A package author cannot add encrypted or database-backed cookies cleanly after 1.0 without a constructor/API change. | Add an async `AlphaXCookieStore` seam before final freeze. Keep `AlphaXCookieJar` as the default in-memory implementation and preserve a compatibility constructor or adapter. | Medium | Potentially, if the concrete constructor is replaced rather than extended. |
| Cache storage | Opt-in bounded in-memory store, buffered GET/HEAD only, validators and mutation invalidation. No disk, encrypted, offline, or shared store implementation. | Storage lifetime and confidentiality belong to the application; the existing `AlphaXCacheStore` is intended as an extension point. | `SHOULD_SUPPORT_VIA_EXTENSION` | Data is lost on restart and large or offline-first applications need their own store. | Keep `AlphaXCacheStore`; document private versus shared use and let applications provide memory, disk, encrypted, or database implementations. | Medium | No for a new implementation. |
| Cache correctness and selection | Store key is only `Uri`; `Vary` is only rejected when `*`; `Expires` and `Age` are not modeled; response directives are incomplete; store scope is unspecified; concurrent miss coalescing is absent. | Standards-aware caching requires request method/URI plus selected request headers and conservative directive handling. [`RFC 9111`](https://www.rfc-editor.org/rfc/rfc9111.html) requires correct reuse conditions and warns about cache poisoning and sensitive information. | `SHOULD_SUPPORT_IN_1_0` | Different `Accept-Language`, `Accept`, tenant, or authorization contexts can receive an entry created for another request if the cache is used as a general HTTP cache. A custom shared store could also persist data that should remain private. | Harden the cache contract or explicitly downgrade it to a narrowly scoped application response memoizer. Recommended: add a variant-aware key/store contract, conservative authenticated-response defaults, `Vary` matching, `Expires`/`Age`, and explicit private-store scope. | Medium-high | Yes if `AlphaXCacheStore.read(Uri)` is replaced. Use a pre-1.0 migration or an additive variant-store interface and deprecate the URI-only path. |
| Generic resilience | Optional in-memory circuit breaker with closed/open/half-open states, one probe, consecutive failure threshold, open duration, and optional retry composition. State is per middleware instance and not per origin. | AlphaX can provide a small generic primitive, but origin identity, service topology, failure taxonomy, and observability are application policy. | `ACCEPTABLE_1_0_LIMITATION` | A single middleware instance can open for all origins it serves. Callers needing per-origin isolation must use separate clients or an extension. | Keep the primitive and document its client-wide, isolate-local scope, failure classification, and middleware composition. Add transition/concurrency tests. | Medium | No. |
| Vendor-specific resilience | No circuit-breaker thresholds, retry budgets, or telemetry policy for a cloud/vendor SDK. | Vendor policy is business and service-specific, not transport-neutral. | `NOT_ALPHA_X_RESPONSIBILITY` | Applications must compose their service SDK or policy layer around AlphaX. | Do not add it to core. Keep generic hooks and normalized errors. | High | A vendor policy would create new coupling and long-term compatibility obligations. |
| Explicit HTTP proxy and HTTPS destination | System/direct/explicit HTTP proxy policies are modeled where the provider allows them. An HTTP proxy can carry an HTTPS destination through CONNECT; this is not TLS to the proxy itself. | Underlying provider and OS APIs expose different proxy controls and authentication schemes. | `ACCEPTABLE_1_0_LIMITATION` | Enterprise users can use only the route modes exposed by their selected transport/provider; unsupported modes must fail closed. | Keep capability reporting and fail-closed errors. Do not infer direct routing from missing provider support. | Medium | No. |
| Explicit HTTPS proxy endpoint | `AlphaXProxyPolicy.https` is expressible, but the selected AlphaX Dart IO, Apple shared mapping, and selected Android paths do not guarantee TLS to the proxy; unsupported requests fail closed. | HTTPS proxying has two TLS/authentication contexts: client-to-proxy and proxy-to-origin. The selected common transport contract does not expose a portable, verified way to configure both. | `PLATFORM_LIMITATION` | Networks that require an encrypted connection to the proxy cannot use the affected AlphaX transport. An HTTP proxy with CONNECT to an HTTPS destination remains a different, supported subset where reported. | Retain the API model and capability state, but do not claim support. Revisit only with provider-specific proxy TLS, proxy CA, auth, and test evidence. | High | No; enabling support later should be additive. |
| Dart IO SPKI pinning | Dart IO rejects configured pins. `badCertificateCallback` is only called for a certificate that normal trust cannot authenticate; using it as a pin hook could accept an otherwise invalid certificate. | The ordinary `HttpClient` path has no post-trust pin callback. Stable low-level APIs expose `SecureSocket.peerCertificate` and certificate DER, but a complete custom connection path must preserve trust, hostname checks, pooling, system proxy behavior, and CONNECT tunnels. | `PLATFORM_LIMITATION` | Linux/Windows/Dart IO users cannot use AlphaX SPKI pins and must select a native provider or another transport when pinning is mandatory. | Keep fail-closed behavior. Correct the rationale to acknowledge the possible direct-only `connectionFactory` research path, but do not ship a partial or trust-weakening implementation in 1.0. | High | No. |
| mTLS/client identity | An opaque `AlphaXClientIdentity` exists, but selected Cronet cannot guarantee client-certificate selection and 1.0 does not expose raw private keys. | Client identity is platform keystore/keychain/provider-specific and has lifecycle/security implications. | `PLATFORM_LIMITATION` | Some enterprise APIs requiring client certificates cannot run on every AlphaX transport. Dart IO and Apple can support selected identity paths when configured safely. | Keep opaque identity references and capability/error reporting. Add platform adapters only when a provider contract and secure identity resolution are verified. | High | No if the opaque seam remains. |
| Native transport in `alphax` | The pure-Dart core does not choose or contain a native transport. | Keeps the core transport-neutral, testable, and free of Flutter/platform dependencies. | `NOT_ALPHA_X_RESPONSIBILITY` | Users must add `alphax_native`, `alphax_web`, or another `AlphaXTransport`. | Keep explicit transport injection. Do not make `AlphaXClient()` silently select a platform or provider. | Medium | An automatic default later would change construction and capability expectations. |
| Browser-controlled features | Web transport is a separate package; browser TLS, proxy, cookie, CORS, and credential rules are not exposed as ordinary Dart controls. | The browser is the security and networking authority. | `PLATFORM_LIMITATION` | Web applications must use browser-supported credential/CORS behavior and cannot require native trust or proxy controls through AlphaX. | Keep the separate adapter and capability states. Do not emulate browser controls in core. | Medium | No. |
| Background transfer | Native background-session/OS-resume behavior is not part of the common 1.0 transfer contract. | It requires lifecycle identifiers, durable task state, OS callbacks, and platform-specific scheduling. | `SHOULD_SUPPORT_VIA_EXTENSION` | Large mobile transfers cannot be guaranteed to finish after process suspension or termination. | Defer to a native/background-transfer extension; keep foreground file transfer in 1.0. | High | Likely new API. |
| Offline queue, telemetry, analytics, GraphQL, WebSocket/SSE, full Dio parity | These are absent or intentionally outside the transport contract. | They are application/framework responsibilities or distinct protocols/products. | `NOT_ALPHA_X_RESPONSIBILITY` | Users compose separate packages or application services. | Keep them out of the 1.0 scope and label them as non-goals rather than incomplete HTTP basics. | High | Adding any would expand the product boundary. |

## Standards and competing-client boundary

The comparison does not mean AlphaX should copy every feature. It identifies
which responsibilities production clients put in the HTTP layer and which they
leave to extensions or callers.

| Ecosystem | What the official surface provides | Boundary relevant to AlphaX |
| --- | --- | --- |
| Dio | Dio exposes lifecycle interceptors for requests, responses, and errors, plus a [`QueuedInterceptor`](https://pub.dev/documentation/dio/latest/dio/QueuedInterceptor-class.html) for serialized asynchronous work. See the official [`Interceptor`](https://pub.dev/documentation/dio/latest/dio/Interceptor-class.html) API. [`dio_cookie_manager`](https://pub.dev/documentation/dio_cookie_manager/latest/) is a separate package; it offers an in-memory `CookieJar` and a file-backed `PersistCookieJar`. | Interceptors are the right level for AlphaX auth/retry/cookie policies. Persistence is an extension, not evidence that the core client needs a database. |
| OkHttp | [`OkHttpClient`](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/) exposes a `CookieJar`, `Cache`, `Authenticator`, `Proxy` and proxy authenticator, certificate pinner, and `retryOnConnectionFailure`. The official [`CookieJar`](https://square.github.io/okhttp/3.x/okhttp/okhttp3/CookieJar.html) contract explicitly separates cookie policy from persistence and allows memory, file, or database implementations. | OkHttp demonstrates that stable policy/store seams matter. Its platform-native client can own more defaults because it controls one runtime; AlphaX should keep transport-neutral policies smaller. |
| URLSession | `URLSessionConfiguration` provides `URLCache`, `HTTPCookieStorage`, system or per-session proxy configuration, ephemeral memory-only sessions, persistent default-session behavior, background sessions, and delegate authentication challenges. See [`URLSessionConfiguration`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration), [`urlCache`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/urlcache?changes=_2%2C_2), and [`httpCookieStorage`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpcookiestorage?changes=_6). | Apple’s stack owns platform storage and lifecycle because it is an OS framework. AlphaX should expose portable contracts and let the Apple adapter use platform facilities where the selected mapping supports them. |
| Cronet | `CronetEngine.Builder` exposes engine-level public-key pins, HTTP cache modes including disk and memory, a storage path for HTTP cache and cookie storage, and provider-specific proxy options. [`CronetEngine.Builder`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/CronetEngine.Builder?hl=en) says disk cache/cookie storage requires a configured storage path and that storage directories cannot be shared concurrently by multiple engines. | Cronet’s native engine has capabilities that cannot be represented as universal AlphaX middleware defaults. AlphaX must report provider limits instead of pretending its in-memory policy is equivalent to engine storage. |
| Dart `HttpClient` | Dart IO maintains cookies between requests, supports environment proxy lookup and direct/PAC-style proxy results, uses `SecurityContext` for trust/client certificates, and exposes a `badCertificateCallback`. [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html) does not provide a standards-aware application response cache or a first-class SPKI policy. | The Dart fallback is a lower-level transport. AlphaX’s cookie middleware is deliberate rather than relying on implicit transport state, and SPKI must remain fail closed until a complete safe path exists. |
| reqwest | `ClientBuilder` has opt-in/default cookie-store behavior and a custom `CookieStore`, configurable retry policy, proxy configuration, and a total request timeout. See [`ClientBuilder`](https://docs.rs/reqwest/latest/reqwest/struct.ClientBuilder.html) and [`Proxy`](https://docs.rs/reqwest/latest/reqwest/struct.Proxy.html). | The Rust ecosystem also treats cookies, retries, and proxy policy as configurable client concerns, while OAuth orchestration and application persistence remain outside the HTTP client. |
| curl/libcurl | libcurl exposes cookie-file import and cookie-jar export, proxy URLs including `https://`, proxy authentication/custom headers, and separate proxy certificate verification controls. See [`CURLOPT_COOKIEFILE`](https://curl.se/libcurl/c/CURLOPT_COOKIEFILE.html), [`CURLOPT_COOKIEJAR`](https://curl.se/libcurl/c/CURLOPT_COOKIEJAR.html), [`CURLOPT_PROXY`](https://curl.se/libcurl/c/CURLOPT_PROXY.html), and [`CURLOPT_PROXY_SSL_VERIFYPEER`](https://curl.se/libcurl/c/CURLOPT_PROXY_SSL_VERIFYPEER.html). | libcurl is a low-level toolkit where the caller owns lifecycle, storage, and policy composition. Its broader proxy surface is not evidence that every selected AlphaX provider can safely implement the same mode. |

## Must address before 1.0

These are API-contract decisions, not requests to expand AlphaX into an
application framework. If the maintainer does not want to make these changes,
the safe alternative is to remove the affected optional policy from the stable
1.0 promise and keep it experimental.

### 1. Add a cookie-store seam without owning persistence

#### Why this cache contract is a 1.0 issue

The in-memory behavior itself is a reasonable 1.0 implementation. The issue is
that [`AlphaXCookieMiddleware`](../packages/alphax/lib/src/alpha_x_cookie.dart)
currently stores a concrete `AlphaXCookieJar`. Once that constructor is part of
a published API, a disk-backed, encrypted, database-backed, or platform
keychain-backed store cannot be integrated without changing the middleware
surface.

The HTTP cookie storage model includes more than a name and value: expiry,
domain, path, creation/access ordering, persistent state, host-only state,
secure-only state, and HttpOnly state are part of the RFC 6265 storage model.
See the [`RFC 6265 storage model`](https://www.rfc-editor.org/rfc/rfc6265.html#section-5.3).
The current jar already covers the most important request-matching fields, but
it has no durable lifecycle or store transaction boundary.

This does **not** mean AlphaX should ship a database, serialize refresh tokens,
or decide whether an app should restore a session after logout. Those decisions
remain caller-owned.

#### Proposed cache API direction

Before the final freeze, add an asynchronous transport-neutral seam similar to:

```dart
abstract interface class AlphaXCookieStore {
  Future<List<AlphaXCookie>> readCookies();

  Future<void> writeCookies(Iterable<AlphaXCookie> cookies);

  Future<void> updateCookies(
    Iterable<AlphaXCookie> Function(List<AlphaXCookie> cookies) transform,
  );

  Future<void> clear();
}
```

The middleware performs header production and Set-Cookie parsing over parsed
`AlphaXCookie` values, so every store uses the same AlphaX matching policy. The
contract should make these invariants explicit:

- request matching and Set-Cookie parsing stay in AlphaX rather than being
  reimplemented differently by every app;
- a store may perform asynchronous I/O;
- response cookie updates are serialized or atomic per store;
- expired/deleted cookies are not returned;
- credentials are never included in diagnostics;
- a store is scoped to a client/session unless the caller intentionally shares
  it;
- persistence failures are surfaced rather than silently treated as an empty
  jar;
- storage encryption and secure key management are supplied by the caller or a
  separate platform package.

Keep `AlphaXCookieJar` as the in-memory implementation. The pre-1.0 correction
makes the middleware accept the interface directly; existing
`AlphaXCookieJar` constructor calls continue to work because the jar implements
the store seam, while its store operations are now asynchronous.

`SameSite` should not be added merely to imply browser behavior. A native HTTP
client can preserve or expose that attribute later, but browser cookie sending,
site context, and CSRF policy belong to the browser/application security layer.
The Web adapter should continue to use browser-managed credentials.

#### Cache implementation plan

- **Affected packages/files:**
  `packages/alphax/lib/src/alpha_x_cookie.dart`, the public export file,
  policy tests, `docs/POLICIES.md`, package README guidance, the API inventory,
  and migration/release documentation.
- **Internal architecture:** separate cookie matching/parsing from store
  lifetime; serialize updates for concurrent response completions; ensure
  streamed/download operations update the store when response headers become
  available.
- **Transport impact:** none. Cookies remain middleware-owned and transport
  neutral. Browser cookies remain browser-owned.
- **Security:** do not write cookie or token values to logs; document secure
  storage, logout clearing, keychain/keystore use, and session isolation.
- **Persistence/storage:** no AlphaX database or file dependency. Provide a
  contract that an application can implement over memory, a file, a database,
  or secure storage.
- **Tests:** RFC matching for domain/path/expiry/secure/host-only; deletion and
  replacement; concurrent store updates; serialization round trip; persistence
  failure propagation; redirect/header timing; logout clearing; no secret
  leakage.
- **Documentation:** show the in-memory default, a pseudocode/custom-store
  boundary, restore/clear rules, and the distinction between cookies and OAuth
  tokens.
- **Complexity/risk:** medium. The API is straightforward, but changing the
  constructor after publication is costly and cookie concurrency bugs are
  security-sensitive.

#### Cache acceptance criteria

1. A caller can implement a persistent or secure `AlphaXCookieStore` without
   changing AlphaX source or depending on a private class.
2. Existing in-memory examples remain valid or have a documented additive
   migration.
3. Concurrent requests cannot lose a Set-Cookie update because of an
   uncoordinated asynchronous write.
4. The docs explicitly state that persistence and session restoration are
   caller decisions.

### 2. Harden the cache contract or narrow its promise

#### Why this is a 1.0 issue

The existing [`AlphaXCacheStore`](../packages/alphax/lib/src/alpha_x_cache.dart)
is already a useful persistence seam. The more serious issue is the cache
selection and metadata contract around it:

- the middleware reads and writes by URI only;
- a response with `Vary: Accept-Language`, `Vary: Accept`, or another selector
  can be reused for a request with different selector headers;
- `Vary: *` is rejected, but ordinary `Vary` is not matched;
- `Expires` and `Age` are not modeled;
- `private`, `public`, `s-maxage`, `must-revalidate`, `stale-*`, and other
  directives are not represented as policy decisions;
- a custom store is not identified as private or shared;
- an authenticated response can be stored without a documented opt-in or
  identity-bound key;
- concurrent misses are not coalesced, so several callers can fetch and write
  the same resource independently.

Some of these are not bugs for a deliberately narrow, private, application
memoizer. A private cache may store private responses, and an application may
choose a heuristic five-minute lifetime. They become gaps when the API is
described as an HTTP cache and when callers provide a shared or persistent
store. RFC 9111 says that the minimum cache key includes method and target URI,
that `Vary` can add request header fields to the key, that caches must honor
reuse conditions, and that authenticated responses need special handling in a
shared cache. See [`RFC 9111 overview and cache keys`](https://www.rfc-editor.org/rfc/rfc9111.html#section-2),
[`storing authenticated responses`](https://www.rfc-editor.org/rfc/rfc9111.html#section-3.5),
and [`constructing responses`](https://www.rfc-editor.org/rfc/rfc9111.html#section-4).

#### Proposed API direction

The durable contract should identify the request variant, not only the URI.
One possible shape is:

```dart
final class AlphaXCacheKey {
  const AlphaXCacheKey({
    required this.method,
    required this.uri,
    required this.selectedRequestHeaders,
  });

  final HttpMethod method;
  final Uri uri;
  final Map<String, String> selectedRequestHeaders;
}
```

The store then reads/writes an `AlphaXCacheKey` and an entry that records the
response `Vary` fields and freshness metadata. Before finalizing names, the
maintainer must choose one compatibility strategy:

1. **Pre-1.0 correction:** change `AlphaXCacheStore.read/write/remove` to use a
   variant key and provide a migration adapter for the current URI-only store.
2. **Additive transition:** add an `AlphaXVariantCacheStore` interface and use
   it when supplied, preserve the URI-only store as a deliberately limited
   private-cache adapter, and mark that adapter deprecated before final 1.0.

The first option is cleaner. The second avoids breaking current RC examples but
leaves two cache contracts in the public surface. The decision must be recorded
in the API inventory; silently keeping URI-only semantics is not recommended.

The policy should also define:

- private versus shared store scope;
- whether responses to requests carrying `Authorization` are bypassed by
  default unless an explicit response directive or caller policy permits them;
- `Cache-Control` parsing including quoted values;
- `Expires`, `Date`, and `Age` freshness calculations;
- `Vary` selection and 304 metadata merging;
- `no-store`, `no-cache`, `private`, `public`, `must-revalidate`, and
  `s-maxage` behavior appropriate to the declared store scope;
- maximum entry bytes and eviction behavior for the in-memory implementation;
- mutation invalidation rules and an explicit `clear`/identity-change hook;
- whether stale responses are ever allowed, and under which caller directive;
- whether in-flight request coalescing is part of the contract or an extension.

#### Implementation plan

- **Affected packages/files:**
  `packages/alphax/lib/src/alpha_x_cache.dart`, public exports, policy tests,
  any cache examples, `docs/POLICIES.md`, package README, API inventory,
  requirements audit, and release-gate documentation.
- **Internal architecture:** introduce a variant key and metadata-aware entry;
  keep storage asynchronous; isolate freshness/selection decisions in a policy
  layer so a disk/encrypted store does not reimplement HTTP semantics.
- **Transport impact:** none for request/response transports. The middleware
  buffers only the operations it explicitly supports; streaming/file cache
  behavior remains out of scope.
- **Security:** default to a private cache; avoid cross-user reuse after token
  changes; do not cache `no-store`; prevent `Vary` and authorization cache
  poisoning; never log bodies or credential-bearing headers.
- **Persistence/storage:** retain a store interface; do not add a database or
  encryption dependency. Document that disk/shared stores must implement atomic
  writes, corruption handling, access control, and encryption where required.
- **Tests:** `Vary` variants; authorization/private-store behavior; `Expires`,
  `Age`, and `max-age`; quoted directives; 304 merge; `no-store`; mutation
  invalidation; cache-size bounds; concurrent misses; persistence failure;
  identity change; and a store that deliberately represents shared scope.
- **Documentation:** state that caching is off by default, that the supplied
  store is private in-memory storage, which HTTP directives are honored, and
  that “offline cache” is not an automatic queue or synchronization system.
- **Complexity/risk:** medium-high. It is not a transport rewrite, but cache
  correctness and credential isolation are security-sensitive and the store
  key is a public API decision.

#### Acceptance criteria

1. Two requests that differ in a response-declared `Vary` field cannot receive
   the wrong cached representation.
2. `no-store` and the selected authenticated-response policy are enforced for
   both memory and custom stores.
3. Freshness and revalidation use documented `Cache-Control`/`Expires`/`Age`
   rules, or the package explicitly labels the behavior as an application
   memoizer rather than an HTTP cache.
4. A persistent or encrypted store can be supplied without changing cache
   policy code.
5. Cache identity changes and mutation invalidation have deterministic tests.

## Explicitly acceptable for 1.0

### OAuth caller ownership is intentional

“OAuth orchestration remains caller-owned” excludes the full lifecycle around
authorization, not the HTTP mechanics of making OAuth requests. AlphaX should
provide no more than token injection, a refresh callback, single-flight refresh,
and one safe retry of the original replayable request.

The following correctly remain outside the HTTP client:

- **Authorization-code flow:** constructing the authorization URI, state and
  nonce, redirect URI handling, external browser launch, and redirect return
  handling. OAuth authorization-code flow explicitly interacts with a user
  agent and redirect endpoint; it is not just a POST helper. See
  [`RFC 6749 §4.1`](https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1).
- **PKCE:** generating, retaining, and binding a code verifier to an app login
  transaction. Native apps are expected to use an external user agent and
  PKCE; embedding that into a general HTTP client would create platform/UI
  dependencies. See [`RFC 7636`](https://www.rfc-editor.org/rfc/rfc7636.html)
  and [`RFC 8252 §§4-6`](https://www.rfc-editor.org/rfc/rfc8252.html#section-4).
- **Token storage:** refresh tokens are long-lived credentials. Secure
  keychain/keystore choice, encryption, rotation, revocation, logout, backup,
  and device-lock behavior belong to the app or a dedicated auth package.
- **Browser/session handling:** cookies and browser SSO are security-domain and
  user-agent responsibilities. A native app should use an external user agent,
  not make AlphaX impersonate a browser.
- **Discovery documents:** fetching and interpreting provider metadata is a
  normal HTTP request plus an auth-domain model. It may be a separate OAuth
  package and should not become part of `AlphaXClient`.
- **Client credentials:** a backend may implement a caller-owned callback that
  obtains and caches a token. The fact that the flow has no user interface does
  not make token lifecycle a transport responsibility.
- **Scope, consent, account switching, logout, and refresh-token rotation:**
  these are application identity state and must remain explicit at the call
  site.

Real applications affected are mobile SSO, desktop enterprise login, service
to service client-credentials, multi-tenant account switching, and APIs with
rotating refresh tokens. They can be implemented cleanly by combining an auth
package/platform browser with AlphaX’s token callbacks. They cannot and should
not be implemented by `alphax` alone.

Dio’s interceptor model, OkHttp’s `Authenticator`, URLSession’s authentication
challenge delegates, Dart IO’s `authenticate` callback, and reqwest’s request
builder all provide request-level credential hooks rather than a universal
OAuth UI/session framework. That comparison supports the existing AlphaX
boundary.

### In-memory cookies are a valid baseline

An in-memory jar is sufficient for short-lived API clients, tests, one-shot
sessions, and applications that intentionally do not persist credentials. It
is not sufficient for “remember me” sessions across restarts, but that is a
storage decision rather than a reason for AlphaX to choose a persistence
format.

The current jar handles important HTTP matching behavior: host-only versus
domain cookies, path matching, expiry, `Secure`, `HttpOnly`, replacement, and
deletion. The in-memory implementation now serializes asynchronous atomic
updates. The missing persistent store is therefore an extension concern. The
missing interface was the 1.0 API concern described above and is now resolved.

Competing designs support this split: OkHttp’s `CookieJar` explicitly allows
memory, file, or database stores; Dio delegates persistence to
`dio_cookie_manager`/`cookie_jar`; reqwest makes its cookie store optional; and
URLSession offers platform-owned persistent or ephemeral stores. None requires
AlphaX to own an application database.

### Persistent cache is an extension, after the contract is corrected

Disk caching is useful for image/catalog data, offline reads, startup latency,
and bandwidth reduction. It is not a universal HTTP-client requirement when a
store abstraction already exists. URLSession and Cronet provide native disk
stores because their platform sessions/engines own the storage lifecycle;
AlphaX’s portable core should not assume the same directory, encryption, quota,
or process-locking rules on every platform.

A caller-owned store can support memory, disk, encrypted disk, a database, or a
shared application cache. The cache middleware must still enforce the same
selection and security policy regardless of storage backend.

### Explicit HTTPS proxy endpoints are a platform boundary

The phrase “HTTPS proxy” is ambiguous and must be kept precise:

1. **HTTP proxy plus HTTPS destination:** connect in cleartext to an HTTP proxy,
   send `CONNECT origin:443`, then establish TLS through the tunnel to the
   origin. This is the common enterprise HTTPS-destination route and is not
   TLS-to-proxy.
2. **HTTPS proxy endpoint:** establish TLS from the client to the proxy first,
   authenticate the proxy under its own trust policy, then issue proxy traffic
   through that connection. This needs proxy-host validation and often a
   separate proxy CA/pinning policy.
3. **Proxy authentication:** Basic credentials, challenge-based credentials,
   and enterprise schemes are distinct from either route.
4. **System/PAC/environment proxy:** the operating system, browser, environment,
   or selected provider chooses the route and may apply policy AlphaX cannot
   inspect.

The current selected transport boundary is defensible:

- Dart IO can use environment/system selection, force `DIRECT`, and configure an
  explicit HTTP proxy. Its `HttpClient` exposes proxy authentication callbacks
  and credentials. The documented `findProxy` surface does not provide a
  portable TLS-to-proxy configuration.
- Apple URLSession uses system proxy settings by default and exposes proxy
  configuration APIs and authentication challenges. Newer Apple APIs can
  represent secure proxy/relay types, but the selected AlphaX shared mapping
  does not claim an explicit HTTPS endpoint.
- Android Cronet/provider behavior is provider and API-version dependent. The
  public builder has proxy options on supported implementations, but the
  selected AlphaX adapter must inspect provider capability and fail closed when
  it cannot enforce the requested mode or credentials.
- A browser controls proxy and PAC behavior outside the Web transport.

The comparison with reqwest and libcurl is useful but not dispositive: reqwest
accepts proxy URLs and libcurl documents `https://` proxy URLs plus separate
proxy TLS verification controls. Those stacks own their connector/TLS layers;
AlphaX’s selected providers do not all expose equivalent controls. The safe
1.0 action is therefore to retain `AlphaXProxyPolicy.https` as a truthful
future/provider-specific model, report capability, and fail closed. Never
silently use an HTTP proxy, direct connection, or origin TLS policy when the
caller asked for TLS to the proxy.

### Dart IO SPKI pinning may have a direct-only research path, but is not a safe 1.0 parity promise

The current limitation is more nuanced than “Dart has no certificate API”:

- [`HttpClient.badCertificateCallback`](https://api.dart.dev/dart-io/HttpClient/badCertificateCallback.html)
  is called only when the certificate cannot be authenticated by trusted roots;
  returning `true` accepts that otherwise bad certificate. It is not a
  post-validation pin callback.
- [`X509Certificate`](https://api.dart.dev/dart-io/X509Certificate-class.html)
  exposes the certificate DER bytes, but not a ready-made SPKI digest.
- [`SecureSocket.peerCertificate`](https://api.dart.dev/dart-io/SecureSocket/peerCertificate.html)
  exposes the peer certificate after a secure socket connects.
- [`HttpClient.connectionFactory`](https://api.dart.dev/dart-io/HttpClient/connectionFactory.html)
  and [`SecureSocket.startConnect`](https://api.dart.dev/dart-io/SecureSocket/startConnect.html)
  are stable public APIs that could support a custom direct connection path.

That means a future direct-only implementation could, in principle, create a
normally validated `SecureSocket`, inspect the peer certificate DER, extract the
SPKI with a reviewed DER parser, compare primary/backup pins, close on mismatch,
and only then return the socket to the HTTP layer. It must not use
`badCertificateCallback` to bypass trust.

The problem is complete transport behavior. The normal `HttpClient` path owns
proxy connection creation and, for an HTTPS destination through a proxy,
creates the origin TLS socket after the CONNECT tunnel. The public
`connectionFactory` hook is not a general post-validation callback for that
final tunneled socket. Reproducing all routes, pooling keys, redirects,
connection cancellation, hostname validation, and proxy behavior would be a
new Dart IO transport path with high security-test cost. The Dart SDK’s public
source shows this lifecycle in its [`HttpClient` connection implementation](https://raw.githubusercontent.com/dart-lang/sdk/main/sdk/lib/_http/http_impl.dart).

Consequently, the 1.0 decision remains fail closed. The rationale should say
“no complete, portable post-trust pinning path in the selected Dart IO
transport” rather than implying that no stable low-level certificate bytes or
socket hooks exist. A future implementation is possible only after a focused
proof of correct direct and proxied behavior; it is not a reason to accept a
trust-all callback or a leaf-only partial promise today.

### Safe retry defaults are sufficient, with explicit limits

The current policy correctly checks both method safety and
`request.body.isReplayable`. It bounds attempts and delay, honors numeric
`Retry-After`, observes cancellation during backoff, and does not automatically
replay a partially consumed response stream or file transfer. This is a sound
1.0 default.

The following are not automatic 1.0 requirements:

- **POST/PUT/PATCH:** PUT is method-idempotent by HTTP semantics, but server
  side effects still belong to the API contract. POST/PATCH require an explicit
  server/application idempotency design. A future request-level idempotency key
  or retry disposition would be clearer than a global policy switch, but the
  current opt-in switch is safe when documented.
- **Idempotency keys:** AlphaX should not invent or reuse a key. The caller must
  generate and scope it to its business operation. A future extension may let a
  caller declare the operation retryable and attach a key.
- **Replayable versus streaming bodies:** a buffered body can be recreated;
  an arbitrary stream or file may have advanced or changed. The current fail
  closed behavior is correct.
- **Retry-After:** RFC 9110 permits a delay-seconds value or an HTTP-date. The
  current numeric-only handling is a standards-completeness gap, but falling
  back to a bounded exponential delay does not create an unsafe replay. Date
  parsing should be a low-risk hardening item if retries are marketed as
  standards-aware.
- **Backoff/jitter/deadline:** exponential backoff and a bounded maximum delay
  exist. Jitter and a total retry budget are important fleet controls, but the
  custom delay hook and request timeouts allow an application extension.
- **Failure versus HTTP response:** the default error/status allowlists are
  intentionally narrow. Applications can narrow them further; they should not
  turn every 4xx response into a retry.
- **Refresh interaction:** the authentication middleware refreshes once for a
  replayable buffered request. Middleware order should be documented and
  tested; AlphaX must not refresh indefinitely or replay a non-replayable body.
- **Circuit interaction:** the built-in resilience middleware can contain a
  retry policy, so one logical operation can be counted after its retry policy
  completes. Applications that compose separate middleware need to choose the
  order deliberately.

OkHttp’s `retryOnConnectionFailure`, reqwest’s configurable retry policy, Dio’s
interceptor model, and curl’s lower-level retry ecosystem all demonstrate that
automatic retry is a policy layer, not a universal guarantee that every
mutation is safe. AlphaX’s conservative default belongs in 1.0.

### A small generic circuit breaker is sufficient as an opt-in primitive

The current breaker has the essential state machine: closed, open, one
half-open probe, reset after success, and fail-fast behavior while open. It
counts selected transport failures and 5xx responses, and its optional retry
composition is explicit.

It is not a complete service-resilience platform. It has no rolling window,
custom failure classifier, per-origin key, cross-isolate coordination,
observability callback, adaptive concurrency, or vendor-specific error budget.
Those omissions are justified because a transport-neutral client cannot infer
whether a 404, 409, 429, 503, timeout, or application error should trip a
particular service’s circuit.

For 1.0, document that state is per middleware instance and recommend one
client/middleware instance per independently isolated origin when that matters.
Add deterministic tests for concurrent half-open requests, cancellation,
success reset, retry composition, and non-transport errors. Defer richer
classification and telemetry to an extension.

## Post-1.0 candidates

These are useful, but they do not justify delaying or expanding the 1.0 core
once the two API-contract decisions above are resolved.

| Candidate | Why useful | Why not a 1.0 blocker |
| --- | --- | --- |
| File/database/encrypted cookie-store implementations | Restores sessions and supports platform-specific secure storage. | Storage format, migration, encryption, and logout semantics vary by application. The 1.0 requirement is the store seam, not a bundled database. |
| Disk/encrypted cache implementations | Enables startup cache, offline reads, and larger responses. | The existing store seam can host them; AlphaX should not choose quotas, encryption, or file locking. |
| Variant-aware cache request coalescing and stale-while-revalidate | Reduces duplicate requests and improves perceived latency. | Useful optimization/extension after correctness and security semantics are stable. |
| Retry jitter, HTTP-date `Retry-After`, total retry deadline, and per-request idempotency disposition | Improves fleet behavior and makes mutation retry intent explicit. | Safe defaults already avoid unsafe replay; these can be additive policy extensions. |
| Per-origin/rolling-window circuit breaker with observability | Better for multi-service applications and operations dashboards. | Topology and failure classification are application policy; the current generic primitive is honest when scoped. |
| Explicit HTTPS proxy endpoint support | Required by some enterprise networks. | Needs provider-specific proxy TLS, proxy trust, proxy auth, capability, and integration evidence. Partial support would be misleading. |
| Dart IO SPKI support | Gives pinning to Linux/Windows/Dart IO fallback users. | A direct-only proof is possible with public socket/certificate APIs, but complete proxy/pooling behavior is high risk and not yet validated. |
| Android Cronet mTLS identity support | Required by enterprise client-certificate APIs. | The selected provider’s public common surface does not guarantee client-certificate selection. |
| Background transfer adapter | Allows OS-managed mobile transfers after suspension or termination. | It is a separate lifecycle API, not a missing foreground HTTP primitive. |
| Dedicated OAuth integration package | Reduces caller boilerplate for specific browser and secure-storage stacks. | It should be a separate package with an explicit platform/auth dependency, not part of `alphax`. |
| SameSite-aware browser cookie policy | Useful for browser-like security models. | Web browsers already own SameSite and site context; a native core should not claim browser semantics. |

## Cross-cutting limitation inventory

The capability matrix is not the only source of 1.0 gaps. The repository was
also scanned for unsupported, caller-owned, intentional, in-memory,
transport-specific, fail-closed, experimental, and future markers.

| Discovered marker | Audit decision | Required treatment |
| --- | --- | --- |
| `AlphaXClient` requires an injected transport | Not a gap. | Keep it explicit and explain package selection. Automatic selection would hide provider capabilities and add platform coupling. |
| Android custom trust anchors are provider-limited | Platform limitation. | Capability/error state and documentation; never map an unavailable root policy to trust-all. |
| Apple/Dart IO trust and client identity controls differ | Platform limitation. | Keep the transport-neutral policy model and opaque identity reference; report unsupported controls per adapter. |
| Web custom trust, native proxy, proxy auth, file-path, and negotiated metadata controls | Browser limitation. | Keep Web separate and let browser/CORS/credential rules remain authoritative. |
| Background transfer | Extension candidate. | Do not put OS task identifiers or resume databases in the common 1.0 contract. |
| Offline queue | Not AlphaX responsibility. | Application sync/outbox logic owns durable ordering, conflict resolution, and business retry rules. |
| Telemetry/OpenTelemetry/Sentry/Firebase | Not AlphaX responsibility. | Expose safe normalized errors/metrics; let the application bridge them to its observability stack. |
| WebSocket, SSE, GraphQL, REST generators | Separate products/protocols or application tooling. | Keep out of the 1.0 HTTP request/response contract. |
| Deterministic fake transport and in-memory file fixtures in `alphax_test` | Intentional test-only limitation. | Do not present them as production transports or persistent file systems. |
| Vendor-specific resilience and authentication SDKs | Not AlphaX responsibility. | Keep generic middleware hooks and caller-owned orchestration. |
| Proxy authentication beyond the selected Basic/challenge paths | Provider-specific. | Report capability and fail closed; do not normalize an unsupported enterprise scheme as Basic. |
| SameSite and browser cookie context | Not the native core’s responsibility. | Explain that browser-managed Web cookies remain subject to browser rules. |

## Maintainer decision checklist

Before the final 1.0 public API freeze, the maintainer should record:

- whether `AlphaXCookieStore` is added now or the cookie middleware is marked
  non-stable/experimental;
- whether the cache store is migrated to a variant-aware key or explicitly
  narrowed to a private URI memoizer;
- whether current cache authenticated-response behavior is conservative enough
  for the intended store scope;
- whether retry HTTP-date parsing is accepted as post-1.0 hardening or added
  before release;
- whether the public docs use “HTTP cache” only after the cache contract is
  corrected;
- whether the Dart IO SPKI limitation wording acknowledges the stable
  direct-only research path while retaining fail-closed behavior;
- whether package README and migration docs clearly distinguish AlphaX policy
  middleware from application auth, persistence, and resilience policy.

## Final verdict

**Core transport client:** acceptable for 1.0 with the documented caller-owned
and platform-owned boundaries.

**Policy surface:** do not expand into OAuth, storage frameworks, or vendor
resilience. Before publishing a stable 1.0 policy API, address the cookie-store
abstraction and cache variant/security contract, or deliberately narrow/remove
those optional policy promises from the stable release.

**H3:** not reviewed, by explicit scope instruction.
