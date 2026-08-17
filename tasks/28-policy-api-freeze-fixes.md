# AlphaX 1.0 policy API freeze fixes

Status: [x] Completed

## Goal

Implement the maintainer-approved pre-freeze contract corrections for the
asynchronous cookie store and private variant-aware HTTP cache, with
transport-neutral tests, documentation, and a final policy-freeze review.

## Scope and Non-goals

Scope:

- add the stable asynchronous `AlphaXCookieStore` seam while retaining the
  in-memory `AlphaXCookieJar`;
- replace the URI-only cache store contract with a variant-aware private cache
  contract;
- enforce Vary, freshness, revalidation, authentication safety, mutation
  invalidation, and bounded in-memory storage semantics;
- add deterministic cookie/cache tests and local HTTP-date `Retry-After`
  parsing if it remains a contained policy hardening change;
- update public API, migration, policy, scope, requirements, release-gate,
  README, changelog, and focused ADR documentation;
- produce `docs/ALPHAX_1_0_POLICY_FREEZE_REVIEW.md` and run the requested
  release validation without benchmarks or publication.

Non-goals:

- no transport architecture changes, H3 research, or benchmark reruns;
- no OAuth orchestration, persistence implementation, secure-storage or
  database dependency, vendor resilience, WebSocket/SSE, observability,
  offline queue, request coalescing, or other deferred functionality;
- no publication, tag, release, or push.

## Owner

Codex, with maintainer review required after validation.

## Dependencies

- `docs/alphax-1.0-capability-gap-audit.md` approval;
- current `alphax` policy implementations, tests, exports, and docs;
- existing release-gate, requirements, scope, migration, and policy docs;
- Dart/Flutter SDKs and package tooling available in the workspace.

## Assumptions

- AlphaX 1.0 is not yet published, so the URI-only public cache contract may
  be corrected rather than preserved as a permanent second API;
- the default cookie/cache stores remain in-memory and private to the client
  or session unless a caller intentionally shares them;
- custom stores are responsible for durability, encryption, access control,
  corruption handling, and their own asynchronous failure behavior;
- request coalescing is not a 1.0 requirement;
- accepted caller-owned and platform-limited boundaries remain unchanged.

## Work Items

- [x] Inspect and reserve the task scope, affected interfaces, exports, tests,
      and documentation.
- [x] Implement the asynchronous `AlphaXCookieStore` interface and adapt the
      in-memory jar with serialized update behavior.
- [x] Implement variant-aware private cache keys, metadata, freshness, Vary,
      authenticated-response safety, revalidation, invalidation, and bounded
      store behavior.
- [x] Add deterministic cookie/cache and Retry-After date tests.
- [x] Update API inventory, docs, migration notes, ADRs where justified,
      changelog, and policy-freeze review.
- [x] Review the combined diff and run the consolidated validation suite.

## Validation

Completed:

- `dart format --set-exit-if-changed .` passed with no changes;
- `tooling/scripts/analyze_dart_packages.sh` passed for all packages and
  benchmark support packages;
- `tooling/scripts/test_packages.sh` passed for all five packages, including
  policy and shared conformance tests;
- both Flutter examples passed `flutter analyze` and `flutter test`;
- Dartdoc dry-runs passed for all five packages with zero warnings/errors;
- Markdown structural lint and a repository-wide internal-link check passed;
- all five `pub publish --dry-run --ignore-warnings` checks passed. Reported
  archive sizes were alphax 49 KB, alphax_native 73 KB, alphax_dio 12 KB,
  alphax_test 10 KB, and alphax_web 9 KB. Dirty-worktree warnings were
  expected because commit/push is outside this task;
- dependency graph/outdated inspection found no discontinued, retracted, or
  advisory-affected packages in the checked graphs;
- credential/signing/path audit and `git diff --check` passed; and
- no benchmark, transport performance run, publication, tag, or push was done.

## Next Action

Maintainer reviews `docs/ALPHAX_1_0_POLICY_FREEZE_REVIEW.md` before any
publication or final RC release-gate work.

## Blockers

None.

## Outcome

Implemented and validated. The final policy review concludes
`READY TO FREEZE ALPHAX 1.0 POLICY API`; publication, tagging, and push remain
outside scope and require maintainer approval.

## References

- `docs/alphax-1.0-capability-gap-audit.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/POLICIES.md`
- `docs/MIGRATION.md`
- `packages/alphax/lib/src/alpha_x_cookie.dart`
- `packages/alphax/lib/src/alpha_x_cache.dart`
- `packages/alphax/test/policy_middleware_test.dart`

## History

- 2026-08-17: Reserved task 28 for the approved pre-freeze cookie-store and
  cache-contract implementation. Existing worktree changes remain preserved.
- 2026-08-17: Completed cookie-store atomic update seam, variant-aware private
  cache contract, deterministic policy tests, ADRs, documentation, package
  dry-runs, and consolidated validation. Stopped for maintainer review.
