# Phase 0 final transport decision experiment

Status: [x] Completed

## Goal

Resolve the two remaining Phase 0 decision blockers with one controlled Linux
experiment: reproducible TLS/HTTP/2 measurements under local, good, typical
mobile, and poor network profiles, plus realistic cross-platform native artifact
accounting. Produce `benchmarks/results/summaries/phase0-final-transport-decision.md`
with exactly one primary transport recommendation. Do not create ADR 0004,
modify AlphaX production architecture, introduce C++, or begin Phase 1.

## Scope and Non-goals

Scope:

- Run the existing small decision-sensitive scenario set on a Linux Docker
  topology with symmetric endpoint `tc`/`netem` shaping.
- Verify TLS certificate validation and ALPN for the HTTP/2 fixture; exclude
  any fallback from HTTP/2 results.
- Retain raw machine-readable results and resource/connection/backpressure
  diagnostics.
- Build practical Linux native artifacts and document measured macOS artifacts
  plus defensible Android/iOS packaging estimates or unavailable build gates.
- Write the final Phase 0 recommendation report without accepting ADR 0004.

Non-goals:

- No new benchmark scenarios or broad matrix expansion.
- No production Android/iOS transport implementation.
- No HTTP/3 implementation, hybrid transport implementation, API restructuring,
  cache/resilience/observability features, or package publication.
- No deletion or rewriting of Round 1/2/3/4 datasets or reports.

## Owner

Codex, with maintainer review required before ADR 0004 or Phase 1.

## Dependencies

- Round 4 pushed at `4272aa0`.
- Existing deterministic Dart HTTP/1.1 server, Hypercorn/h2 fixture, TLS CA
  generator, benchmark runner, and native prototypes.
- Docker Desktop Linux environment with network administration capability and
  enough resources for native Linux builds.

## Assumptions

- The Docker Linux VM is a controlled Linux environment, but its host CPU and
  virtualized timing are recorded and not generalized to mobile hardware.
- Symmetric endpoint shaping uses 15/50/150 ms one-way delay to approximate
  30/100/300 ms RTT, with the requested bandwidth and loss profiles.
- Dart IO is measured over verified TLS HTTP/1.1 because the current prototype
  does not negotiate HTTP/2; native HTTP/2 results include only libcurl and Rust
  when server-observed protocol is `2`.
- The 64 KiB × 4 native bounded-stream configuration remains unchanged.

## Work Items

- [x] Review and push Round 4 as a historical investigation.
- [x] Add a reproducible Linux client/server Docker topology and symmetric
  `tc`/`netem` profile application/reset path.
- [x] Run the targeted TLS/HTTP/2 decision scenarios for all profiles; record
  the Rust poor-profile H2 correctness limitation and exclude incomplete
  performance claims.
- [x] Measure Linux native artifacts and complete cross-platform accounting;
  Android, iOS, and Linux x64 remain explicitly unbuilt.
- [x] Write the final decision report and exactly one recommendation.
- [x] Run final validation, update this task, and stop without ADR 0004 or
  Phase 1.

## Validation

Validation:

- Docker image builds and Linux environment metadata capture.
- TLS CA verification and explicit ALPN `h2` checks.
- Raw-result correctness, protocol, profile, connection, CPU/RSS, and bounded
  backpressure provenance checks.
- Dart format/analyze/tests, native C/Rust builds/tests, package dry-run checks,
  fixture syntax, and `git diff --check`.
- Secret, credential, local-path, generated-binary, and network-cleanup review.

Completed evidence:

- 33 final raw result files, 3,934 samples, and 0 included correctness/hash/
  protocol integrity failures.
- Linux arm64 release artifact accounting and existing macOS arm64 accounting.
- Final report at
  `benchmarks/results/summaries/phase0-final-transport-decision.md`.

Completed commands and outcomes:

- `dart format --set-exit-if-changed .` — passed, 0 files changed.
- `tooling/scripts/analyze_dart_packages.sh` — passed for all packages and
  benchmark Dart packages.
- `tooling/scripts/test_packages.sh` — passed for all public packages.
- `tooling/scripts/validate_packages.sh` — passed for all four packages using
  `dart pub publish --dry-run`; nothing was published.
- `tooling/scripts/analyze_prototypes.sh` — passed for all three prototypes.
- `tooling/scripts/test_benchmark_contract.sh` and
  `tooling/scripts/test_benchmark_harness.sh` — passed.
- `make -C prototypes/libcurl_ffi clean && make -C prototypes/libcurl_ffi
  test` — passed libcurl C smoke test.
- Rust `cargo fmt --check`, `cargo test`, and release build — passed.
- libcurl and Rust Dart FFI tests with built libraries — passed, all tests
  executed rather than skipped.
- Final raw JSON parse, correctness/hash/protocol checks, shell syntax,
  `git diff --check`, secret/path scan, and generated-output ignore checks —
  passed.

Not run by design: Android/iOS/Linux-x64 production artifact builds, HTTP/3,
ADR 0004, package publication, and Phase 1 work.

## Next Action

Review the pushed evidence and recommendation. Do not create ADR 0004 or begin
Phase 1 without explicit maintainer approval.

## Blockers

None currently. If Docker networking, Linux toolchains, or a target artifact
cannot be built, record the exact failure and use a clearly labeled estimate.

## Outcome

Completed. The final evidence recommendation is Dart IO; this does not accept
ADR 0004 or change the production architecture. Commits:

- `f575ad8` — final Phase 0 harness corrections and retained Linux evidence.
- `f49db13` — final transport decision report and task closure.

## References

- `AGENTS.md`
- `docs/benchmarks.md`
- `docs/architecture/ffi_boundary.md`
- `docs/architecture/memory_model.md`
- `benchmarks/results/summaries/phase0-round4-transport-decision-gate.md`
- `benchmarks/scripts/network-profile-linux.sh`
- `benchmarks/server/http2/README.md`
- `tasks/05-phase-0-round-4-transport-decision-gate.md`

## History

- 2026-08-13: Created after Round 4 commit `4272aa0` was validated and pushed.
- 2026-08-14: Completed the targeted Linux TLS/HTTP/2 and artifact experiment;
  recorded the libcurl multiplexing correction, deterministic netem seeds, the
  Rust poor-profile H2 correctness limitation, and the final recommendation
  report. Final validation passed; commits `f575ad8` and `f49db13` record the
  benchmark evidence and report.
