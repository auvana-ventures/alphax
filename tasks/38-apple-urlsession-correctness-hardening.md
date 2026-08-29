# Task 38: Apple URLSession correctness hardening

Status: [x] Completed

## Goal

Correct Apple URLSession timing-unit reporting and the bounded response
backpressure state machine, then validate the fixes with deterministic native
tests and a focused macOS/iPhone rerun where a signed iPhone is available.
Preserve the accepted URLSession architecture and the production 64 KiB/four
credit default.

## Scope and Non-goals

Scope:

- correct every Apple `TimeInterval` phase/total mapping so `*DurationMs`
  values are milliseconds exactly once;
- add deterministic native regression coverage for timing units, unavailable
  timestamps, invalid intervals, backpressure state transitions, oversized
  callback splitting, completion ordering, cancellation, pause/resume, and
  native-file finalization behavior;
- reproduce and fix the normal 64 KiB/four-credit/256 KiB bounded response
  timeout with a small state-machine correction;
- preserve private benchmark counters, gated and disabled by default;
- validate only the affected Apple/macOS/iOS correctness subset and retain
  raw diagnostic evidence without publishing performance claims;
- decide and document the Apple native-file replacement/partial-file contract
  without introducing a generic transactional filesystem API.

Non-goals:

- no new benchmark phase or restart of the Phase 0 matrix;
- no transport architecture or URLSession replacement;
- no global chunk/window default change or performance optimization of the
  64 KiB/four-credit design;
- no progress suppression/coalescing, isolate/transform package, FFI/shared
  buffers, second engine, native-copy rewrite, or advanced H3/DoH/0-RTT/
  migration control;
- no new public AlphaX API unless a minimal transport-neutral correctness fact
  is unavoidable and separately reviewed;
- no performance ranking or public benchmark claim.

## Owner

Codex; maintainer review is required before follow-up optimization work.

## Dependencies

- completed task 37 and
  `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`;
- accepted ADR 0005, Apple URLSession source, current Apple Dart facade, and
  existing native/platform conformance tests;
- macOS build/runtime availability and a signed physical iPhone if available;
- existing private integration counters and fixture harness, used only for
  focused correctness evidence.

## Assumptions

- task 38 is the next monotonic task number after task 37;
- the pre-existing modification to
  `benchmarks/mobile_gate/ios/Runner.xcodeproj/project.pbxproj` remains user
  work and must not be reverted or reformatted;
- timing values remain nullable when URLSession does not provide a phase;
- ADR 0005 continues to make completion-time metrics authoritative for final
  negotiated protocol and completion metadata;
- the current 64 KiB/four-credit behavior is a correctness invariant for this
  task, not a tuning variable.

## Work Items

- [x] Reserve task 38 and inspect repository context, ADR 0005, Apple source,
      existing tests, previous raw evidence, and file-contract documentation.
- [x] Add a private/native timing conversion seam and deterministic regression
      tests for all Apple phase and total mappings.
- [x] Reproduce the 5 MiB normal-window timeout and instrument private
      suspend/resume/pending-queue state sufficiently to establish the cause.
- [x] Apply the smallest backpressure state-machine correction and cover
      oversized callbacks, slow consumers, pause/resume, cancellation, and
      completion ordering.
- [x] Validate and document native-file finalization, replacement, partial-file,
      cancellation, and failure behavior without claiming atomic replacement.
- [x] Run the focused macOS suite and the signed iPhone subset if available;
      retain raw diagnostics and do not start another benchmark matrix.
- [x] Write
      `docs/ALPHAX_APPLE_URLSESSION_CORRECTNESS_HARDENING.md`, self-review the
      task-owned diff, and record validation/limitations.

## Validation

Planned:

