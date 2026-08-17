# AlphaX 1.0 release-quality marker audit

Audit date: 2026-08-17

This is a release-quality marker classification, not a new capability-gap
audit. The repository was searched for `TODO`, `FIXME`, `HACK`, `XXX`,
`experimental`, `temporary`, `placeholder`, `unsupported`, `unimplemented`,
`not implemented`, `future`, `planned`, and `deprecated`. Generated build
directories and raw benchmark result blobs were excluded from the semantic
review; historical benchmark and prototype files were classified rather than
rewritten.

| Class | Finding | Representative locations | Release action |
| --- | --- | --- | --- |
| A — release blocker | No release-blocking TODO, FIXME, HACK, XXX, unimplemented required behavior, or deprecated shipped API was found in the current 1.0 package surface. | `packages/*/lib`, current scope/release documents | None. The required API rows are implemented and validated or explicitly accepted as platform/caller boundaries. |
| B — accepted platform limitation | `unsupported` capability values and fail-closed errors describe Dart IO H1-only behavior, browser-owned Fetch controls, provider-limited proxy/TLS/mTLS behavior, and unavailable authoritative browser protocol metadata. | `packages/alphax_native/lib/src/dart_io_transport.dart`, `packages/alphax_web/lib/src/web_fetch_transport.dart`, `docs/ALPHAX_1_0_RELEASE_GATE.md` | Keep the capability state and documentation. Do not silently degrade or weaken security. |
| C — post-1.0/deferred work | Explicit future scope includes persistence implementations, SPM packaging, offline queue, telemetry integrations, WebSocket/SSE, GraphQL/REST generation, background transfer lifecycle, and vendor-specific policies. | `docs/ALPHAX_1_0_SCOPE.md`, `PROJECT_CONTEXT.md`, `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md` | Leave outside the frozen 1.0 core. Track only as separately approved follow-up work. |
| D — historical/prototype/benchmark evidence | `experimental`, `temporary`, `planned`, `future`, and `unimplemented` wording in Phase 0/1 reports, benchmark runners, and FFI/Rust/libcurl prototypes describes old evidence or research state. | `docs/phase1*.md`, `docs/benchmarks.md`, `benchmarks/**`, `prototypes/**`, `docs/alphax-1.0-capability-gap-audit.md` | Preserve historical records. Do not rewrite evidence to remove the state that was observed. |
| E — harmless documentation/tooling wording | Flutter scaffold TODOs for application IDs/signing setup, temporary test-file wording, safe placeholder pin/host values, and task-file planned validation steps are not production package promises or secrets. | `examples/waypoint/**`, `benchmarks/mobile_gate/**`, `docs/POLICIES.md`, `tasks/**` | No release action. Keep examples clearly non-production and keep real credentials out. |

## Focused conclusions

- No marker is classified A.
- The word `unsupported` is used both as an intentional capability state and in
  historical reports; neither is an accidental promise of support.
- The conditional Web stub is an expected non-Web analysis target, while the
  browser implementation is validated separately. It is not a placeholder
  package or an unimplemented RC package.
- The obsolete native placeholder transport is not exported; the remaining
  `placeholder` matches are documentation/stub or historical wording.
- No production default contains a benchmark endpoint, QUIC diagnostic hint,
  trust-all path, signing value, private key, or machine-specific path.

The marker audit is complete for RC review. It does not authorize new feature
work or changes to the frozen AlphaX 1.0 API.
