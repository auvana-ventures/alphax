# Phase 0 Comparable Benchmark Suite

Status: [*] In Progress

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
- [ ] Run the first complete comparable macOS dataset and review it for fairness.
- [ ] Push logical working benchmark commits and stop for maintainer review.

## Validation

Planned commands:

- `dart format --set-exit-if-changed .`
- `dart analyze`
- `tooling/scripts/test_packages.sh`
- `tooling/scripts/analyze_prototypes.sh`
- `make -C prototypes/libcurl_ffi test`
- `cargo test --manifest-path prototypes/rust_http/Cargo.toml`
- Deterministic server correctness tests and candidate adapter tests.
- Reproducible local benchmark runner with raw and summary output.
- `git diff --check` for each logical commit.

## Next Action

Run the final macOS local profile with the current release native libraries, review
raw and summarized output for completeness, then perform the consolidated repository
validation before the next logical commit.

## Blockers

None currently.

## Outcome

Pending benchmark implementation and first comparable macOS dataset.

## References

- `docs/prd/08_BENCHMARKS.md`
- `docs/prd/12_PHASE_0_IMPLEMENTATION_SPEC.md`, sections 13–19 and 24–30
- `docs/architecture/ffi_boundary.md`
- `docs/architecture/memory_model.md`

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
