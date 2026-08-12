# Architecture Overview

## Phase 0 boundary

```text
Application / Flutter app
          │
          ▼
alphax
  request, response, headers, body, errors, cancellation, metrics
          │
          ▼
AlphaXTransport
          │
          ├── dart:io baseline
          ├── libcurl multi through a small C ABI/FFI bridge
          └── Rust reqwest/hyper through a C ABI/FFI bridge
```

Phase 0 does not use a C++ engine. A future C++ boundary would be a separate
architectural proposal and would require benchmark evidence plus an accepted ADR.

The `alphax` package is pure Dart and has no Flutter SDK dependency. It must not
know whether a request is handled by Dart, C/libcurl, Rust, or a future platform
transport. `alphax_native` is an experimental integration boundary and is not a
production transport during Phase 0.

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

## Invariants

- No package may make `alphax` depend on Flutter or a native implementation.
- No production transport is selected before equivalent benchmark evidence and an
  accepted transport ADR.
- Unsafe mutations are not silently retried.
- Native ownership, callback lifetime, cancellation, and shutdown are explicit.
- Planned capabilities must not be described as supported.

## Phase progression

Phase 0 validates contracts and transport candidates. Phase 1 begins only after the
transport choice, FFI design, benchmark suite, public contracts, package boundaries,
and CI are accepted.
