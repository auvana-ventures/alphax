# Phase 0 Round 4 Transport Decision Gate

Status: [x] Completed

## Goal

Complete the final planned Phase 0 architecture-validation round by making the
libcurl prototype connection-reuse capable, preserving bounded FFI streaming,
and collecting the fairest available TLS, protocol, network, resource,
file-transfer, binary-size, and engineering-cost evidence. Do not select a
production transport, modify AlphaX production architecture, introduce C++, or
begin Phase 1 without explicit approval.

## Scope and Non-goals

Scope:

- Replace the libcurl per-request multi-handle worker model with one persistent
  client-owned multi handle and bounded worker lifecycle.
- Validate sequential reuse, concurrent connection counts, cancellation,
  shutdown, and bounded streaming after the refactor.
- Add deterministic local TLS infrastructure with explicit protocol reporting;
  run HTTP/2 only when every participating candidate negotiates it explicitly.
- Add reproducible network-profile support, using macOS shaping where permitted
  and documenting an exact Linux `tc`/`netem` path when macOS privileges block
  automation.
- Improve process-level CPU/RSS and direct native-file measurements, binary-size
  accounting, and the engineering-cost comparison.
- Write `benchmarks/results/summaries/phase0-round4-transport-decision-gate.md`
  and retain all Round 1, Round 2, and Round 3 datasets and reports.

Non-goals:

- No production transport selection or acceptance of ADR 0004.
- No Phase 1 work, public API expansion, cache/resilience/observability
  features, production Cronet/URLSession, or HTTP/3 implementation.
- No C++ engine or Rust-plus-C++ boundary.
- No disabling TLS certificate verification merely to make a benchmark pass.
- No synthetic overall performance score or unverified mobile-network claim.

## Owner

Codex, with maintainer review required before any transport decision.

## Dependencies

- Round 3 pushed at `65af0a7`, `e045d26`, and `3a14160`.
- Existing benchmark contract, deterministic server, native FFI prototypes,
  bounded credit/ack flow, and macOS measurement tooling.
- OpenSSL/certificate and packet-shaping tools available on the host; any
  unavailable privilege or protocol capability must be recorded explicitly.

## Assumptions

- The benchmark-only 64 KiB × 4 credit window remains the baseline and is not a
  production default.
- A local TLS/HTTP/2 result is comparable only if negotiated protocol metadata
  is verified for every candidate in that run.
- Process-level RSS is authoritative when component allocation attribution is
  unavailable; cumulative high-water values are not presented as per-scenario
  peaks.
- Cross-platform native artifact builds may be partial when toolchains are not
  installed, but the report must distinguish measured artifacts from estimates
  and disclose system-provided dependencies.

## Work Items

- [x] Review Round 3 commits, preserve historical results, and establish the
  Round 4 task record.
- [x] Implement a persistent libcurl multi-handle worker with cancellation,
  wakeup, bounded streaming, concurrent easy handles, and deterministic close.
- [x] Add connection-reuse acceptance tests and rerun the local HTTP/1.1
  decision-sensitive scenarios.
- [x] Add deterministic TLS/test-CA server support and explicit protocol
  negotiation diagnostics; verify HTTP/1.1 TLS and add a separate Docker h2
  fixture. Native HTTP/2 is verified; Dart is explicitly unsupported/not-tested
  because the current client negotiates HTTP/1.1.
- [x] Add or document reproducible local/good/typical/poor network shaping and
  run profiles when the environment permits safe apply/reset. The macOS host
  has no usable shaping toolchain/privilege in this run; Linux `tc`/`netem` is
  documented and scripted.
- [x] Improve process RSS/CPU and direct-file evidence; measure feasible native
  artifacts for macOS and document unavailable Linux/Android/iOS targets.
- [x] Write the Round 4 report, decision matrix, and smallest remaining
  experiment; the result is `INSUFFICIENT EVIDENCE`.
- [x] Run consolidated validation, review the task-owned diff, and stop without
  Phase 1 or production architecture changes.

## Validation

Completed:

- `dart pub get` and `dart format --set-exit-if-changed .` passed.
- `tooling/scripts/analyze_dart_packages.sh` passed for all Dart packages,
  benchmark packages, and prototypes.
