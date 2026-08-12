# Phase 0 Comparable Benchmark Suite

Status: [x] Completed

## Goal

Build the first fair, reproducible macOS benchmark suite comparing `dart:io`
`HttpClient`, libcurl through the existing C ABI/Dart FFI bridge, and Rust
reqwest/hyper through its C ABI/Dart FFI bridge. Establish correctness before
collecting performance data and stop after the first complete comparable dataset.

## Scope and Non-goals

Scope:

- Define a benchmark-only transport abstraction separate from the public `alphax`
  package contracts.
- Complete the deterministic local server with health, request, stream, upload,
  download, delay, status, header, and redirect behavior.
- Add correctness checks for equivalent status, headers, bytes, streaming, uploads,
  downloads, timeout, cancellation, and supported redirects.
- Add local benchmark profiles, warmup/measurement methodology, raw samples, and
  reproducible summaries for the initial small-request, concurrency, streaming,
  upload, download, and cancellation scenarios.
- Record reliable metadata, memory observations, FFI copy/ownership notes, and
  release binary-size measurements where available.
- Push logical working milestones without selecting a production transport.

Non-goals:

- Changing or expanding the production `alphax` API.
- Implementing cache, offline, circuit breaker, telemetry, DevTools, full Dio,
  authentication, GraphQL, REST generation, Cronet, URLSession, or Phase 1.
- Declaring a production transport or accepting ADR-0004 before evidence is
  complete and reviewed.
- Treating localhost results as mobile-network performance.

## Owner

Codex, with maintainer review required before transport selection or Phase 1.

## Dependencies

- Bootstrap commit `24e5ec7` on `origin/main`.
- Dart SDK `>=3.8.0 <4.0.0`.
- macOS libcurl development library and C compiler.
- Rust toolchain and Cargo dependencies.
- Local deterministic server runtime.

## Assumptions

- The first complete comparable dataset targets macOS and the local profile.
- Benchmark adapters may use lower-level candidate-specific APIs but must expose
  equivalent operations through the benchmark contract.
- HTTP/1.1 is the first protocol profile; HTTP/2 and HTTP/3 are reported only when
  configured fairly and supported by the candidate.
- Raw samples are small enough to commit when useful; disposable large artifacts
  remain ignored or local.
- Candidate failures exclude that candidate from comparative claims until fixed.

## Work Items

- [x] Create benchmark task record and define the benchmark-only contract.
- [x] Finalize deterministic server endpoints, health, and streaming surface.
- [x] Implement equivalent Dart, libcurl/FFI, and Rust/FFI benchmark adapters.
- [x] Add correctness suite covering request, stream, transfer, timeout, cancel,
  and redirect behavior.
- [x] Add warmup, measured iterations, percentile statistics, raw samples, and
  human-readable summaries.
- [x] Add initial local scenarios for small requests, concurrency, stream, upload,
  download, and cancellation.
- [x] Add metadata, memory/copying notes, and binary-size measurement tooling.
- [x] Run the first complete comparable macOS dataset and review it for fairness.
- [x] Push logical working benchmark commits and stop for maintainer review.

## Validation

Passed on 2026-08-12:

- `dart format --set-exit-if-changed` across packages, prototypes, and benchmark
  packages.
- Benchmark server/runner tests and all package tests.
- All four package `dart pub publish --dry-run` validations with zero warnings.
- Dart analysis for all three prototypes and the benchmark server/runner.
- `make -C prototypes/libcurl_ffi test`, libcurl FFI tests, and macOS smoke test.
- Rust `cargo test`, release build, Rust FFI tests, and the shared-runtime
  concurrency test.
- Dart IO prototype tests.
- Full macOS local benchmark: 3 warmups, 10 measured iterations, 630 raw samples,
  all correctness checks passed, no performance errors.
- `benchmarks/scripts/measure-binary-size.sh` with a tracked raw result.
- `git diff --check` before each pushed logical commit and final result commit.

## Next Action

Review the pushed dataset with the maintainer. Do not proceed to the primary
transport ADR or Phase 1 until that review is complete.

## Blockers

None currently.

## Outcome

Completed and pushed the first comparable macOS localhost dataset. All candidates
passed 10/10 correctness checks, and all 21 scenarios produced 10 measured samples
per candidate (630 raw samples total) with no performance errors. Every cancellation
scenario recorded `cancelled` and `resources_released: true` for all candidates.

The dataset includes small cold/warm requests, 10/50/100/250 concurrency,
10 MB/100 MB direct-file downloads and uploads, streaming, slow-consumer streaming,
separate network/UTF-8/JSON timings, and waiting/streaming/download/upload
cancellation. The binary-size result records a 6,422,048-byte Dart AOT baseline,
36,752-byte stripped libcurl candidate artifact, and 3,706,256-byte stripped Rust
candidate artifact under the documented measurement method. These are candidate
artifact observations, not a production package-size claim.

CPU utilization, Dart heap peak, native allocation peak, numeric connection-reuse
counts, protocol negotiation parity, and network simulation were unavailable and
are explicitly not inferred. The local results are not representative of mobile
network performance. No production transport was selected, no C++ engine was
introduced, and ADR-0004 remains unaccepted pending review and additional evidence.

## References

- `docs/prd/08_BENCHMARKS.md`
- `docs/prd/12_PHASE_0_IMPLEMENTATION_SPEC.md`, sections 13–19 and 24–30
- `docs/architecture/ffi_boundary.md`
- `docs/architecture/memory_model.md`
- `benchmarks/results/raw/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.json`
- `benchmarks/results/summaries/macos-local-ee25c2efd362c78f32e8f1ac98773db86aa5b63f.md`
- `benchmarks/results/raw/binary-size-local.json`

## History

- 2026-08-12: Created after bootstrap commit and push. Production transport remains
  unselected.
- 2026-08-12: Added and validated the Dart IO adapter, including buffered requests,
  streaming events, cancellation, and the shared benchmark entry point.
- 2026-08-12: Added and validated the libcurl C ABI/FFI adapter for buffered and
  streaming requests, direct file transfers, timeout, and cancellation.
- 2026-08-12: Added and validated the Rust reqwest/hyper C ABI/FFI adapter for
  buffered and streaming requests, direct file transfers, timeout, and cancellation.
  No C++ engine or production transport has been selected.
- 2026-08-12: Added the correctness matrix, statistical runner, deterministic local
  scenarios, metadata capture, process/memory observations, binary-size tooling,
  and raw/summary output generation. Candidate runs are isolated with fresh local
  server processes to avoid cross-candidate heap/socket/runtime contamination.
- 2026-08-12: Fixed Rust reqwest shared-client lifecycle by keeping its Tokio runtime
  alive for the lifetime of the FFI client; the 250-concurrency smoke profile now
  completes in isolation.
- 2026-08-12: Completed the 3-warmup/10-measured macOS localhost profile, reviewed
  all 630 raw samples for scenario completeness and metadata hygiene, recorded
  binary-size measurements, and pushed the logical benchmark commits. Stopped for
  maintainer review; no production transport or C++ engine was selected.
