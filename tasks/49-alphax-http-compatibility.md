# Task 49 — AlphaX HTTP Compatibility

Status: [x] Completed

## Goal

Add the small `alphax_http` interoperability package so maintained libraries that
accept a `package:http` `Client` can use an existing `AlphaXClient` without a
framework-specific adapter or a second HTTP implementation.

## Scope and Non-goals

Scope:

- Add `packages/alphax_http` with the `AlphaXHttpClient` `BaseClient` seam.
- Preserve request and response streaming, package:http-visible errors, redirects,
  multipart behavior, client reuse, and explicit ownership.
- Add deterministic bridge tests plus bounded Chopper, GraphQL HTTP, generic consumer,
  and local production-transport smoke validation.
- Update the compatibility README, root/user guidance, and the final review report.

Non-goals:

- No changes to AlphaX package architecture or the rc.5 scope lock.
- No Flutter, native-provider, Dio, Chopper, GraphQL, OpenAPI, generator, SSE, or
  WebSocket runtime dependency in `alphax_http`.
- No new AlphaX request/response/configuration types, retry/timeout/cancellation
  policy layer, performance work, publication, tag, or release.
- No `alphax_io` package and no attempt to solve the pure-Dart provider packaging
  limitation.

## Owner

AlphaX maintainers.

## Dependencies

Runtime dependencies are limited to `alphax` and `http`. Test-only dependencies may
use `alphax_test`, `test`, and disposable ecosystem fixtures without leaking those
packages into the published runtime graph.

## Assumptions

- `package:http` 1.x `BaseClient.send(BaseRequest)` remains the maintained injection
  seam and is sufficient for normal Client behavior.
- `AlphaXStreamBody` can carry a finalized package:http body stream without eager
  buffering.
- AlphaX's existing request contract can represent the standard package:http methods,
  headers, body length, cancellation trigger, and redirect follow/max settings.
- AlphaX has no authoritative reason phrase, persistent-connection flag, or public
  redirect-list equivalent in `StreamedResponse`; the bridge must retain unknowns as
  unknown/default values rather than inventing them.
- The injected `AlphaXClient` is caller-owned by default. Closing the compatibility
  client must not close that borrowed client.

## Work Items

- [x] Confirm the package:http boundary and dependency requirements.
- [x] Create `alphax_http` and implement `AlphaXHttpClient`.
- [x] Add deterministic request, response, streaming, multipart, cancellation,
  redirect, error, reuse, close, and compatibility tests.
- [x] Run bounded Chopper, GraphQL HTTP, generic consumer, and production-transport
  smoke fixtures.
- [x] Update package/root/user documentation and record capability loss honestly.
- [x] Run validation, complete the final review, commit only Task B changes, and push
  to `origin/main`.

## Validation

Completed validation includes `dart format`, `dart analyze`, `alphax_http` tests, all
existing six AlphaX package tests, package:http-focused conformance tests, Chopper and
GraphQL fixtures, bounded generic/local transport smoke tests, Dartdoc, Markdown and
internal-link checks, package dry-run/archive inspection, dependency/security/path
audits, and `git diff --check`; exact results are recorded in
[`docs/ALPHAX_RC5_HTTP_COMPATIBILITY_REVIEW.md`](../docs/ALPHAX_RC5_HTTP_COMPATIBILITY_REVIEW.md).
No performance benchmarks or unrelated platform builds were run.

## Next Action

Return for maintainer review. Do not begin Task C or any SSE, WebSocket, generator,
OpenAPI, Protobuf, or broader ecosystem work in this task.

## Blockers

None.

## Outcome

Implemented `packages/alphax_http` with a borrowed `AlphaXHttpClient` BaseClient
bridge, deterministic mapping/streaming/multipart/cancellation/close tests, bounded
Chopper and GraphQL HTTP fixtures, a generic consumer proof, and a local production
transport smoke test. Root and user documentation now present this package as an
optional ecosystem escape hatch. The final review concludes `RC5 ALPHAX_HTTP READY`.

## References

- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md`
- `docs/ALPHAX_RC5_HTTP_COMPATIBILITY_REVIEW.md`

## History

- 2026-08-30 — Task B approved for implementation by the maintainer request.
- 2026-08-30 — Reserved monotonic task number 49 after inspecting `tasks/`.
- 2026-08-30 — Implemented and validated the package, fixtures, documentation, and
  final review; ready for maintainer review.
