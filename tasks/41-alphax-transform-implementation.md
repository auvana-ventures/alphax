# Task 41: `alphax_transform` implementation

Status: [x] Completed

## Goal

Implement the approved optional, pure-Dart `alphax_transform` package for
explicit one-shot JSON decoding and caller-supplied isolate transforms. The
package must reduce caller-isolate blocking for profiled large-payload work
without changing AlphaX core semantics, transport behavior, or Web execution
claims.

## Scope and Non-goals

Scope:

- add the independently publishable `packages/alphax_transform` package;
- expose one small `decodeJson` operation accepting already-buffered
  `Uint8List` bytes, a caller transform, optional AlphaX cancellation, and an
  optional diagnostic name;
- use one-shot `Isolate.run` on Dart VM/native Flutter targets;
- use internal `TransferableTypedData` only where it preserves the small API and
  correct ownership behavior;
- fail closed on Web with a package-specific unsupported error;
- test JSON/error/cancellation/sendability contracts and deterministic payload
  correctness;
- update workspace/package documentation and provide implementation evidence.

Non-goals:

- no changes to `alphax` core or `alphax_native` transports;
- no automatic response transformation, middleware, thresholds, streaming JSON,
  persistent workers/pools, model registry, code generation, Flutter dependency,
  FFI/shared buffers, or transport-specific types;
- no Web background execution claim or silent synchronous Web fallback;
- no networking benchmark phase and no public performance claim;
- no package publication, tag, or push as part of this task.

## Owner

Codex; maintainer review is required after implementation validation.

## Dependencies

- Task 40 design and `docs/ALPHAX_TRANSFORM_EXTENSION_DESIGN.md`;
- Task 37 deterministic parsing evidence and
  `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`;
- `alphax` cancellation and error contracts;
- repository workspace/package, documentation, and publication conventions.

## Assumptions

- `Isolate.run` is available on supported native Dart VM and Flutter targets;
- the caller supplies bytes that are already buffered and accepts responsibility
  for the transport read and any separate network cancellation;
- the transform closure and returned value must satisfy Dart isolate
  sendability rules;
- cancellation after dispatch can discard the result but cannot synchronously
  terminate the one-shot worker;
- Web remains explicitly unsupported for background execution in this release;
- Task 40 design files and unrelated pre-existing benchmark/mobile changes are
  preserved and are staged separately from this implementation.

## Work Items

- [x] Inspect package/workspace conventions and reserve monotonic task 41.
- [x] Create the package manifest, public library, native/Web implementation,
      tests, README, changelog, license, and optional supporting example only if
      it adds material value.
- [x] Implement one-shot native decoding with honest cancellation/discard and
      error propagation.
- [x] Implement fail-closed Web behavior and document sendability, buffering,
      memory/copy, and threshold guidance.
- [x] Add deterministic tests and a bounded parsing comparison for synchronous,
      direct-isolate, and package paths where the environment permits.
- [x] Update root workspace metadata, package list, architecture/package map,
      and roadmap without making `alphax` depend on the extension.
- [x] Create `docs/ALPHAX_TRANSFORM_EXTENSION_IMPLEMENTATION.md` with results,
      limitations, and the required conclusion.
- [x] Review task-owned diff, run focused/regression/publication validation,
      and record commands and outcomes here.
- [x] Commit Task 40 design documentation separately from this implementation
      if validation is green, without staging pre-existing user work.

## Validation

Completed validation:

- `dart pub get` registered the package in the workspace without changing
  production dependencies.
- `dart format --set-exit-if-changed lib test tool`, `dart analyze`, and
  `flutter analyze` passed for `alphax_transform`.
- `dart test` and `flutter test` passed for `alphax_transform`; the suite covers
  JSON/UTF-8/transform errors, sendability failure, cancellation races, late
  result/error discard, deterministic 100 KiB/1 MiB/5 MiB/10 MiB payloads, and
  Web unsupported behavior.
- `dart test -p chrome` passed, including browser compilation and fail-closed
  unsupported semantics.
- Existing `alphax`, `alphax_native`, `alphax_web`, `alphax_dio`, and
  `alphax_test` package test suites and scoped analyzers passed.
- `dart doc --validate-links` passed with zero warnings/errors.
- `dart run tool/benchmark_transform.dart` completed a bounded local comparison
  with one warm-up and three measured samples for each deterministic payload;
  results are summarized in the implementation report and raw output was not
  retained.
- A disposable Flutter app importing the package built successfully with
  `flutter build apk --profile`, `flutter build macos --debug`, and
  `flutter build ios --simulator --no-codesign`. No repository app or mobile
  project file was changed; no Android device was available for runtime
  execution.
- `dart pub publish --dry-run` passed with zero warnings and a 13 KB compressed
  archive. `dart pub deps --style=compact` confirmed the only runtime package
  dependency is `alphax`.
- Scoped Markdown checks passed for the implementation report, Task 41,
  architecture overview, and roadmap. Dartdoc validated API links; local
  documentation targets were checked. Existing repository README HTML/line-
  length style is preserved.
- `git diff --check` and the final staged ownership review passed; no known
  pre-existing benchmark/mobile file was staged.

The attempted root-wide `dart analyze` was stopped after it spent over a minute
traversing the retained 3.2 GB benchmark tree without producing a result. It
was superseded by successful scoped analyzers for all six AlphaX packages; no
root-wide source change required the broader check.

Actual commands, skipped checks, and evidence will be appended after the batch
implementation and review.

## Next Action

Maintainer review of the separate Task 40 design and Task 41 implementation
commits. Do not publish the package or begin automatic thresholds, streaming
parsing, persistent workers, or transport optimization in this task.

## Blockers

None currently.

## Outcome

Implemented and validated. The optional package is ready for maintainer review
as an RC candidate; publication remains intentionally unperformed.

## References

- `docs/ALPHAX_TRANSFORM_EXTENSION_DESIGN.md`
- `tasks/40-optional-transform-extension-design.md`
- `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`
- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- [Dart `Isolate.run`](https://api.dart.dev/dart-isolate/Isolate/run.html)
- [Dart `TransferableTypedData`](https://api.dart.dev/dart-isolate/TransferableTypedData-class.html)
- [Dart `SendPort.send`](https://api.dart.dev/dart-isolate/SendPort/send.html)
- [Flutter `compute`](https://api.flutter.dev/flutter/foundation/compute.html)

## History

- 2026-08-29: Reserved task 41 after approval of the Task 40 design.
- 2026-08-29: Implemented the one-shot native isolate package, fail-closed Web
  boundary, cancellation/discard state machine, tests, benchmark tool, package
  metadata, and documentation.
- 2026-08-29: Completed scoped package/regression analysis and tests, browser
  compilation, Dartdoc, deterministic parsing comparison, disposable Flutter
  Android/macOS/iOS builds, and package dry-run validation.
