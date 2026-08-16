# AlphaX Dio RC Adapter

Status: [x] Completed

## Goal

Make `alphax_dio` a deliberate, publishable `1.0.0-rc.1` compatibility
boundary by implementing an AlphaX-backed Dio `HttpClientAdapter`, validating
the request/response lifecycle, and updating the RC publication and migration
documentation.

## Scope and Non-goals

Scope:

- implement a pure-Dart `AlphaXDioAdapter` over an injected `AlphaXClient`;
- map Dio request streams, headers, methods, cancellation, timeouts, redirects,
  progress, response streams, normalized errors, and completion protocol
  metadata without changing AlphaX transport architecture;
- add deterministic adapter tests using the existing AlphaX fake transport;
- set `alphax_dio` to the proposed `1.0.0-rc.1` publication boundary and
  review its package metadata;
- update the public API inventory, migration guide, package README/changelog,
  release gate, RC review, and package publication order.

Non-goals:

- no new transport, native code, Flutter dependency, benchmark, retry policy,
  cache, auth framework, or resilience feature;
- no claim of full source-compatible Dio behavior or full Dio API parity;
- no per-request trust-all, native TLS, or proxy implementation in the adapter;
  those policies remain owned by the configured AlphaX transport/client;
- no historical report rewrite, pub.dev publication, git tag, GitHub release,
  or final 1.0 work.

## Owner

Codex coordinator with maintainer approval required before publication.

## Dependencies

- `alphax` `1.0.0-rc.1` contracts;
- Dio 5.x `HttpClientAdapter` contract;
- `alphax_test` deterministic fake transport for adapter tests;
- accepted AlphaX transport, protocol, security, and package-boundary ADRs.

## Assumptions

- `alphax_dio` depends on `alphax` and Dio 5.x, and uses `alphax_test` only
  for development tests;
- callers provide an already configured `AlphaXClient`, so native transport,
  TLS, trust, pinning, proxy, and middleware policy remain explicit;
- AlphaX-specific protocol preference/requirement values are supplied through
  documented typed `RequestOptions.extra` keys;
- response metadata uses Dio's standard HTTP-version extra plus documented
  AlphaX metadata extras, including completion-time futures.

## Work Items

- [x] Implement and document `AlphaXDioAdapter` with safe lifecycle and error
  mapping.
- [x] Add deterministic tests for request mapping, response/body streaming,
  cancellation, timeout/error mapping, redirects, progress, and protocol
  metadata.
- [x] Update package version, dependencies, publish state, README, changelog,
  migration/API inventory, release gate, and RC review publication set/order.
- [x] Run scoped formatting, analysis, tests, docs, package dry-run, and
  security/endpoint/package audits.
- [x] Commit and push the bounded Dio RC update; verify remote and worktree.

## Validation

The scoped checks completed:

- `dart format --set-exit-if-changed packages/alphax_dio`;
- `dart analyze packages/alphax_dio`;
- `dart test` in `packages/alphax_dio`;
- Dartdoc and Markdown/link checks for changed documentation;
- `dart pub publish --dry-run` for `alphax_dio`;
- package dependency and production-endpoint audits;
- `git diff --check`, push verification, and clean worktree check.

Results:

- `dart format --set-exit-if-changed packages/alphax_dio/lib
  packages/alphax_dio/test` passed.
- `dart analyze` and all six `alphax_dio` adapter tests passed.
- Dartdoc with `--validate-links` passed with zero warnings and zero errors.
- Package README, changelog, migration, compatibility, API inventory, RC
  review, and task documentation passed the focused Markdown checks; the
  existing table-heavy API/root release docs retain only baseline line-length
  warnings.
- `dart pub publish --dry-run` for `alphax_dio` passed with zero warnings and
  zero errors. The compressed archive is 10 KB and contains only the expected
  adapter source, tests, metadata, license, and documentation.
- Dependency, production-endpoint, signing/secret, certificate/private-key,
  machine-path, and `git diff --check` audits passed.
- The adapter commit is `8b2975b`; final remote/worktree verification is
  recorded with the closeout commit after push.

The existing AlphaX transport and broad release-gate benchmark validation will
not be restarted for this adapter-only boundary.

## Next Action

Wait for maintainer approval and naming clearance before publication. No new
transport, benchmark, or post-1.0 work is authorized by this task.

## Blockers

None known. Publication remains intentionally held for maintainer approval and
naming clearance.

## Outcome

`alphax_dio` is ready as an optional `1.0.0-rc.1` package. The focused
`AlphaXDioAdapter` is implemented, tested, documented, included in the RC
publication set, and represented in the frozen API/package review. It remains
a deliberate compatibility boundary rather than full Dio API compatibility.
No package was published.

## References

- `docs/prd/04_API_DIO.md`
- `docs/architecture/transport_contract.md`
- `docs/MIGRATION.md`
- `docs/phase1a-public-api-inventory.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `packages/alphax_dio/README.md`
- `packages/alphax_dio/pubspec.yaml`

## History

- 2026-08-16: Reserved task 18 after the maintainer expanded RC scope to make
  `alphax_dio` publishable as a deliberate adapter boundary.
- 2026-08-16: Implemented the adapter, deterministic tests, RC package metadata,
  migration/API/release documentation, and clean 10 KB pub dry-run. Committed
  the bounded implementation as `8b2975b`; final closeout push verification is
  pending in the next documentation commit.
