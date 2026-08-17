# Task 31: README v2 hybrid structure

Status: [x] Completed

## Goal

Create a clearer, more useful AlphaX README experience by combining the current
repository's accurate 1.0 release documentation with the stronger onboarding,
visual hierarchy, and feature navigation used by the referenced `nitro_http`
README.

## Scope and Non-goals

Scope:

- revise the root README as the product overview and first-read guide;
- revise all five package READMEs to use a consistent user journey;
- keep the theme-aware, package-local logo treatment from Task 30;
- move the most useful install and first-request paths earlier;
- add concise “why AlphaX”, package/platform selection, capability boundaries,
  and feature navigation sections;
- preserve the frozen 1.0 API, platform matrix, security defaults, caller-owned
  boundaries, RC status, and package publication status.

Non-goals:

- no production code, API, transport, dependency, benchmark, or package-version
  changes;
- no unsupported performance claims, universal H3 claims, or cross-platform
  parity claims;
- no WebSocket/SSE, mTLS, disk-cache, OAuth-orchestration, observability, or
  other deferred feature claims;
- no rewrite of historical benchmark or release documents;
- no publication, tag, release, or push operation.

## Owner

Codex, with maintainer review required before release publication.

## Dependencies

- current root and package README content;
- AlphaX 1.0 RC scope and accepted policy boundaries;
- package-local logo assets from Task 30;
- referenced comparison README:
  `https://github.com/Shreemanarjun/nitro_http`.

## Assumptions

- the root README should explain the product and help users choose a package;
- package READMEs should be independently understandable on pub.dev;
- detailed policy/security documentation remains the source of truth for edge
  cases, while READMEs should link to it rather than duplicate every rule;
- code examples must use only released/frozen AlphaX APIs.

## Work Items

- [x] Compare the current AlphaX README set with the reference README.
- [x] Define and apply the hybrid root README structure.
- [x] Define and apply consistent package README structures.
- [x] Preserve and reconcile all factual 1.0 boundaries and package statuses.
- [x] Run Markdown, link, logo, package dry-run, and diff validation.
- [x] Review the combined documentation diff and record the outcome.

## Validation

- local Markdown link and asset-path checks;
- `git diff --check`;
- verify package-local logo assets remain exact copies;
- `dart pub publish --dry-run` for each RC package;
- review for forbidden marketing claims and stale package/status wording;
- no production test or benchmark rerun unless documentation validation reveals
  a source/API mismatch.

Results:

- local links, image paths, and logo identity: passed;
- `git diff --check`: passed;
- all five package dry-runs: passed, with expected uncommitted-README warnings;
- archive sizes: 52 KB, 75 KB, 14 KB, 12 KB, and 11 KB for `alphax`,
  `alphax_native`, `alphax_dio`, `alphax_test`, and `alphax_web`;
- no new unsupported performance, H3, transport-parity, or deferred-feature
  claims introduced.

## Next Action

The hybrid README information architecture and package alignment are complete.

## Blockers

None.

## Outcome

The root README now combines AlphaX's factual release/platform/security content
with a concise hero, early installation choices, a quick start, a task-based
feature map, and reusable-client guidance. All five package READMEs now expose a
short Start-here path before their detailed examples and boundaries. The Nitro
README's strong onboarding patterns were adopted without copying unsupported
benchmark, universal-performance, single-engine, WebSocket, mTLS, or parity
claims.

## References

- `README.md`
- `packages/*/README.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/POLICIES.md`
- `docs/MIGRATION.md`
- `https://github.com/Shreemanarjun/nitro_http`

## History

- 2026-08-17: Task reserved after comparing the current AlphaX README set with
  the `nitro_http` README.
- 2026-08-17: Applied and validated the hybrid root/package README structure.
