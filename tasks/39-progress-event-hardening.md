# Task 39: Progress-event suppression and coalescing

Status: [x] Completed

## Goal

Measure and implement the smallest safe reduction in unnecessary AlphaX native/Dart
progress traffic. Preserve body streaming, cancellation, public contracts, protocol
behavior, chunk sizing, and credit-window behavior.

## Scope and Non-goals

Scope:

- audit Android Cronet, Apple URLSession, Dart IO, and Web progress paths;
- make progress interest operation-scoped for native transports;
- suppress native progress event construction and delivery when no observer is
  registered;
- evaluate, but do not assume, a conservative requested-progress coalescing policy;
- add deterministic regression coverage and run the focused progress-sensitive
  integration scenarios.

Non-goals:

- no transport architecture change or replacement of Cronet/URLSession;
- no credit batching, chunk/window tuning, isolate-transform package, FFI/shared
  buffers, or native buffer-copy optimization;
- no public progress configuration API, public benchmark claims, or global mutable
  progress switch;
- no change to the 64 KiB chunk or four-credit defaults.

## Owner

AlphaX maintainers / Codex implementation pass.

## Dependencies

- Task 37 integration-cost harness and raw baseline data.
- Task 38 Apple URLSession correctness-hardening changes and 64 KiB × 4 behavior.
- Existing `alphax` progress callback contracts.

## Assumptions

- Task 38 remains unchanged and is not reopened unless this work exposes a regression.
- Native progress counters remain private instrumentation and count emitted native
  progress events, not internal byte accounting.
- Existing observer semantics are preserved: an upload observer includes a file-body
  progress observer where the current Dart adapter delivers it.
- Focused device runs are available only where the current local Android/macOS
  harnesses and fixtures remain usable; unavailable iPhone provisioning will be
  reported rather than represented as evidence.

## Work Items

- [x] Audit progress generation and observer detection for every supported transport
  and transfer mode.
- [x] Add operation-scoped native progress-interest gating without changing public API.
- [x] Add deterministic tests for suppression, delivery, ordering, cancellation, and
  mixed concurrent progress interest.
- [x] Run bounded before/after progress-sensitive measurements and evaluate bounded
  coalescing candidates.
- [x] Review focused results and choose exactly `SUPPRESS_ONLY`,
  `SUPPRESS_AND_COALESCE`, or `NO_CHANGE`.
- [x] Document behavior, measurements, limitations, and follow-up decisions.
- [x] Run affected formatting, analysis, tests, builds, runtime checks, and diff
  validation.

## Validation

Planned validation scope:

- native Android and Apple unit/standalone tests for progress gating;
- affected `alphax_native` Dart tests and package analysis;
- focused Android/macOS progress-sensitive harness scenarios using existing defaults;
- raw machine-readable result retention under the existing benchmark results area;
- formatting, `git diff --check`, and relevant package/build checks.

## Next Action

Maintainer review. If requested progress coalescing is pursued later, run a separate
provider-side experiment with explicit final-event, cancellation, backpressure, and
frame-tail assertions.

## Blockers

None currently. Physical iPhone execution may be unavailable if the existing signing
and provisioning limitation persists.

## Outcome

Implemented `SUPPRESS_ONLY`. Android and Apple native progress events are gated before
progress-map construction/EventChannel delivery; Dart IO and generic file accounting
avoid unused progress construction without changing the public progress contract.
Focused Android/macOS runs produced zero native progress events in every off arm while
requested arms retained per-read delivery. Coalescing was not implemented because the
bounded trace replay did not establish a user-visible benefit or correctness case.

## References

- `docs/ALPHAX_POST_1_0_PERFORMANCE_AND_CAPABILITY_AUDIT.md`
- `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`
- `docs/ALPHAX_APPLE_URLSESSION_CORRECTNESS_HARDENING.md`
- `docs/architecture/transport_contract.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`

## History

- 2026-08-29: Task 39 reserved after Task 38; implementation started.
- 2026-08-29: Added operation-scoped Android/Apple interest flags, defensive Dart
  observer gates, and generic unknown-length upload accounting.
- 2026-08-29: Ran focused Android/macOS progress-off/on scenarios with 64 KiB × 4;
  retained raw JSON under `benchmarks/results/raw/integration-cost/`.
- 2026-08-29: Selected `SUPPRESS_ONLY`; requested coalescing remains follow-up work.
- 2026-08-29: Validation completed; see
  `docs/ALPHAX_PROGRESS_EVENT_HARDENING.md` for evidence and limitations.