- `tooling/scripts/test_packages.sh` passed for all four public packages.
- `tooling/scripts/validate_packages.sh` passed for `alphax`,
  `alphax_native`, `alphax_dio`, and `alphax_test`; this was dry-run metadata
  validation only and nothing was published to pub.dev.
- `tooling/scripts/test_benchmark_contract.sh` and
  `tooling/scripts/test_benchmark_harness.sh` passed.
- `make -C prototypes/libcurl_ffi clean && make -C prototypes/libcurl_ffi test`
  passed; the C smoke test reported libcurl 8.7.1 with SecureTransport and
  nghttp2.
- Rust `cargo fmt --check`, `cargo test`, and release build passed.
- The libcurl Dart FFI suite passed all 6 tests with the built macOS library;
  the Rust Dart FFI suite passed all 7 tests.
- TLS/network shell syntax checks, in-memory Python fixture syntax checks, and
  the HTTP/2 Docker fixture build passed. Earlier Round 4 fixture smoke checks
  verified the trusted test certificate, ALPN `h2`, and an HTTP/2 response.
- `git diff --check` passed. The repository hygiene scan found no credentials,
  private keys, host-specific absolute paths, or result-file secrets. Python
  cache output is ignored by `.gitignore` and was removed after syntax checks.
- The macOS host did not provide a safe reproducible `tc`/`netem` run, so no
  impaired-network measurements were claimed. No direct root-level benchmark
  test invocation was used as evidence because those packages require their
  package-local configuration; the repository tooling scripts were used and
  passed instead.

## Next Action

Wait for maintainer review. If approved, run only the specifically identified
controlled Linux TLS/HTTP/2 plus `tc`/`netem` experiment and complete the
cross-platform artifact gate before deciding whether ADR 0004 can be created.

## Blockers

None currently. Host packet-filter privileges, TLS/HTTP/2 server capability, and
cross-platform toolchains are environment gates to be reported if unavailable.

## Outcome

Round 4 is complete as a Phase 0 decision gate and reports `INSUFFICIENT
EVIDENCE`. The persistent libcurl architecture, sequential connection reuse,
bounded native streaming, TLS verification, native HTTP/2 fixture, process-level
CPU/RSS sampling, direct-file observations, and macOS binary accounting are
implemented and documented. No production transport, hybrid architecture, ADR
0004, or Phase 1 work was started. Historical Round 1/2/3 datasets remain
unchanged.

The remaining evidence is narrowly defined: a controlled Linux shaped-network
run with explicit HTTP/2 negotiation for all candidates, plus equivalent release
artifact accounting for the priority platforms.

## References

- `PROJECT_CONTEXT.md`
- `AGENTS.md`
- `docs/architecture/overview.md`
- `docs/architecture/ffi_boundary.md`
- `docs/architecture/memory_model.md`
- `docs/benchmarks.md`
- `docs/decisions/0002-transport-benchmark-first.md`
- `docs/decisions/0003-public-api-transport-independence.md`
- `prd/03_NATIVE_TRANSPORT.md`
- `prd/05_STREAMING_PERFORMANCE.md`
- `prd/08_BENCHMARKS.md`
- `prd/12_PHASE_0_IMPLEMENTATION_SPEC.md`
- `tasks/04-phase-0-round-3-transport-evaluation.md`
- `benchmarks/results/summaries/macos-round3-transport-evaluation.md`
- `benchmarks/results/summaries/phase0-round4-transport-decision-gate.md`
- `benchmarks/scripts/create-local-tls.sh`
- `benchmarks/scripts/network-profile-linux.sh`

## History

- 2026-08-13: Created after Round 3 was validated, logically committed, and
  pushed. Round 4 remains Phase 0 research only.
- 2026-08-13: Completed the persistent libcurl refactor, corrected the upload
  handshake measurement, validated bounded streaming and connection reuse,
  added verified TLS/HTTP/2 fixtures, recorded process resource and macOS
  artifact evidence, wrote the decision-gate report, and stopped at
  `INSUFFICIENT EVIDENCE` pending review.
