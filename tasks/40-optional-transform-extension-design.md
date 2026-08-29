# Task 40: Optional AlphaX large-payload transform extension design

Status: [x] Completed

## Goal

Decide whether AlphaX should provide a small, optional package for one-shot
large-payload JSON decoding and caller-supplied isolate transforms, using the
measured Task 37 evidence without changing `alphax` core or implementing the
package in this task.

## Scope and Non-goals

Scope:

- evaluate documentation-only, `alphax_transform`, `alphax_compute`, automatic
  core middleware, and persistent-worker alternatives;
- sketch a deliberately small pure-Dart interface for buffered JSON bytes,
  sendable caller transforms, cancellation/discard behavior, and diagnostics;
- assess `TransferableTypedData`, native Dart/Flutter behavior, Web limitations,
  threshold guidance, package boundaries, binary impact, and risks;
- record a recommendation for maintainer review.

Non-goals:

- no transform package or production source implementation;
- no change to `alphax` public interfaces or response decoding behavior;
- no automatic model mapping, hidden isolate dispatch, persistent worker/pool,
  streaming JSON transform, or general-purpose worker framework;
- no new transport, FFI/shared buffer, benchmark phase, or public performance
  claim;
- no universal payload threshold.

## Owner

Codex; maintainer review is required before any implementation task.

## Dependencies

- Task 37 parsing evidence and
  `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`;
- accepted pure-Dart `alphax` boundary and package philosophy in
  `PROJECT_CONTEXT.md` and `docs/architecture/overview.md`;
- current Dart/Flutter isolate interfaces and their documented Web behavior.

## Assumptions

- the measured 5 MiB/10 MiB main-isolate gaps are device- and schema-specific
  evidence, not universal thresholds;
- one-shot isolation is useful for occasional large transforms, while Task 37
  did not establish a persistent-worker advantage;
- a future helper accepts already-buffered bytes and does not own native
  transport streams or backpressure;
- Web background execution is not promised without a separate implementation
  and experiment;
- `alphax` remains pure Dart and transport-independent.

## Work Items

- [x] Read the Task 37 evidence and current AlphaX package/architecture
      boundaries.
- [x] Review official Dart `Isolate.run`, `TransferableTypedData`, sendability,
      `Isolate.spawn`, and Flutter `compute` behavior.
- [x] Compare documentation-only, optional helper, core middleware, and
      persistent-worker product shapes.
- [x] Define a minimal interface sketch with explicit sendability and
      cancellation/discard semantics.
- [x] Document native Dart/Flutter/Web behavior, threshold guidance, package
      impact, risks, and implementation validation gates.
- [x] Create
      `docs/ALPHAX_TRANSFORM_EXTENSION_DESIGN.md` and stop without implementing
      the extension.

## Validation

- Read-only design inspection completed against Task 37 results and current
  package boundaries.
- Official API references reviewed:
  `Isolate.run`, `TransferableTypedData`, `SendPort.send`, `Isolate.spawn`, and
  Flutter `compute`.
- No production code, public API, transport default, benchmark, or package
  implementation was changed.
- `git diff --check` passed for the tracked Task 38/39 commits; the two Task 40
  files remain intentionally uncommitted for maintainer review.

## Next Action

Maintainer review. If approved, create a separate implementation task for the
optional package and re-run the measured parsing matrix as targeted package
validation; do not implement it as part of Task 40.

## Blockers

None for the design deliverable. Implementation remains approval-gated.

## Outcome

The design recommends a future pure-Dart `alphax_transform` package with one
opt-in one-shot JSON transform operation. It uses `Isolate.run` on native Dart
and Flutter, may use `TransferableTypedData` as an internal optimization where
supported, requires sendable inputs/transforms/results, and treats
post-dispatch cancellation as discard rather than hard worker termination. The
first design rejects core middleware, persistent workers, automatic thresholds,
and a Web background-execution claim.

See `docs/ALPHAX_TRANSFORM_EXTENSION_DESIGN.md` for the interface sketch,
tradeoffs, risks, and implementation validation gate.

## References

- `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`
- `tasks/37-post-1-0-integration-cost-spike.md`
- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- [Dart `Isolate.run`](https://api.dart.dev/dart-isolate/Isolate/run.html)
- [Dart `TransferableTypedData`](https://api.dart.dev/dart-isolate/TransferableTypedData-class.html)
- [Dart `SendPort.send`](https://api.dart.dev/dart-isolate/SendPort/send.html)
- [Dart `Isolate.spawn`](https://api.dart.dev/dart-isolate/Isolate/spawn.html)
- [Flutter `compute`](https://api.flutter.dev/flutter/foundation/compute.html)

## History

- 2026-08-29: Created as the next monotonic task after Task 39, after the
  accepted integration-cost evidence identified large synchronous JSON decode
  as the clearest remaining user-visible opportunity.
- 2026-08-29: Completed the read-only design. Recommended a small optional
  `alphax_transform` package; no implementation was started.
