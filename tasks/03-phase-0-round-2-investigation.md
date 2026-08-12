# Phase 0 Round 2 Measurement Investigation

Status: [x] Completed

## Goal

Explain the suspicious libcurl upload, concurrency, and slow-consumer results;
confirm timing parity and event-loop behavior; add reliable macOS process-resource,
connection-reuse, lifecycle, and variance evidence; and publish a retained Round 2
investigation report without selecting a production transport or entering Phase 1.

## Scope and Non-goals

Scope:

- Instrument the libcurl upload lifecycle and event-loop waits with monotonic timestamps.
- Instrument the deterministic server for upload completion and connection reuse.
- Make upload timing boundaries explicit and equivalent across all candidates.
- Verify upload byte counts and deterministic content hashes.
- Measure concurrency, backpressure, process CPU, and process memory on macOS.
- Normalize deployable-artifact size accounting and document system dependencies.
- Increase key scenario repetitions to at least 30 measured samples after warmup.
- Add variance-aware scenario classifications and retain before/after raw results.
- Write `benchmarks/results/summaries/macos-local-round2-investigation.md`.

Non-goals:

- No production transport selection or ADR-0004 acceptance.
- No Phase 1 work, HTTP/2 or HTTP/3 expansion, or public API expansion.
- No arbitrary event-loop tuning or semantic changes that make candidates incomparable.
- No deletion or rewriting of the original macOS dataset.

## Owner

Codex, with maintainer review required before any transport decision.

## Dependencies

- Existing Phase 0 benchmark harness and retained macOS dataset.
- macOS monotonic/process resource APIs available to the Dart and C prototypes.
- Local deterministic benchmark server and release native libraries.

## Assumptions

- The current approximately one-second libcurl upload cost may be an HTTP request
  handshake or event-loop boundary issue and must be evidenced before changing it.
- Process-level CPU and resident/peak memory are acceptable when component-level
  allocation metrics are not reliable.
- The current local profile remains HTTP/1.1-compatible and localhost-only.

## Work Items

- [x] Inspect the existing harness, candidate implementations, and anomalous dataset.
- [x] Add lifecycle, server, timing-boundary, connection, and backpressure instrumentation.
- [x] Identify and correctness-preservingly fix the libcurl upload/event-loop cause.
- [x] Add process CPU/memory and normalized binary-size measurements.
- [x] Run affected before/after scenarios and key scenarios with at least 30 samples.
- [x] Generate the Round 2 investigation report and review remaining uncertainties.
- [x] Validate and stop for maintainer review without committing or pushing.

## Validation

Completed:

- `dart format --set-exit-if-changed .` — passed.
- `tooling/scripts/analyze_dart_packages.sh` and
  `tooling/scripts/analyze_prototypes.sh` — passed.
- `tooling/scripts/test_packages.sh`,
  `tooling/scripts/test_benchmark_contract.sh`, and
  `tooling/scripts/test_benchmark_harness.sh` — passed.
- `tooling/scripts/validate_packages.sh` — all four package publish dry-runs
  passed with zero warnings; nothing was published.
- Native libcurl Dart tests, `make test`, Rust Dart tests, `cargo test`, and
  `cargo build --release` — passed.
- Selected macOS profile — 630 samples, 3/3 candidates passed 10/10
  correctness checks, and no performance errors.
- `benchmarks/scripts/measure-binary-size.sh` — passed with stripped artifact
  and dependency accounting.
- `git diff --check` and generated-result secret/local-path scan — passed.

Skipped or limited:

- No clean commit-only reproduction was run because commit/push was not
  requested and the working tree remains intentionally dirty.
- No Linux native build was run locally; CI remains authoritative for the
  Linux matrix.
- No HTTP/2, HTTP/3, mobile-network simulation, or Phase 1 work was started.

## Next Action

Wait for maintainer review. Do not select a production transport, accept ADR-0004,
or begin Phase 1 from this task.

## Blockers

None currently.

## Outcome

Round 2 evidence is retained without selecting a production transport. The
original macOS dataset remains unchanged. The upload anomaly was explained as the
libcurl `Expect: 100-continue` wait, the prototype fix was validated by exact
counts and hashes, event-loop and lifecycle diagnostics were added, key scenarios
were repeated with 30 samples after warmup, process CPU/RSS and artifact
dependencies were recorded, and the investigation report was written. Connection
reuse and FFI backpressure retain the uncertainties documented in the report.

## References

- `tasks/01-phase-0-benchmark-suite.md`
- `benchmarks/results/raw/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.json`
- `benchmarks/results/summaries/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.md`
- `docs/benchmarks.md`
- `docs/architecture/ffi_boundary.md`
- `docs/architecture/memory_model.md`
- `benchmarks/results/summaries/macos-local-round2-investigation.md`

## History

- 2026-08-12: Created after review of the first macOS dataset. Libcurl upload
  measurements are unverified pending lifecycle instrumentation; Phase 0 remains active.
- 2026-08-12: Completed the Round 2 investigation. Retained the original dataset,
  explained and corrected the libcurl upload delay, recorded macOS resource and
  artifact evidence, and stopped for maintainer review without commit, push, or
  transport selection.
- 2026-08-12: Completed the consolidated validation pass, including package
  dry-run publication checks, native smoke/tests/builds, binary-size measurement,
  formatting, analysis, and repository hygiene checks.