- deterministic native timing/state-machine unit tests;
- affected Dart package tests and shared conformance tests;
- formatting and Dart/Flutter analysis;
- macOS profile/build and focused runtime correctness suite;
- iOS no-code-sign build and signed iPhone runtime subset when available;
- docs/dartdoc/package dry-run checks if public behavior documentation changes;
- `git diff --check` and review that defaults, public APIs, architecture, and
  progress behavior remain unchanged.

Completed commands/results:

- The pre-fix macOS 5 MiB `json_discard` run at 64 KiB × 4 failed with
  `AlphaXTimeoutException` / `NSURLErrorDomain:-1001`; raw JSON and log are
  retained as `task38-before-fix-*` under
  `benchmarks/results/raw/integration-cost/`.
- `bash packages/alphax_native/tool/run_apple_urlsession_correctness_tests.sh`
  passed all deterministic timing, invalid-date, oversized-callback,
  completion, cancellation, slow-consumer, and file-finalization checks. The
  test was first run red against the old double-scaling helper at the 1 ms
  assertion, then green after the fix.
- `dart test` in `packages/alphax`, `flutter test` and `flutter analyze` in
  `packages/alphax_native`, and `flutter analyze` in
  `benchmarks/mobile_gate` passed.
- `flutter build macos --profile --no-pub -t lib/integration_cost_apple.dart`
  and `flutter build ios --profile --no-codesign --no-pub -t
  lib/integration_cost_apple.dart` passed.
- Focused macOS AlphaX runs passed for small request, 5 MiB discard, 5 MiB
  decode, 2 MiB stream, slow consumer, backpressured cancellation, 32 MiB
  native download, and existing-destination replacement. The official
  Cupertino 5 MiB reference also completed.
- The physical iPhone was detected but the focused run stopped before deploy:
  Xcode reported that `Runner` requires a provisioning profile. No iPhone
  correctness result is inferred from macOS.
- `dart pub publish --dry-run` completed package validation with one dirty
  worktree warning for pre-existing/task-37 modified files; no package-content
  or public-API validation error was reported.
- `git diff --check` passed.

## Next Action

Maintainer review of the correctness report. The next separate engineering task
may measure progress-event suppression/coalescing; no optimization work is
started by task 38.

## Blockers

None known. A physical iPhone may remain unavailable; if so, macOS is evidence
only for macOS and the iPhone limitation will be explicit.

## Outcome

Apple URLSession timing conversion now maps native seconds to milliseconds once,
including unavailable/invalid handling. The corrected incremental state machine
keeps the AlphaX pending queue at 256 KiB, avoids repeated native suspend calls,
drains oversized callbacks in order, and delays completion until accepted body
data is drained. The focused macOS 5 MiB and slow-consumer paths complete with
64 KiB × 4; native-file downloads keep payload bytes out of Dart and successful
replacement is verified without claiming atomicity. iPhone runtime validation
is blocked by provisioning. No production default, public API, transport
architecture, progress behavior, or native-copy strategy changed.

See `docs/ALPHAX_APPLE_URLSESSION_CORRECTNESS_HARDENING.md` for the evidence,
limitations, required answers, and exact conclusion.

## References

- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/ALPHAX_POST_1_0_INTEGRATION_COST_RESULTS.md`
- `packages/alphax_native/ios/Classes/AlphaXNativePlugin.swift`
- `packages/alphax_native/lib/src/apple_url_session_transport.dart`
- `packages/alphax_native/test/apple_url_session_protocol_test.dart`
- `packages/alphax_native/README.md`
- `docs/architecture/transport_contract.md`

## History

- 2026-08-29: Created as task 38 after task 37 identified an Apple timing-unit
  defect and a reproducible normal-window large-response timeout. Scope is
  correctness hardening and a focused rerun only; no performance phase or
  architecture change is authorized.
- 2026-08-29: Completed timing conversion correction, incremental backpressure
  state machine, deterministic native tests, file-finalization tests, focused
  macOS reruns, and iPhone provisioning limitation review. Kept 64 KiB × 4 and
  recorded no public performance claim.
