# AlphaX 1.0 Capability-Gap Audit

Status: [x] Completed

## Goal

Produce a read-only, evidence-backed audit of AlphaX 1.0 capability boundaries,
with explicit decisions about what must be addressed before release, what is a
valid caller/platform boundary, and what should remain post-1.0.

## Scope and Non-goals

Scope:

- review automatic retries, authentication/OAuth responsibility, cookies,
  caching, resilience, explicit HTTPS proxies, Dart IO SPKI pinning, and
  cross-cutting unsupported/caller-owned/fail-closed markers;
- compare AlphaX's responsibility boundary with relevant RFCs and official
  Dio, OkHttp, URLSession, Cronet, Dart IO, reqwest, and libcurl documentation;
- identify public API seams that must be decided before a 1.0 freeze;
- write `docs/alphax-1.0-capability-gap-audit.md` with the required decision
  table and implementation plans for any must-address items.

Non-goals:

- no HTTP/3 availability, negotiation, provider, network, or hardware review;
- no production code, public API, transport architecture, or dependency
  changes;
- no benchmark rerun, publication, tag, commit, or push;
- no implementation of any recommendation before maintainer review.

## Owner

Codex, with maintainer review required before any implementation work.

## Dependencies

- `PROJECT_CONTEXT.md`, architecture and contract documents, relevant ADRs;
- current AlphaX policy implementations and tests;
- existing release scope, requirements, policy, and security research notes;
- primary RFC and official ecosystem documentation.

## Assumptions

- current opt-in policy middleware and fail-closed transport boundaries are the
  behavior under review;
- production-grade means safe, truthful, and evolvable at the HTTP-client
  boundary, not a bundled application framework;
- persistence implementations may remain application-owned when a stable
  storage abstraction is sufficient;
- the maintainer explicitly requested an audit report before implementation.

## Work Items

- [x] Read repository instructions, architecture, contracts, policy ADRs, and
      existing capability/release documentation.
- [x] Inspect current retry, auth, cookie, cache, resilience, proxy, TLS, and
      transport capability implementations and tests.
- [x] Review cross-cutting limitation markers outside the capability matrix.
- [x] Gather primary-source evidence for standards and competing ecosystems.
- [x] Synthesize classifications, release recommendations, and API evolution
      risks.
- [x] Write and review the capability-gap audit report.
- [x] Validate report links/formatting and record the outcome.

## Validation

Completed:

- Inspected the task-owned report/task changes and preserved all pre-existing
  maintainer changes.
- `git diff --check`: passed.
- Relative Markdown link/target check for the report: passed; all five local
  targets resolve.
- Reviewed the report scope and confirmed that no production source files were
  modified and no H3 capability claims were assessed.
- The delegated read-only review was stopped after it did not return within
  the bounded wait; the final report is based on the completed local source
  and primary-document review.

## Next Action

Maintainer reviews the report and decides whether to implement the two
pre-freeze API-contract recommendations. Do not change production code until
that review is complete.

## Blockers

None.

## Outcome

Completed the read-only audit in `docs/alphax-1.0-capability-gap-audit.md`.
The report identifies cookie-store injection and cache variant/security
semantics as the two API-contract decisions to resolve before a stable 1.0
policy freeze; it keeps OAuth orchestration, persistence implementations,
vendor resilience, explicit HTTPS proxy TLS, and Dart IO SPKI within caller,
provider, or platform boundaries.

## References

- `docs/alphax-1.0-capability-gap-audit.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/POLICIES.md`
- `docs/research/alpha-x-1-0-security-platform-research.md`
- `packages/alphax/lib/src/alpha_x_retry.dart`
- `packages/alphax/lib/src/alpha_x_auth.dart`
- `packages/alphax/lib/src/alpha_x_cookie.dart`
- `packages/alphax/lib/src/alpha_x_cache.dart`
- `packages/alphax/lib/src/alpha_x_resilience.dart`
- `packages/alphax/lib/src/alpha_x_security.dart`

## History

- 2026-08-17: Reserved task 27 for the requested read-only 1.0 capability-gap
  audit. Existing worktree changes remain preserved.
- 2026-08-17: Completed the report, primary-source comparison, local-link
  validation, and whitespace check. No production code was changed.
