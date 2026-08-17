# 1.0 Policy Defaults and Customization Documentation

Status: [x] Completed

## Goal

Make the AlphaX 1.0 policy and transport documentation understandable to a
non-specialist: show what happens by default, which behaviors are opt-in, how
to enable each supported policy, and how to handle provider limitations without
silently weakening security or request safety.

## Scope and Non-goals

Scope:

- update the core, native, Dio, and Web package README guidance where their
  setup or limitations differ;
- update the shared migration/release documentation with a canonical policy
  setup path and copyable examples;
- explain defaults, opt-in behavior, customization points, failure-closed
  limitations, and safe next steps for retry, authentication, cookies, cache,
  resilience, protocol selection, proxy routing, and TLS/SPKI pinning;
- validate Markdown examples and documentation links without changing the
  frozen public API or transport architecture.

Non-goals:

- no source-code or public-API changes;
- no new vendor-specific resilience policy, OAuth framework, persistent cache,
  cookie database, or H3 guarantee;
- no benchmark rerun or performance claim;
- no publication, tag, release, or rewrite of historical reports.

## Owner

Codex, with maintainer review required before publication.

## Dependencies

- current AlphaX public policy constructors and transport capability mappings;
- `docs/ALPHAX_1_0_SCOPE.md`, `docs/ALPHAX_1_0_RELEASE_GATE.md`, and
  `docs/MIGRATION.md`;
- package README files and existing documentation validation scripts.

## Assumptions

- the existing public API is frozen for 1.0;
- examples must use only released AlphaX symbols and clearly marked placeholder
  values for credentials, hosts, and pin material;
- provider-specific unsupported controls remain explicit failure-closed
  boundaries rather than being presented as universal features.

## Work Items

- [x] Inventory current policy documentation and verify public constructor
      signatures used by examples.
- [x] Add a shared defaults/opt-in/customization guide with examples.
- [x] Align package READMEs and migration/release documentation with the guide.
- [x] Review the combined documentation diff for accuracy, security, and
      beginner usability.
- [x] Run focused Markdown/link/format validation and record the results.

## Validation

Completed:

- `dart format --set-exit-if-changed .`;
- package documentation validation through `tooling/scripts/validate_packages.sh`;
- `dart doc --validate-links` for packages whose README links changed;
- `git diff --check` and a focused scan for stale defaults, real secrets,
  machine-specific paths, and unsupported claims.

## Next Action

Maintainer review is the next action. Publication, tagging, and transport
changes remain outside this task.

## Blockers

None.

## Outcome

The shared policy guide and package-specific documentation now explain the
default/opt-in boundary, safe customization steps, platform limitations, and
failure-closed behavior for retries, authentication, cookies, caching,
resilience, protocols, proxies, and TLS/SPKI pinning.

## History

- 2026-08-17: Created for the requested defaults, examples, and customization
  documentation pass.
- 2026-08-17: Added `docs/POLICIES.md`, aligned root/package READMEs,
  migration/scope/release-gate documentation, and added a deterministic policy
  example to `alphax_test`.
- 2026-08-17: `dart format --set-exit-if-changed .` passed; package dry-runs
  completed with the expected dirty-worktree warnings for the modified root
  README; fresh `dart doc --validate-links` passed for all five packages with
  zero warnings and zero errors; `git diff --check` passed.
- 2026-08-17: Split the requirements-audit state for validated generic policy
  middleware from the intentionally unsupported vendor-specific resilience
  policy so the audit matches the implementation and guide.

## References

- `packages/alphax/README.md`
- `packages/alphax_native/README.md`
- `packages/alphax_dio/README.md`
- `packages/alphax_web/README.md`
- `docs/MIGRATION.md`
- `docs/POLICIES.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`
