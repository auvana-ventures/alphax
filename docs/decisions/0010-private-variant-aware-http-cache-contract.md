# ADR-0010: Private variant-aware HTTP cache contract

- Status: Accepted
- Date: 2026-08-17

## Context

The pre-freeze cache store used `Uri` as its only key. That could reuse one
representation for different methods or response variants and did not give a
custom store enough information to enforce `Vary`, freshness, validators, or
authenticated-response isolation. AlphaX needs an HTTP-aware private cache
without owning disk, database, or encryption storage.

## Decision

`alphax` exposes `AlphaXCacheKey`, which includes the HTTP method, URI,
request-header values available for `Vary` matching, and an optional opaque
caller-provided identity key. `AlphaXCacheEntry` retains the stored variant
key, response headers, body, validators, `Vary` fields, response age, and
freshness metadata. `AlphaXCacheStore` reads a matching variant, writes an
entry, removes all variants for a method/URI, and clears the store.

`AlphaXCacheMiddleware` is opt-in and private by default. It owns HTTP cache
selection and freshness semantics, including quoted Cache-Control parsing,
`no-store`, `no-cache`, `private`, `public`, `must-revalidate`, `max-age`,
`s-maxage` for explicitly shared scope, `Date`, `Age`, `Expires`, `Vary`, ETag,
Last-Modified, conditional requests, 304 metadata merging, and deterministic
GET/HEAD invalidation after POST/PUT/PATCH/DELETE. `Vary: *` is never reusable.

Authorization- or cookie-bearing requests bypass the cache unless the caller
supplies a stable non-secret identity key; proxy-authenticated requests always
bypass. Responses that set cookies are not stored by the bundled middleware.
Sensitive Vary fields are not persisted. The caller must change identity scope
or clear the store when the authenticated identity changes. The bundled memory
store is bounded by entry count and body bytes, uses deterministic
insertion-order eviction, and skips oversized entries. Request coalescing and
stale-while-revalidate are not part of 1.0.

Custom stores own durability, encryption, access control, corruption handling,
and asynchronous failure behavior; they must serialize concurrent writes.

## Alternatives considered

- Keep URI-only lookup: rejected because method and response variants can
  cross-contaminate.
- Add a disk cache: rejected because storage lifetime, quotas, encryption, and
  process locking vary by application/platform.
- Make full request coalescing or stale-while-revalidate a 1.0 requirement:
  rejected because they are optimizations beyond the correctness contract.
- Treat the cache as a generic URI memoizer: rejected because AlphaX already
  promises HTTP-aware freshness and revalidation behavior.

## Consequences

- The URI-only `AlphaXCacheStore` contract is replaced before publication;
  custom pre-RC stores must migrate to the variant-aware interface.
- A private cache is safe by default but does not provide offline sync or
  persistent storage.
- Shared-scope users explicitly opt into additional intermediary-style
  responsibilities and must supply an appropriate store.
- Correctness logic stays in AlphaX, while storage implementations remain
  replaceable.

## Evidence and revisit conditions

Deterministic tests cover method/URI keys, Accept-Language and Accept variants,
Vary star, quoted directives, Date/Age/Expires, authenticated identity scope,
private/shared behavior, ETag/Last-Modified revalidation, 304 merging,
mutation invalidation, bounds, asynchronous store writes, and store failures
in `packages/alphax/test/policy_contract_test.dart`.
Revisit only for a demonstrated 1.0 compatibility defect or a separately
approved post-1.0 optimization such as coalescing or stale-while-revalidate.
