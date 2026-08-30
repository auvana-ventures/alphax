# Task 50 — AlphaX Server-Sent Events

Status: [x] Completed

## Goal

Add first-class Server-Sent Events support as the small pure-Dart
`package:alphax/sse.dart` parser layer over the existing AlphaX HTTP response
stream.

## Scope and Non-goals

Scope:

- Add `AlphaXSseEvent` and an incremental `AlphaXSseParser` transformer.
- Correctly parse incremental UTF-8, SSE line endings, fields, data joining,
  comments, IDs, retry hints, BOM, stream errors, cancellation, and bounded
  parser buffering.
- Validate the parser through the existing native Dart IO response stream and a
  browser Fetch response stream where the environment permits.
- Update public AlphaX, root, usage, and necessary native/Web documentation plus
  a compile-checked example and final review.

Non-goals:

- No new `alphax_sse` package, transport engine, request helper, reconnect loop,
  hidden retry, `Last-Event-ID` automation, or EventSource implementation.
- No changes to `AlphaXTransport.send`, streaming windows, native transports,
  `alphax_http`, the Dio adapter, or the transform helper.
- No WebSocket, generator, OpenAPI, Protobuf, GraphQL framework, gRPC, benchmark,
  or broader ecosystem work.
- No new runtime dependency merely for parsing SSE.

## Owner

AlphaX maintainers.

## Dependencies

The runtime implementation uses only Dart core libraries and the existing
`alphax` stream/request contracts. Native and Web validation may exercise their
existing integration packages; no new runtime package dependency is expected.

## Assumptions

- The SSE wire format is UTF-8 and can be decoded incrementally with Dart's
  strict streaming `Utf8Decoder`.
- `StreamTransformer<List<int>, AlphaXSseEvent>` is the smallest useful public
  parser seam and preserves source stream pause/cancel behavior.
- A parser event reports fields from the dispatched SSE event block. It does not
  own reconnection state or automatically send `Last-Event-ID`.
- The existing `AlphaXResponse.stream` is sufficient; no SSE-specific transport
  path or HTTP content-type gate is required.

## Work Items

- [x] Confirm the locked SSE boundary, public-library location, task number, and
  existing AlphaX streaming/cancellation APIs.
- [x] Implement the minimal `alphax/sse.dart` event/parser API with strict
  incremental decoding and documented limits.
- [x] Add deterministic parser, chunk-boundary, error, cancellation,
  backpressure, and limit tests.
- [x] Add native and browser Fetch stream validation plus compile-tested example
  coverage where the available environment supports it.
- [x] Update public/root/user/native/Web documentation and export decisions.
- [x] Run validation, complete the final review, commit only Task C changes, and
  push to `origin/main`.

## Validation

Completed validation includes `dart format`, workspace `dart analyze`, affected
Flutter analysis, all seven package suites, focused SSE parser tests, the native
Dart IO fixture, the Chrome/CORS Fetch fixture, Dartdoc for all affected public
libraries, compile-tested `example/sse.dart`, Markdown lint, relative-link
checks, affected package dry-runs/archive inspection, dependency and
security/path audits, and `git diff --check`. No performance benchmarks were
run.

## Next Action

Return for maintainer review. Do not begin Task D or any WebSocket, generator,
OpenAPI, Protobuf, GraphQL framework, gRPC, or broader ecosystem work in this
task.

## Blockers

None currently.

## Outcome

Implemented `package:alphax/sse.dart` with `AlphaXSseEvent` and the incremental,
strict UTF-8 `AlphaXSseParser`; added deterministic parser/native/Web coverage,
one-import integration re-exports, compile-tested example code, and the
requested documentation/review. The final review concludes `RC5 SSE READY`.

## References

- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `docs/ALPHAX_RC5_SSE_REVIEW.md`

## History

- 2026-08-30 — Task C approved for implementation by the maintainer request.
- 2026-08-30 — Reserved monotonic task number 50 after inspecting `tasks/`.
- 2026-08-30 — Implemented and validated the parser, native/Web fixtures,
  documentation, and export decisions; ready for maintainer review.
