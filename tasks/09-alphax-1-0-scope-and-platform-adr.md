# AlphaX 1.0 scope and platform transport ADR

Status: [x] Completed

## Goal

Create the definitive AlphaX 1.0 scope, record the platform-native mobile
transport strategy in Proposed ADR 0004, and provide a bounded Phase 1
implementation roadmap. This package is documentation-only; it must not begin
transport implementation or another benchmark round.

## Scope and Non-goals

Scope:

- Create `docs/ALPHAX_1_0_SCOPE.md` as the classification source of truth and
  align `docs/roadmap.md` to point to it.
- Create `docs/decisions/0004-platform-native-mobile-transports.md` with status
  `Proposed`.
- Include the requested Phase 1A–1F deliverables, dependencies, tests, and exit
  criteria in the scope document.
- Reconcile the documents with the existing pure-Dart API, platform capability
  investigation, package boundaries, and historical benchmark reports.

Non-goals:

- No Dart, Kotlin/Java, Swift/Objective-C, FFI, platform-channel, or native
  transport implementation.
- No benchmark rerun, benchmark dataset rewrite, package publication, ADR
  acceptance, or Phase 1 execution.
- No C++ engine, production Rust transport, cache, retry engine, telemetry
  integration, DevTools extension, GraphQL, REST generator, or web transport
  implementation.

## Owner

Codex, with maintainer review and explicit ADR acceptance required before
implementation begins.

## Dependencies

- `PROJECT_CONTEXT.md` and repository `AGENTS.md`.
- `docs/architecture/overview.md` and `docs/architecture/transport_contract.md`.
- ADRs 0001–0003.
- Historical Phase 0 benchmark and protocol capability reports.
- Existing package manifests and PRD context.

## Assumptions

- H1/H2/H3 are required protocol capabilities on Android, iOS, and macOS for
  AlphaX 1.0; Windows/Linux may use Dart IO initially.
- The public `alphax` API remains transport-independent and Flutter-free.
- Android uses Cronet/HttpEngine, Apple platforms use URLSession, and Dart IO
  remains a fallback/baseline.
- `REQUIRED FOR 1.0`, `OPTIONAL FOR 1.0`, `POST-1.0`, and `EXPLICIT NON-GOAL`
  are the only capability classifications in the definitive scope.

## Work Items

- [x] Reserve the documentation task and inspect existing architecture/ADR
  conventions.
- [x] Write `docs/ALPHAX_1_0_SCOPE.md` with complete capability classifications,
  required-item completion contracts, exclusions, package changes, and Phase 1
  roadmap.
- [x] Write Proposed ADR 0004 without accepting it or implementing transports.
- [x] Remove conflicting roadmap status language by pointing `docs/roadmap.md`
  to the definitive scope.
- [x] Review links, status coverage, contradictions, and task-owned diff.
- [x] Record validation and stop for maintainer review.

## Validation

Completed validation:

- Every requested capability has exactly one allowed classification.
- Every `REQUIRED FOR 1.0` item includes user behavior, public API impact,
  transport requirements, platforms, fallback, tests, docs, and completion
  criteria.
- ADR status remains `Proposed` and explicitly preserves historical
  evidence without selecting Dart IO as the sole transport.
- `git diff --check`, trailing-whitespace checks, classification validation,
  link-target checks, and Markdown linting passed. Markdown line-length and
  table-style rules were disabled for the intentionally wide contract tables.
- No source, benchmark, package manifest, or historical report changes were
  introduced by this task; the pre-existing user-owned prototype/mobile-gate
  changes remain untouched.

## Next Action

Stop for maintainer review. Do not accept ADR 0004 or begin Phase 1
implementation in this task.

## Blockers

None.

## Outcome

Created and validated the definitive 1.0 scope, Proposed ADR 0004, and roadmap
pointer. No implementation, benchmark rerun, ADR acceptance, or publication was
performed.

## References

- `PROJECT_CONTEXT.md`
- `AGENTS.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- `docs/decisions/0001-monorepo-and-package-boundaries.md`
- `docs/decisions/0002-transport-benchmark-first.md`
- `docs/decisions/0003-public-api-transport-independence.md`
- `benchmarks/results/summaries/phase0-protocol-capability-investigation.md`
- `benchmarks/results/summaries/phase0-final-transport-decision.md`
- `benchmarks/results/summaries/phase0-mobile-sanity-gate.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/roadmap.md`

## History

- 2026-08-14: Created for the maintainer-approved AlphaX 1.0 scope and Proposed
  ADR 0004 documentation package.
- 2026-08-14: Completed the scope, ADR, roadmap alignment, and documentation
  validation; stopped for maintainer review before implementation.
- 2026-08-14: Maintainer approved the scope and accepted ADR 0004. Phase 0 is
  closed; Phase 1A contract stabilization is authorized, while Phase 1B–1F
  remain out of scope for this task.
