# ADR-0009: Asynchronous cookie-store persistence boundary

- Status: Accepted
- Date: 2026-08-17

## Context

AlphaX needs consistent HTTP cookie parsing and matching without forcing a
database, filesystem, secure-storage package, or serialization format into
the pure-Dart core. The pre-freeze API used a concrete in-memory
`AlphaXCookieJar` in `AlphaXCookieMiddleware`, which prevented a caller-owned
durable or encrypted store from being supplied without changing the public
surface later.

## Decision

`alphax` exposes the transport-neutral asynchronous `AlphaXCookieStore`
interface with operations to read/write parsed `AlphaXCookie` values, atomically
update them, and clear the store. `AlphaXCookieMiddleware` performs
Cookie-header production and response `Set-Cookie` consumption over that seam,
so every storage adapter uses the same AlphaX parsing and matching rules.

`AlphaXCookieMiddleware` accepts `AlphaXCookieStore` directly.
`AlphaXCookieJar` remains the default in-memory implementation and serializes
atomic updates so concurrent response completions—including completions from
different clients sharing one store—cannot lose replacement or deletion
operations. Store failures are surfaced to the caller.

The store owns persistence, encryption, secure-storage integration, restore
policy, corruption handling, and lifecycle decisions. AlphaX keeps domain,
path, expiry, Secure, HttpOnly, host-only, replacement, and deletion semantics
in the in-memory implementation. SameSite and browser site-context behavior
remain browser/application responsibilities.

## Alternatives considered

- Keep the concrete jar in the middleware: rejected because it makes external
  persistence a post-1.0 breaking API change.
- Add a database or secure-storage implementation: rejected because storage,
  encryption, migration, and logout policy are application/platform concerns.
- Add browser SameSite behavior: rejected because the Web browser owns site
  context and cookie enforcement.

## Consequences

- Callers can implement memory, encrypted, database, file, or platform
  secure-storage adapters without changing AlphaX source.
- The current in-memory examples remain simple, but cookie operations that
  mutate or read the store are asynchronous. Custom stores must implement
  `updateCookies` as a transaction or equivalent lock.
- AlphaX does not promise cookie persistence across process restarts.
- Store implementations must provide concurrency-safe updates and must not log
  cookie or token values.

## Evidence and revisit conditions

Deterministic cookie tests cover domain/host-only/path/expiry/Secure/HttpOnly,
replacement/deletion, concurrent updates, clear/logout, store failures, and
diagnostic redaction in `packages/alphax/test/policy_contract_test.dart`.
Revisit only if a 1.0-compatible cookie attribute or browser integration
requirement cannot be represented by this store seam.
