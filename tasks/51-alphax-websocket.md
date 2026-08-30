# Task 51 — AlphaX WebSocket

Status: [x] Completed

## Goal

Add first-class, transport-neutral WebSocket lifecycle support through
`package:alphax/websocket.dart`, with maintained native and browser connectors
provided by the integration packages.

## Scope and Non-goals

Scope:

- Define a small connector/session/message/close/capability contract in `alphax`.
- Adapt the maintained `package:web_socket` implementation in `alphax_native`
  and `alphax_web`.
- Preserve deterministic lifecycle, cancellation, close, subprotocol, text,
  binary, and streaming semantics.
- Add provider, conformance, local-fixture, browser, example, and documentation
  coverage required by the approved Task D specification.

Non-goals:

- No WebSocket engine, HTTP `AlphaXTransport.send()` integration, automatic
  reconnect, backoff, replay, resend queue, or GraphQL behavior.
- No `alphax_websocket` package, generator, OpenAPI, Protobuf, SSE, WebSocket
  framework adapter, gRPC, or broader ecosystem work.
- No arbitrary browser request-header support, native certificate bypass, or
  provider-specific objects in the portable contract.
- No changes to the existing HTTP transport, streaming window, native HTTP
  providers, `alphax_http`, Dio adapter, or transform helper.

## Owner

AlphaX maintainers.

## Dependencies

The core contract remains pure Dart and has no WebSocket runtime dependency.
`alphax_native` and `alphax_web` use the maintained `web_socket` package as
their provider adapter dependency. Tests use existing Dart/Flutter test tooling
and local deterministic fixtures only.

## Assumptions

- The maintained `package:web_socket` abstraction is the appropriate shared
  provider seam for Dart IO and browser WebSocket implementations.
- Its provider-level API exposes complete text/binary messages, negotiated
  subprotocol reporting, close information, and no portable arbitrary headers
  or manual ping/pong; AlphaX will report those limitations honestly.
- WebSocket is a separate full-duplex lifecycle and must not be added to
  `AlphaXClient` or `AlphaXTransport` merely for API symmetry.
- An injected session is caller-owned; connector/session close is explicit and
  deterministic.

## Work Items

- [x] Confirm the locked WebSocket boundary, provider API, task number, and
  existing lifecycle/cancellation conventions.
- [x] Implement the core WebSocket contract and dedicated public library.
- [x] Implement native and browser connectors without adding a new package or
  WebSocket engine.
- [x] Add deterministic conformance, provider, local-server, browser, and
  compile-tested example coverage.
- [x] Update public/root/user/integration documentation and export decisions.
- [x] Run the required validation, complete the final review, commit only Task D
  changes, push to `origin/main`, and return for maintainer review.

## Validation

Passed on 2026-08-30:

- `dart format --set-exit-if-changed` for all changed Dart sources.
- `dart analyze` for `alphax`, `alphax_dio`, `alphax_http`, `alphax_test`,
  `alphax_transform`, and `alphax_web`; `flutter analyze` for
  `alphax_native`.
- Core WebSocket tests (3), focused native WebSocket tests (13), Chrome
  browser tests (3), and VM-gated browser tests (3).
- `./tooling/scripts/test_packages.sh`: all seven package suites passed.
- Dartdoc `--validate-links` for all seven packages: zero errors; existing
  relative-example/generated-doc warnings are recorded in the final review.
- Markdownlint with repository-approved MD013/MD033/MD060 exclusions and a
  local relative-link target check.
- All seven package publication dry-runs with archive inspection.
- Dependency graph, secret/path, protected-file, and `git diff --check` audits.

No performance benchmarks were run. The workspace has seven package
directories, not eight; all seven were tested and analyzed.

## Next Action

Return for maintainer review. Do not begin Task E, generator, OpenAPI, Protobuf,
GraphQL framework, gRPC, SSE, or broader ecosystem work from this task.

## Blockers

None.

## Outcome

Implemented and validated. The pure-Dart WebSocket lifecycle contract is exposed
through `package:alphax/websocket.dart`; `alphax_native` and `alphax_web` expose
thin maintained `package:web_socket` connectors. The default AlphaX HTTP API and
all existing HTTP transports remain unchanged. The final review is
`docs/ALPHAX_RC5_WEBSOCKET_REVIEW.md` and concludes `RC5 WEBSOCKET READY`.

## References

- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md`
- `docs/ALPHAX_RC5_WEBSOCKET_REVIEW.md`

## History

- 2026-08-30 — Task D approved for implementation by the maintainer request.
- 2026-08-30 — Reserved monotonic task number 51 after inspecting `tasks/`.
- 2026-08-30 — Added the transport-neutral contract, native/browser adapters,
  local fixture coverage, browser coverage, examples, and documentation.
- 2026-08-30 — Full seven-package tests and analysis passed; native focused
  WebSocket tests (13), Chrome browser tests (3), core tests (3), package
  dry-runs, Dartdoc, Markdown/link, dependency, security/path, and formatting
  checks passed with documented Dartdoc baseline warnings only.
- 2026-08-30 — Task marked Completed; ready for maintainer review and the locked
  next task, Task E — direct typed REST generator.
