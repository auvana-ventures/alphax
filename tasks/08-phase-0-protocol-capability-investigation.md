# Phase 0 protocol capability investigation

Status: [x] Completed

## Goal

Determine the smallest maintainable AlphaX 1.0 transport architecture that can
provide HTTP/1.1, HTTP/2, and HTTP/3 on Android and iOS while keeping the public
AlphaX API transport-independent. Preserve all prior Phase 0 performance
evidence and stop for maintainer review without creating ADR 0004 or beginning
Phase 1.

## Scope and Non-goals

Scope:

- Compare platform-native networking, libcurl, the existing Rust prototype only
  insofar as production HTTP/3 is realistic, and Dart IO as fallback/baseline.
- Verify current protocol/platform capabilities and engineering implications
  from primary documentation and the existing repository prototypes.
- Explain Dart isolate versus native execution boundaries for a Flutter UI.
- Produce one concise architecture capability report.

Non-goals:

- No benchmark reruns or new performance matrix.
- No transport implementation, public API change, C++ engine, HTTP/3 prototype,
  ADR 0004, Phase 1 work, package publication, or production selection change.
- Do not discard, rewrite, or reinterpret historical Round 1/2/3/4/final/mobile
  benchmark datasets.

## Owner

Codex, with maintainer review required before any transport implementation or
ADR 0004.

## Dependencies

- Existing AlphaX project context, transport contract, and native prototypes.
- Current official platform/library documentation for HTTP/1.1, HTTP/2, HTTP/3,
  TLS, proxying, cancellation, streaming, and distribution requirements.

## Assumptions

- AlphaX 1.0's H1/H2/H3 requirement is mandatory on Android and iOS; desktop
  behavior remains part of the architecture comparison.
- Dart IO remains available as a fallback/baseline even if it cannot satisfy
  the H3 requirement by itself.
- Capability and maturity, not hypothetical localhost or UI microbenchmark
  improvements, drive the recommendation.

## Work Items

- [x] Inspect existing architecture/prototype evidence and preserve historical
  benchmark conclusions.
- [x] Gather primary-source protocol/platform capability evidence.
- [x] Analyze Flutter isolate/native workload boundaries.
- [x] Write and validate one concise capability report.

## Validation

Completed:

- Reviewed official Android, Apple, curl, Rust, Dart, and Flutter documentation
  for the capability claims in the report; repository-specific claims were
  checked against the existing prototypes and historical reports.
- Confirmed that no benchmark command was run and no transport source, public
  API, ADR 0004, or Phase 1 file was changed.
- Ran Markdown/trailing-whitespace checks and reviewed the task/report-only
  diff while preserving pre-existing user-owned working-tree changes.

## Next Action

Stop for maintainer review. Do not implement adapters or create ADR 0004 until
the recommendation is approved.

## Blockers

None.

## Outcome

Created `benchmarks/results/summaries/phase0-protocol-capability-investigation.md`.
The report recommends a platform-native mobile strategy: Cronet/HttpEngine on
Android, URLSession on iOS/macOS, and Dart IO as the fallback/baseline. It does
not select a production transport, create ADR 0004, or begin Phase 1.

## References

- `PROJECT_CONTEXT.md`
- `docs/decisions/0002-transport-benchmark-first.md`
- `docs/decisions/0003-public-api-transport-independence.md`
- `benchmarks/results/summaries/phase0-final-transport-decision.md`
- `benchmarks/results/summaries/phase0-mobile-sanity-gate.md`
- `prototypes/dart_io/`
- `prototypes/libcurl_ffi/`
- `prototypes/rust_http/`
- `benchmarks/results/summaries/phase0-protocol-capability-investigation.md`
- Android Cronet documentation: <https://developer.android.com/media/media3/exoplayer/network-stacks>
- Apple URLSession documentation: <https://developer.apple.com/documentation/foundation/urlsession>
- curl HTTP/3 documentation: <https://curl.se/docs/http3.html>
- reqwest documentation: <https://docs.rs/reqwest/latest/reqwest/index.html>
- Flutter isolates documentation: <https://docs.flutter.dev/perf/isolates>

## History

- 2026-08-14: Created for the maintainer-approved protocol capability gate.
- 2026-08-14: Completed source-backed capability review and report; stopped for
  maintainer approval before any transport implementation or ADR.
