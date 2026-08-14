# Phase 1B — Dart IO fallback transport

Status: [x] Completed

## Goal

Implement a production-quality `DartIoTransport` using one reusable
`dart:io` `HttpClient` behind the frozen Phase 1A transport-neutral contract.
The adapter must provide the required HTTP/1.1 fallback behavior without
claiming HTTP/2 or HTTP/3 support.

## Scope and Non-goals

Scope:

- implement the Dart IO adapter in the existing `alphax_native` transport
  boundary;
- support the required methods, body forms, progressive response/request
  streaming, redirects, files, progress, cancellation, timeouts, normalized
  errors, lifecycle, reuse, and honest capabilities;
- add deterministic local integration fixtures and transport-specific tests;
- run the shared `alphax_test` conformance suite against the real adapter;
- document actual Dart IO behavior and Phase 1B findings.

Non-goals:

- Android Cronet/HttpEngine or Apple URLSession implementation;
- C++, Rust, libcurl, FFI, Flutter dependencies, or new transport architecture;
- Dio integration, retry/auth/cache/resilience/telemetry, WebSocket/SSE, or
  other deferred features;
- Phase 0 benchmark matrices or transport-ranking claims.

## Owner

Codex coordinator with the repository maintainer reviewing the Phase 1B
contract evidence.

## Dependencies

- accepted ADR 0004 and `docs/ALPHAX_1_0_SCOPE.md`;
- Phase 1A commit `c16f665` and the public contracts in `packages/alphax`;
- shared fakes, file fixtures, and conformance suite in `packages/alphax_test`;
- Dart SDK `>=3.8.0 <4.0.0`.

## Assumptions

- `packages/alphax_native` remains the approved adapter boundary; no separate
  `alphax_dart_io` package is introduced without a new package-scope review.
- Dart IO's standard TLS verification remains enabled and no trust-all callback
  is installed.
- A response returned by `send` remains lazy/streamed; the adapter does not
  buffer complete response bodies merely to satisfy metrics or timeouts.
- Provider-specific timings unavailable from `HttpClient` remain unavailable.

## Work Items

- [x] Add the public `DartIoTransport` adapter without exposing `dart:io` types
  in its required API.
- [x] Implement required methods and all supported Phase 1A body forms with
  single-consumption and backpressure semantics.
- [x] Implement response streaming, redirects, files, progress, cancellation,
  timeout mapping, error normalization, and client shutdown.
- [x] Add real local HTTP/TLS integration fixtures and transport-specific tests.
- [x] Run the shared conformance suite and fix only transport-neutral contract
  issues; record any genuine mismatch for maintainer review.
- [x] Update package/docs/changelog and create the Phase 1B review report.

## Validation

Completed final validation:

- Formatting passed for all four Dart packages.
- Analysis passed for `alphax`, `alphax_test`, `alphax_native`, and `alphax_dio`.
- All affected package tests passed, including 23 real-client/conformance tests.
- `dart doc --validate-links` passed for `alphax`, `alphax_test`, and
  `alphax_native` with zero warnings/errors.
- Markdown checks passed for changed Markdown files.
- All four `dart pub publish --dry-run --ignore-warnings` validations passed;
  ordinary validation warnings are only the expected dirty-worktree warning.
- `git diff --check` and the public API audit passed.

No pub.dev publication is authorized.

## Next Action

Stop for maintainer review. Do not begin Phase 1C, URLSession, Cronet/HttpEngine,
Dio, or deferred features.

## Blockers

None currently.

## Outcome

`DartIoTransport` implements the Phase 1B HTTP/1.1 fallback in
`alphax_native`. It passes the shared conformance suite and deterministic local
integration coverage for methods, bodies, streaming, progress, redirects,
timeouts, cancellation, files, TLS verification, middleware, lifecycle, and
connection reuse. H2/H3 and native platform transport work remain deferred.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/architecture/transport_contract.md`
- `docs/phase1a-api-review.md`
- `packages/alphax_test/lib/src/transport_conformance.dart`

## History

- 2026-08-14: Task reserved as the next monotonic task number after Phase 1A
  approval; Phase 1B work started after commit `c16f665` was pushed.
- 2026-08-14: Completed Dart IO implementation, integration tests, docs, and
  validation. Added a non-breaking middleware lifecycle guard discovered during
  review; no public transport API redesign was made.
