# AlphaX 1.0 policy API freeze review

**Review date:** 2026-08-17
**Proposed release:** `1.0.0-rc.1`
**Scope:** pre-freeze cookie-store and cache-contract corrections only

This review covers the two approved changes from the capability-gap audit. It
does not reopen HTTP/3 constraints, transport research, benchmarking, accepted
platform limitations, or deferred product features. No persistence
implementation, OAuth orchestration, vendor resilience policy, offline queue,
request coalescing, WebSocket/SSE support, or transport change is included.

## 1. Final cookie-store API

`alphax` now exposes the transport-neutral asynchronous contract:

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

`AlphaXCookieMiddleware` accepts `AlphaXCookieStore` directly. The middleware
owns Cookie-header production, Set-Cookie parsing, domain/path matching,
expiry, Secure, HttpOnly, host-only, replacement, deletion, and expired-cookie
filtering. `updateCookies` is the atomic read/transform/write boundary required
to prevent concurrent response updates from being lost, including when
multiple clients share one store.

## 2. In-memory cookie behavior

`AlphaXCookieJar` remains the bundled default implementation. It is:

- asynchronous at its public store and convenience operations;
- in-memory and non-persistent;
- serialized for reads, replacements, deletions, clear, and response updates;
- host-only/domain and path aware;
- Secure aware and HttpOnly-preserving;
- expiry and deletion aware; and
- free of cookie/token values in diagnostics.

`SameSite` is intentionally not modeled. Native AlphaX is not a browser user
agent, and Web browser cookie/site-context behavior remains browser-owned.

## 3. Persistence boundary

AlphaX does not include a database, filesystem store, secure-storage package,
encryption format, or restore-after-login policy. Applications may implement
`AlphaXCookieStore` over memory, encrypted storage, a database, a file, or a
platform secure store. Such adapters own serialization, encryption, access
control, corruption handling, lifecycle, logout clearing, and transaction
locking. Failures must be surfaced; a failed read must not silently become an
empty cookie jar.

Existing concrete-jar usage remains structurally simple:

```dart
final jar = AlphaXCookieJar();
final client = AlphaXClient(
  transport: transport,
  middleware: <AlphaXMiddleware>[AlphaXCookieMiddleware(jar)],
);
await jar.clear();
```

The migration impact is that cookie reads, writes, clearing, and convenience
header/response operations are asynchronous and must be awaited. Custom stores
must implement `updateCookies` as a transaction or equivalent lock.

## 4. Final cache-key model

The URI-only public store contract is replaced by:

- `AlphaXCacheKey`: HTTP method, URI, request-header values available for
  response `Vary` matching, and an optional non-secret identity scope;
- `AlphaXCacheEntry`: stored key, response status/headers/body, storage time,
  response `Vary`, validators, `Date`, accumulated `Age`, freshness lifetime,
  and revalidation metadata; and
- `AlphaXCacheStore`: asynchronous `read`, `write`, resource-level `remove`,
  and `clear` operations.

`read` must return only a matching method/URI/identity/Vary variant. `remove`
invalidates all variants for a method and URI so mutation invalidation cannot
leave another representation behind. Custom stores own persistence and must
serialize concurrent writes.

## 5. Vary behavior

The middleware stores the request-header values selected by the response's
`Vary` fields and requires those values to match on lookup. This keeps
`Accept-Language: en` separate from `Accept-Language: fr`, and
`Accept: application/json` separate from another representation. Header names
are normalized case-insensitively.

`Vary: *` is never stored or reused. `Authorization`, `Proxy-Authorization`,
`Cookie`, and `Set-Cookie` are treated as sensitive variant boundaries and are
not placed in the built-in cache key. A response varying on those fields is
not stored by the bundled middleware.

## 6. Freshness and revalidation behavior

The cache is opt-in and buffered for `GET` and `HEAD`. The middleware honors
the supported private/shared HTTP policy directives:

- `no-store` prevents storage;
- `no-cache` and request `max-age=0` require revalidation;
- `max-age` controls freshness for a private cache;
- `s-maxage` takes precedence only for an explicitly shared cache;
- `private` prevents storage in shared scope;
- `public` and `must-revalidate` are retained and used for shared-scope
  authenticated-response decisions; and
- `Date`, `Age`, and `Expires` contribute to conservative current-age and
  freshness calculations, including quoted directive values.

ETag and Last-Modified validators are added to stale requests when the caller
has not supplied them. A `304 Not Modified` response merges response metadata
into the stored representation, refreshes its age/freshness state, and keeps
the cached body. `stale-while-revalidate` and `stale-if-error` are not claimed
or implemented.

## 7. Authenticated-response policy

By default, requests carrying `Authorization` or `Cookie` bypass cache lookup
and storage. Requests carrying `Proxy-Authorization` always bypass this
application cache. Responses containing `Set-Cookie` are not stored by the
bundled middleware.

An application may intentionally cache a credentialed private session by
providing a stable, non-secret `AlphaXCachePolicy.identityKey`. The key is a
scope label, not a token. The application must change the key or clear the
store when the identity changes. Separate identity keys cannot reuse one
another's entries. Shared-scope credentialed responses additionally require
explicitly cacheable intermediary semantics (`public`, `must-revalidate`, or
`s-maxage`).

This is an identity-aware opt-in, not a claim that AlphaX can discover or
validate application identities.

## 8. Private/shared cache semantics

The default `AlphaXCacheScope.private` describes a cache owned by one client,
application session, or intentionally isolated identity. It is bounded
in-memory storage, not a shared intermediary or proxy cache. `shared` is an
explicit caller choice and carries responsibility for shared-store access
control, persistence, encryption, process coordination, and intermediary
semantics.

