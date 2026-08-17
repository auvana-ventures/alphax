# Non-H3 Capability Support

Status: [x] Completed

## Goal

Implement the requested non-H3 AlphaX capabilities instead of documenting them
only as exclusions: browser/Web transport, safe automatic retries,
authentication orchestration, cookies, caching, and generic resilience policy.
Keep H3 opportunistic and preserve the transport-independent core seam.

## Scope and Non-goals

Scope:

- add transport-independent policy modules behind `AlphaXMiddleware` for:
  - replay-aware, cancellation-aware retries with safe defaults;
  - authentication header injection and single-flight refresh after an
    authentication challenge;
  - an in-memory cookie jar with host/path/secure/expiry handling;
  - an in-memory HTTP cache with freshness, conditional revalidation, and
    mutation invalidation;
  - generic resilience controls such as a circuit breaker, without a vendor
    SDK or vendor-specific policy;
- add a separate browser Fetch transport package that implements the AlphaX
  transport seam and reports browser protocol limitations honestly;
- add deterministic tests, exports, package metadata, examples, and user
  documentation for the supported behavior;
- update the frozen API inventory and scope to distinguish implemented
  capabilities from the remaining H3 guarantee limitation.

Non-goals:

- no native transport implementation inside the pure-Dart `alphax` package;
- no universal H3 guarantee or browser H2/H3 inference;
- no unsafe automatic replay of non-replayable request bodies;
- no trust-all TLS behavior, secret logging, persistent cookie storage, disk
  cache, model-specific authentication framework, or vendor resilience SDK;
- no benchmark rerun, transport architecture replacement, publication, tag,
  commit, or push in this task.

## Owner

Codex coordinator; maintainer review remains required.

## Dependencies

- frozen `AlphaXTransport` and `AlphaXMiddleware` interfaces;
- `AlphaXRequest` replayability and cancellation semantics;
- `alphax_test` fake transport and conformance helpers;
- Dart Web Fetch support through the selected browser HTTP client package.

## Assumptions

- the user’s latest instruction supersedes the earlier documentation-only
  interpretation and requests real support for the listed non-H3 behaviors;
- these additions are non-gating follow-up capabilities for the already
  prepared RC unless the maintainer explicitly promotes them into the release
  gate;
- in-memory cookie/cache modules are a useful first supported implementation;
  persistent storage and application-specific token persistence remain caller
  responsibilities;
- Web can support ordinary browser HTTP requests while leaving negotiated
  protocol unknown and rejecting an H3 requirement rather than guessing.

## Work Items

- [x] Inspect current package seams, middleware, request-body replayability,
  capabilities, and Web dependency options.
- [x] Finalize public interfaces and package placement for each capability.
- [x] Implement retry, auth, cookie, cache, and generic resilience middleware.
- [x] Implement the browser Fetch transport package and capability mapping.
- [x] Add deterministic unit/conformance tests and public exports.
- [x] Update API inventory, scope/audit, package READMEs, examples, and
  changelogs to describe supported behavior and remaining limitations.
- [x] Run affected Dart, Flutter/Web, documentation, and package validation.

## Validation

Completed:

- `dart format --set-exit-if-changed` for `alphax` and `alphax_web`: passed;
- `dart analyze` for `alphax`, `alphax_web`, `alphax_dio`, `alphax_test`, and
  `alphax_native`: passed;
- full `alphax` tests including policy middleware: passed;
- `alphax_test`, `alphax_dio`, and `alphax_native` tests: passed;
- `alphax_web` VM tests, Chrome tests, and JavaScript compilation: passed;
- `dart doc --validate-links` for `alphax` and `alphax_web`: zero warnings and
  zero errors using temporary output directories;
- public export audit and `git diff --check`: passed;
- package dry-runs for all five workspace packages: completed. The four
  previously approved RC packages emitted only expected dirty-worktree
  warnings; `alphax_web` emitted zero warnings.
- root `dart analyze` was not a valid package-wide gate because the repository's
  standalone benchmark app lacks its separate integration-test/prototype
  dependencies; package-scoped analysis above is clean and the benchmark was
  not changed or rerun.

## Next Action

Maintainer review the completed optional policy/Web capability work and decide
whether `alphax_web` joins the approved RC publication set. No publication,
commit, push, benchmark rerun, or transport-architecture change is authorized
by this task.

## Blockers

None currently. The browser runtime may limit authoritative protocol metadata,
file paths, and request cancellation; those limitations must be surfaced as
capability states rather than hidden.

## Outcome

Completed. AlphaX now has explicit opt-in non-H3 policy support and a separate
browser Fetch adapter. The pure-Dart core remains transport-independent, H3
remains opportunistic, unsafe replay is blocked by default, and browser
protocol metadata remains unknown/fail-closed for concrete requirements.

## References

- `packages/alphax/lib/src/alpha_x_client.dart`
- `packages/alphax/lib/src/alpha_x_middleware.dart`
- `packages/alphax/lib/src/alpha_x_request.dart`
- `packages/alphax/lib/src/alpha_x_body.dart`
- `packages/alphax/lib/src/alpha_x_transport.dart`
- `packages/alphax_test/lib/src/fake_alpha_x_transport.dart`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/phase1a-public-api-inventory.md`

## History

- 2026-08-17: Reserved task 24 after correcting the prior documentation-only
  interpretation of the requested non-H3 capabilities.
- 2026-08-17: Implemented and tested policy middleware, added `alphax_web`,
  synchronized the frozen API/release documentation, and completed package
  dry-runs and browser validation.
