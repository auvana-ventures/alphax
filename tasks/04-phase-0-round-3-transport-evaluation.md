# Phase 0 Round 3 Transport Evaluation

Status: [x] Completed

## Goal

Make the libcurl and Rust native prototypes representative enough for
decision-useful streaming, concurrency, memory, file-transfer, connection, and
protocol comparisons while preserving AlphaX transport independence. Produce a
macOS Round 3 evaluation dataset and report without selecting a production
transport or entering Phase 1.

## Scope and Non-goals

Scope:

- Design and implement bounded native streaming with an explicit FFI
  credit/acknowledgment boundary for libcurl and Rust.
- Measure chunk sizing, queue bounds, FFI notification frequency, pause/resume,
  cancellation, process CPU, RSS, and native resource release.
- Validate connection reuse, pooling limits, connection establishment, and
  shutdown behavior for all candidates where the platform exposes evidence.
- Add HTTP/2 and reproducible network-profile support only where negotiation and
  fairness can be verified.
- Separate Dart-streamed file transfers from direct native-to-file transfers and
  retain deterministic byte-count/hash correctness checks.
- Add Nitro HTTP and Dio only as versioned external references where an exact,
  fair harness comparison is practical; otherwise document the limitation.
- Record implementation complexity, dependency, build, CI, and cross-platform
  implications and write
  `benchmarks/results/summaries/macos-round3-transport-evaluation.md`.

Non-goals:

- No production transport selection, primary-transport ADR acceptance, or Phase 1.
- No C++ engine; native boundaries remain C ABI plus Dart FFI.
- No public `alphax` API exposure of libcurl, reqwest, hyper, or Rust types.
- No HTTP/3 unless the required Round 3 evidence is complete early and the
  experiment does not delay the decision dataset.
- No cache, offline queue, circuit breaker, observability integrations,
  authentication framework, generators, production Cronet, or production
  URLSession.
- No deletion, rewriting, or replacement of retained Round 1 or Round 2 raw
  results.

## Owner

Codex, with maintainer review required before any transport decision.

## Dependencies

- Pushed Round 2 baseline at commits `2215e65` and `be95b6b`.
- Existing benchmark contract, deterministic server, native prototypes, and
  macOS measurement tooling.
- Available macOS HTTP/2 and network-shaping facilities; unsupported features
  must be reported rather than silently emulated or mislabeled.

## Assumptions

- A bounded credit/ack model is the benchmark prototype contract; it is not a
  production AlphaX API decision.
- The initial experimental flow window and chunk size are configuration values
  for reproducibility, not a selected production default.
- Process-level CPU and RSS remain the authoritative resource measurements when
  component-level ownership cannot be measured reliably.
- HTTP/2 results are valid only when protocol negotiation is explicitly
  observed for every participating candidate.
- Local and impaired-network profiles are not representative mobile-network
  claims unless the impairment mechanism is documented and reproducible.

## Work Items

- [x] Inspect Round 2 architecture, retained results, repository instructions,
  and native event-loop boundaries.
- [x] Create and validate the bounded FFI flow-control design for both native
  candidates.
- [x] Implement bounded libcurl streaming, cancellation, and diagnostics.
- [x] Implement bounded Rust streaming, cancellation, and diagnostics.
- [x] Add chunk/batch experiments, explicit file-transfer paths, connection
  observations, and resource reporting.
- [x] Add verified HTTP/2 and network-profile support where fair and available;
  record HTTP/2 and network shaping as unavailable/not comparable where the
  fairness prerequisites are absent.
- [x] Evaluate Nitro/Dio references or document why exact integration is not
  practical.
- [x] Run the Round 3 macOS dataset, retain raw results, and write the report.
- [x] Review the combined diff and run consolidated validation; stop for review
  without selecting a production transport or starting Phase 1.

## Validation

Completed:

- `dart format` and `dart analyze` for the affected benchmark/server/native
  packages; benchmark and server Dart tests passed.
- Native libcurl `make test` passed; Rust `cargo fmt -- --check`, `cargo test`,
  `cargo check`, and release build passed.
- libcurl and Rust FFI Dart tests passed, including bounded streaming,
  cancellation, hashes/counts, and resource-release probes.
- Corrected 30-sample batching matrix at 16/32/64/128/256 KiB, 30-sample key
  macOS dataset, dedicated connection run, paused-cancellation run, and Dio
  reference run were retained as raw JSON with generated summaries.
- Release artifact accounting passed through
  `benchmarks/scripts/measure-binary-size.sh`.
- `bash -n` and profile descriptions passed for
  `benchmarks/scripts/network-profile.sh`; shaping was not applied because
  administrator packet-filter access was unavailable.
- Final consolidated validation passed: `dart format --set-exit-if-changed .`,
  package analysis/tests/publication dry-runs, prototype analysis, benchmark
  contract/harness checks, libcurl native/FFI tests, and Rust format/tests/
  check/release build. No pub.dev publish was performed.

## Next Action

Maintainer review of the Round 3 report and unresolved evidence gate. Do not
select a production transport or begin Phase 1 automatically.

## Blockers

None currently. Unsupported HTTP/2, network shaping, or external-reference
capabilities will be recorded as limitations rather than treated as successful
measurements.

## Outcome

Round 3 local evidence is complete for the available HTTP/1.1 profile. Both
native candidates have bounded credit/ack streaming, corrected equivalent
batching semantics, deterministic transfer hashes, connection observations,
process CPU/RSS diagnostics, paused cancellation coverage, release artifact
accounting, and a dedicated evaluation report. HTTP/2 and impaired network
profiles remain explicitly unmeasured; libcurl's current connection-pool
architecture remains a material limitation. No production transport was
selected.

## References

- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/ffi_boundary.md`
- `docs/architecture/memory_model.md`
- `prd/03_NATIVE_TRANSPORT.md`
- `prd/05_STREAMING_PERFORMANCE.md`
- `prd/08_BENCHMARKS.md`
- `prd/12_PHASE_0_IMPLEMENTATION_SPEC.md`
- `tasks/03-phase-0-round-2-investigation.md`
- `benchmarks/results/summaries/macos-local-round2-investigation.md`

## History

- 2026-08-12: Created after the Round 2 commits were pushed. Round 3 is
  explicitly limited to Phase 0 transport research; no production transport,
  C++ engine, or Phase 1 work is authorized.
- 2026-08-13: Completed the bounded-flow, corrected batching, connection,
  transfer, resource, cancellation, external-reference, and artifact evidence
  for the available macOS local profile. Recorded HTTP/2/network limitations and
  stopped for maintainer review without selecting a transport.
- 2026-08-13: Final hygiene review and consolidated validation passed; Round 3
  remains uncommitted pending maintainer review.