The bundled `AlphaXMemoryCacheStore` is bounded by both `maxEntries` and
`maxBytes`, evicts in deterministic insertion order, and skips an entry larger
than `maxBytes`. It does not provide request coalescing, stale serving, or
offline synchronization.

## 9. Mutation invalidation

`POST`, `PUT`, `PATCH`, and `DELETE` invalidate all cached `GET` and `HEAD`
variants for the request URI before the mutation proceeds. This is the
existing deterministic AlphaX policy, retained after the contract correction.
It is not an offline queue or synchronization protocol.

## 10. Extension and persistent-store boundary

`AlphaXCookieStore` and `AlphaXCacheStore` are the extension seams. AlphaX
retains HTTP policy correctness; caller-owned stores retain storage concerns:

- durability and restart recovery;
- encryption and key management;
- access control and session isolation;
- quotas, eviction beyond the bundled memory bounds;
- corruption and migration handling;
- multi-process or multi-isolate coordination; and
- storage failure reporting.

No storage framework or platform type leaks into `alphax`.

## 11. Retry hardening

The contained optional hardening was performed: `AlphaXRetryPolicy` now
accepts both delay-seconds and HTTP-date forms of `Retry-After`, bounded by
the existing `maxDelay`. No jitter, retry budget, per-request idempotency API,
or broader retry-policy redesign was added.

## 12. Public API changes

The pre-publication policy API now includes:

- `AlphaXCookieStore.updateCookies` and direct store injection into
  `AlphaXCookieMiddleware`;
- `AlphaXCacheScope`;
- `AlphaXCacheKey`;
- the metadata-aware `AlphaXCacheEntry`;
- the variant-aware `AlphaXCacheStore` methods; and
- bounded `AlphaXMemoryCacheStore(maxEntries, maxBytes)` behavior.

The old URI-only cache methods are not retained as a second permanent public
API. These decisions are recorded in [ADR 0009](decisions/0009-cookie-store-persistence-boundary.md)
and [ADR 0010](decisions/0010-private-variant-aware-http-cache-contract.md).

## 13. Migration impact

Existing in-memory cookie middleware remains recognizable:
`AlphaXCookieMiddleware(AlphaXCookieJar())`. Callers must await jar operations,
and persistent implementations should implement the store interface rather
than subclassing or replacing AlphaX parsing rules.

Custom pre-RC cache stores must migrate from `read(Uri)`,
`write(Uri, entry)`, and `remove(Uri)` to `AlphaXCacheKey`/`AlphaXCacheEntry`
operations. There is intentionally no URI-only compatibility API in the
frozen 1.0 contract. See [MIGRATION.md](MIGRATION.md).

## 14. Tests

`packages/alphax/test/policy_contract_test.dart` covers:

- cookie domain, host-only, path, expiry, replacement, deletion, Secure,
  HttpOnly metadata, concurrent updates, clear/logout, asynchronous failure,
  and diagnostic redaction;
- method/URI cache keys, Accept-Language and Accept variants, `Vary: *`,
  quoted directives, `no-store`, `no-cache`, private/shared behavior,
  `max-age`, `Expires`, `Age`, `s-maxage`, ETag and Last-Modified revalidation,
  304 merge, credential identity isolation, cookie-bearing bypass,
  Set-Cookie exclusion, mutation invalidation, bounds, custom async stores,
  and store failures; and
- HTTP-date `Retry-After` parsing with bounded delay.

The focused policy suite passed with 35 tests. The final repository validation
also passed:

- `dart format --set-exit-if-changed .` reported no changes;
- all five package test suites passed, including shared conformance tests;
- package analysis and example analysis passed;
- both Flutter examples passed their widget/data tests;
- Dartdoc dry-runs passed for all five packages with zero warnings/errors;
- internal Markdown links resolved; Markdown structural lint passed with the
  repository's pre-existing long-line/table-style rules disabled;
- package dry-runs passed with no packaging errors: `alphax` 49 KB,
  `alphax_native` 73 KB, `alphax_dio` 12 KB, `alphax_test` 10 KB, and
  `alphax_web` 9 KB. The only warnings were expected dirty-worktree warnings
  because this review deliberately stops before commit;
- dependency inspection found no discontinued, retracted, or advisory-affected
  packages in the checked package graphs; and
- `git diff --check` and the credential/signing/path audit passed. No
  benchmark or transport performance run was performed.

## 15. Remaining caller/platform boundaries

These accepted boundaries are unchanged:

- OAuth authorization-code/PKCE/browser/session/discovery/token-storage
  orchestration remains caller/auth-library owned;
- persistence implementations remain caller-owned;
- explicit HTTPS proxy endpoints remain provider-limited and fail closed;
- Dart IO SPKI pinning remains unsupported and fail-closed;
- mTLS remains provider/platform-specific and optional;
- background transfer remains extension territory;
- Web browser cookies, CORS, TLS, proxy, and credential controls remain
  browser-owned; and
- vendor-specific resilience remains outside core AlphaX.

No transport architecture or benchmark result was changed by this work.

## 16. Policy API freeze decision

The public seams are transport-neutral, storage-independent, variant-aware,
credential-conservative, and documented. Persistent cookie/cache stores can be
implemented externally without changing AlphaX source or weakening the
bundled defaults.

Final validation status: complete. The public exports contain no accidental
transport, Flutter, storage, or platform types; the internal HTTP-date helper
is not exported. The remaining package changes are limited to this approved
policy work and retained documentation/test evidence.

READY TO FREEZE ALPHAX 1.0 POLICY API
