# Architecture Overview

## Transport architecture boundary

```text
Application / Flutter app
          │
          ▼
alphax
  request, response, headers, body, errors, cancellation, metrics, middleware
          │
          ▼
AlphaXTransport
          │
          ├── Dart IO fallback/baseline
          ├── Android Cronet/HttpEngine adapter
          └── Apple URLSession adapter
```

`alphax_native` also exports `createAlphaXTransport()`. It is the automatic
native-platform facade: Android selects Cronet/HttpEngine, iOS/macOS select
URLSession, and Linux/Windows select Dart IO. The factory is outside `alphax`
so the core remains pure Dart and transport-neutral. Web remains an explicit
`WebFetchTransport()` choice from the separate `alphax_web` package.

Optional caller-side extension:

```text
alphax_transform
  buffered bytes + sendable caller transform → one-shot native Isolate.run
```

`alphax_transform` depends on `alphax` but not on a transport. It is invoked
explicitly after the caller has buffered a response; it does not alter response
semantics, transport backpressure, or protocol behavior. Browser builds fail
closed rather than presenting synchronous browser work as background execution.

The accepted 1.0 architecture does not use a C++ engine or a production Rust
transport. A future change would require separate evidence plus an accepted ADR.

The `alphax` package is pure Dart and has no Flutter SDK dependency. It must not
know whether a request is handled by Dart, Cronet, URLSession, or a future
platform transport. `alphax_native` remains an integration boundary and must not
leak implementation types into `alphax`.

## Ownership by layer

### Dart

- Public request and response models.
- Headers, body abstractions, cancellation, timeout and priority policy.
- Middleware, authentication, cache/retry policy, decoding, and app integration.
- Transport-neutral errors and optional metrics.

### Native transport

- DNS, connection setup, TLS, protocol negotiation, pooling, multiplexing,
  streaming, cancellation, proxy transport, file descriptors, and low-level timing.
- Bounded buffering and direct file transfer where supported.

### Optional transform extension

- `alphax_transform` owns only one-shot native-isolate UTF-8/JSON decoding and a
  caller-supplied sendable transformation for already-buffered bytes.
- The package is opt-in and independently publishable. It must not become a
  dependency of `alphax`, `alphax_native`, or an automatic response middleware.
- Cancellation after isolate dispatch is result-discard semantics; it does not
  synchronously terminate the worker.

## Invariants

- No package may make `alphax` depend on Flutter or a native implementation.
- No production transport is selected before equivalent benchmark evidence and an
  accepted transport ADR.
- Unsafe mutations are not silently retried.
- Native ownership, callback lifetime, cancellation, and shutdown are explicit.
- Planned capabilities must not be described as supported.

## Current implementation

The stable package family uses the transport-neutral core with Dart IO as the
fallback, Android Cronet/HttpEngine where the native provider is available,
Apple URLSession on iOS and macOS, and browser Fetch in `alphax_web`. Optional
features such as policy middleware, the large-payload transform, SSE, and the
WebSocket contract remain layered above the transport boundary.
