# Phase 1A public transport-independent contracts

Status: [x] Completed

## Goal

Stabilize the pure-Dart AlphaX 1.0 public contracts so Dart IO, Android
Cronet/HttpEngine, and Apple URLSession transports can implement one behavioral
surface without leaking implementation-specific types.

## Scope and Non-goals

Scope:

- Finalize request, response, body, headers, method, error, cancellation,
  timeout, streaming, redirect, protocol, capability, metrics, progress, file,
  middleware, and client-lifecycle contracts.
- Support the required HTTP methods and body forms in the transport-neutral API.
- Build `alphax_test` fake transports, fixtures, request recording, and a
  reusable transport conformance suite.
- Update public API documentation, architecture contract documentation, and a
  Phase 1A review report.

Non-goals:

- No Dart IO transport implementation.
- No Cronet/HttpEngine, URLSession, FFI, platform-channel, C++, or Rust
  production transport implementation.
- No cache, retry/resilience, authentication, telemetry, Dio integration,
  WebSocket/SSE, GraphQL, REST generation, or package publication.
- No H2/H3 support claim before a platform adapter negotiates and validates it.

## Owner

Codex, with maintainer review required before Phase 1B.

## Dependencies

- Accepted ADR 0004 and `docs/ALPHAX_1_0_SCOPE.md`.
- Dart SDK `>=3.8.0 <4.0.0`.
- Existing `alphax` and `alphax_test` package boundaries.
- Existing package lint and test configuration.

## Assumptions

- `alphax` remains pure Dart with no Flutter SDK dependency.
- Transport implementations may report unavailable or unknown capabilities and
  metrics; they must not fabricate protocol negotiation or unsupported behavior.
- Response streams and non-replayable request streams are single-consumption
  unless a body explicitly documents replayability.
- File sources and targets are public abstractions; native handles, descriptors,
  and platform task types remain private to adapters.

## Work Items

- [x] Inspect and replace the minimal Phase 0 public model where it conflicts
  with the accepted 1.0 contract.
- [x] Implement the transport-neutral client, request/response, body, headers,
  protocol, capability, metrics, progress, file, cancellation, timeout,
  redirect, error, middleware, and lifecycle APIs.
- [x] Add focused unit tests for immutability, validation, lifecycle, body
  consumption, cancellation, and middleware behavior.
- [x] Add `alphax_test` fakes, delayed/failure/cancellation behavior, request
  recording, and reusable transport conformance tests.
- [x] Update architecture/API documentation and write the Phase 1A review
  report without starting a transport implementation.
- [x] Run consolidated formatting, analysis, tests, API inventory, and package
  dry-run validation; self-review the task-owned diff.

## Validation

Completed final validation:

- `dart format --output=none --set-exit-if-changed packages/alphax
  packages/alphax_test packages/alphax_native packages/alphax_dio` passed.
- `dart analyze` for all four affected packages passed.
- All affected package tests passed: 36 tests across `alphax`, `alphax_test`,
  `alphax_native`, and `alphax_dio`.
- `dart pub publish --dry-run --ignore-warnings` validated all four package
  archives. The only warning was the expected dirty-worktree notice; nothing
  was published.
- `dart doc --validate-links` passed for `alphax` and `alphax_test` with zero
  warnings/errors.
- Markdown lint, `git diff --check`, public API inventory review, and the
  no-Flutter/no-native-import audit passed.

## Next Action

Stop for maintainer review. Do not begin Phase 1B, Dart IO, Cronet/HttpEngine,
URLSession, Dio integration, or deferred features from this task.

## Blockers

None.

## Outcome

Implemented and validated the Phase 1A contract and test foundation. The public
review is recorded in `docs/phase1a-api-review.md`; no production transport was
started.

## References

- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- `packages/alphax/lib/alphax.dart`
- `packages/alphax_test/lib/alphax_test.dart`
- `docs/phase1a-public-api-inventory.md`
- `docs/phase1a-api-review.md`

## History

- 2026-08-14: Reserved for the approved Phase 1A public-contract work.
- 2026-08-14: Implemented the pure-Dart API, updated dependent placeholders,
  added fake/file fixtures and conformance tests, and completed validation.
