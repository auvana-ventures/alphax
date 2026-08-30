# Task 52 — AlphaX Direct Typed REST Generator

Status: [x] Completed

## Goal

Add the locked rc.5 `alphax_generator` development-time source-generation surface.
Generated clients must call `AlphaXClient` directly while preserving the existing
Retrofit → Dio → `alphax_dio` compatibility path.

## Scope and Non-goals

Scope:

- keep lightweight AlphaX-owned annotations in the pure-Dart `alphax` package;
- add one `alphax_generator` package using maintained Dart source-generation tooling;
- generate direct clients for the common REST methods and request/response mappings;
- support caller-owned model serialization hooks, cancellation, request options,
  multipart/file representations, and honest streaming where the AlphaX contract
  already provides them;
- add compile-tested native, Web, and plain-Dart consumer fixtures;
- update user-facing documentation and record validation evidence.

Non-goals:

- no OpenAPI parsing or template work (Task F);
- no Protobuf implementation (Task G);
- no GraphQL, WebSocket, SSE, Retrofit, Dio, or package:http runtime dependency;
- no model registry, reflection, runtime code generation, or serializer framework;
- no package architecture changes beyond the approved `alphax_generator` boundary;
- no version publication, tag, release, benchmark, or unrelated mobile/signing work.

## Owner

AlphaX maintainers / Codex implementation.

## Dependencies

- `alphax` public request, body, response, file, protocol, timeout, and cancellation
  contracts;
- Dart `build_runner`/`source_gen` generation conventions;
- the approved rc.5 scope lock and final-feature ADR;
- existing `alphax_native` and `alphax_web` entry façades for consumer examples.

## Assumptions

- annotation declarations can remain const metadata in `alphax` without tooling
  dependencies or a dependency cycle;
- one `alphax_generator` package is sufficient for the direct generator seam;
- generated services borrow, and never close, the supplied `AlphaXClient`;
- generated consumers can use `alphax_generator` only as dev-time tooling while
  runtime code depends on `alphax` or a deployment package;
- the existing AlphaX body/file/stream contracts are sufficient for the bounded
  request representations in this task.

## Work Items

- [x] Reserve Task 52 and confirm the approved generator/package boundary.
- [x] Add AlphaX-owned annotation metadata and public annotation library.
- [x] Add the `alphax_generator` package, builder configuration, and generator.
- [x] Implement direct generated-client request construction and response decoding.
- [x] Add diagnostics, runtime/generator tests, and consumer compile fixtures.
- [x] Update root/package/user documentation and generator usage guidance.
- [x] Review the combined Task E diff and run the required validation/audits.
- [x] Complete the review record, commit only Task E-owned changes, push, and verify
  `HEAD == origin/main`.

## Validation

Completed on 2026-08-30:

- `dart format --set-exit-if-changed` for all Task E Dart sources;
- Dart analysis for all affected Dart packages and Flutter analysis for
  `alphax_native`;
- generator diagnostics/generation tests (4), AlphaX core tests (95), and all
  8 workspace package suites;
- native generated-consumer build, analysis, local API fixture, model,
  multipart/file, stream, cancellation, timeout, and concurrency coverage (9
  tests);
- pure-Dart generated-consumer build, analysis, executable compilation, and
  caller-supplied transport test;
- Web generated-consumer build, analysis, test, and JavaScript compilation;
- manual, json_serializable, and Freezed model compatibility fixtures;
- Dartdoc `--validate-links` for all 8 workspace packages: 0 errors, with
  existing README/example cross-package warnings recorded in the final review;
- Markdownlint with repository-standard MD013/MD033/MD060 exclusions and a
  relative Markdown target check;
- affected package dry-runs and archive inspection: `alphax` 66 KB,
  `alphax_generator` 17 KB, `alphax_native` 103 KB, and `alphax_web` 17 KB;
- dependency, generated-seam, security, secret/path, and protected-file audits;
- `git diff --check`;
- no performance benchmarks.

## Next Action

Return for maintainer review. After approval, the maintainer decides whether to
complete or defer bounded optional Task F (OpenAPI template proof), Task G
(Protobuf ergonomics), or Task H (ecosystem compatibility validation). Do not
start any of them automatically from Task E.

## Blockers

None currently.

## Outcome

Implemented and validated the direct typed REST generator. The final review is
`docs/ALPHAX_RC5_TYPED_REST_GENERATOR_REVIEW.md` and concludes
`RC5 TYPED REST GENERATOR READY`. Existing Retrofit → Dio → `alphax_dio`
compatibility remains unchanged. Task E is complete; the worktree also
contains unrelated protected benchmark/release changes that were not staged.

## References

- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- `docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`
- `docs/ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md`
- `docs/decisions/0011-rc5-final-feature-candidate.md`
- `packages/alphax/README.md`
- `packages/alphax_dio/README.md`
- `docs/ALPHAX_RC5_TYPED_REST_GENERATOR_REVIEW.md`
- `examples/typed_rest/README.md`
- `examples/typed_rest_web/README.md`
- `examples/typed_rest_dart/README.md`

## History

- 2026-08-30: Reserved Task 52 after Task 51 consistency verification and maintainer
  approval. Confirmed that Task E is the final committed rc.5 feature task; F/G/H are
  deferred optional decisions and must not be started here.
- 2026-08-30: Implemented AlphaX annotations, request options, typed response helpers,
  the one-package build_runner/source_gen generator, direct generated request/response
  paths, diagnostics, pure-Dart/native/Web consumers, model compatibility fixtures, and
  docs.
- 2026-08-30: Completed formatting, analysis, all 8 package suites, native/Web
  generated-consumer validation, Dartdoc, Markdown/link, dry-run/archive,
  dependency/security/path, and whitespace checks. Review concludes
  `RC5 TYPED REST GENERATOR READY`.
