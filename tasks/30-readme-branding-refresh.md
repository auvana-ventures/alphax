# Task 30: README branding and onboarding refresh

Status: [x] Completed

## Goal

Give the root project and all AlphaX package READMEs a consistent, theme-aware
brand treatment and a clearer beginner-first path from package selection to a
working example, while preserving the frozen 1.0 release claims and boundaries.

## Scope and Non-goals

Scope:

- add the supplied dark and light AlphaX SVG logo variants as repository assets;
- use a theme-aware HTML `picture` block in the root and package READMEs;
- improve README hierarchy, package selection, quick starts, capability summaries,
  and links across `alphax`, `alphax_native`, `alphax_dio`, `alphax_test`, and
  `alphax_web`;
- reconcile package-status wording with the approved `1.0.0-rc.1` publication set;
- validate Markdown links, asset references, package README visibility, and the
  task-owned diff.

Non-goals:

- no production API, transport, policy, dependency, or benchmark changes;
- no new feature claims, performance claims, badges, or release publication;
- no rewrite of historical audit, benchmark, or release documents;
- no persistent logo-generation or theme-CSS dependency.

## Owner

Codex, with maintainer review required before any release publication.

## Dependencies

- supplied assets at `/Users/princeteck/Pictures/designer-2-exports/alphax/`;
- approved AlphaX 1.0 RC scope and package publication decisions;
- current root and package README content.

## Assumptions

- the supplied SVGs intentionally represent dark-background and light-background
  variants with fixed fills;
- GitHub and package registries can render remote SVG references from the public
  repository, while the root README can use repository-relative references;
- both logo variants are required because an external SVG cannot inherit the
  GitHub page's parent text color through an `<img>` element.

## Work Items

- [x] Add central dark/light logo assets and a shared README usage pattern.
- [x] Refresh the root README structure and package-status wording.
- [x] Refresh all five package READMEs without changing API semantics.
- [x] Run Markdown, link, asset, formatting, and package-facing validation.
- [x] Review the combined diff and record the outcome.

## Validation

- inspect SVG fills and README asset references;
- custom local Markdown-link and logo-reference check: passed;
- `git diff --check`: passed;
- source/export SVG byte comparison: passed for both variants;
- `dart pub publish --dry-run` for `alphax`, `alphax_native`, `alphax_dio`,
  `alphax_test`, and `alphax_web`: passed with the expected uncommitted-README
  warning; archive sizes were 50 KB, 73 KB, 12 KB, 10 KB, and 9 KB;
- review all changed READMEs for accurate 1.0.0-rc.1 claims and no unsupported
  performance or protocol guarantees: passed.

## Next Action

The central logo variants and coordinated README refresh are complete. The
package README URLs will resolve once this task is committed to `main`; no
package-local asset duplication was introduced.

## Blockers

None.

## Outcome

Added exact copies of the supplied dark/light SVG exports at
`assets/branding/alphax-logo-dark.svg` and `assets/branding/alphax-logo-light.svg`.
Updated the root README and all five package READMEs with theme-aware logo
selection, concise capability summaries, clearer package positioning, and
beginner-oriented entry points. No production code, API, transport, policy,
benchmark, or dependency behavior changed.

## References

- `/Users/princeteck/Pictures/designer-2-exports/alphax/logo-dark.svg`
- `/Users/princeteck/Pictures/designer-2-exports/alphax/logo-light.svg`
- `README.md`
- `packages/*/README.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/POLICIES.md`
- `https://github.com/Shreemanarjun/nitro_http`

## History

- 2026-08-17: Task reserved for the coordinated README and branding refresh.
- 2026-08-17: Added central logo assets and refreshed all six user-facing
  READMEs; validation and package dry-runs passed.
- 2026-08-17: Post-completion correction after local VS Code preview exposed
  the limitation of unpushed remote logo URLs. Added exact logo copies to each
  independently publishable package and changed package README references to
  local package assets so previews, GitHub, and pub.dev archives work without
  depending on the repository branch being available remotely.
- 2026-08-17: Re-ran package dry-runs after the correction; archives included
  the local branding assets and measured 52 KB, 75 KB, 14 KB, 12 KB, and 11 KB
  for `alphax`, `alphax_native`, `alphax_dio`, `alphax_test`, and `alphax_web`.
