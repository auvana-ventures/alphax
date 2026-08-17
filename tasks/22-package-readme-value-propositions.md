# Package README Value Propositions

Status: [x] Completed

## Goal

Make the AlphaX package READMEs understandable to a new user by explaining
which problem each package solves, when to choose it, and how to perform a
first useful operation, while preserving truthful 1.0 platform and security
boundaries.

## Scope and Non-goals

Scope:

- improve the root package-selection guidance;
- rewrite the `alphax`, `alphax_native`, `alphax_dio`, and `alphax_test`
  READMEs around user goals, benefits, quick starts, examples, and limits;
- link readers to the Waypoint reference app and migration documentation;
- keep all claims consistent with the frozen 1.0 API and release gate.

Non-goals:

- no source, public API, transport, package metadata, or dependency changes;
- no benchmark rerun or numeric performance claims;
- no promise of full Dio compatibility or universal H3;
- no publication, tag, release, commit, or push.

## Owner

Codex coordinator; maintainer review remains required.

## Dependencies

- `docs/ALPHAX_1_0_SCOPE.md`;
- `docs/ALPHAX_1_0_RELEASE_GATE.md`;
- `docs/MIGRATION.md`;
- `examples/waypoint/README.md`;
- current public package APIs and package manifests.

## Assumptions

- the README should be useful on pub.dev without requiring the reader to open
  internal release documents first;
- package-specific technical details remain available after the quick-start
  section;
- examples use only released/frozen public APIs.

## Work Items

- [x] Reserve task 22 and define the package-documentation scope.
- [x] Add a package-selection/value-proposition section to the root README.
- [x] Rewrite the four package READMEs with beginner-first structure and
  accurate benefits.
- [x] Review links, code snippets, limitations, and unsupported-claim wording.
- [x] Run Markdown and whitespace validation and record the outcome.

## Validation

Completed on 2026-08-17:

- Markdown lint passed for the root, package, and task READMEs;
- relative-link target checks passed;
- `git diff --check` and trailing-whitespace checks passed;
- claim scan found only intentional disclaimers; no unsupported performance,
  universal H3, or full-Dio claims were added;
- all referenced package, example, migration, and release-gate files exist.

## Next Action

Maintainer review the root/package README diff. No source or release changes are
required.

## Blockers

None.

## Outcome

Completed. The root README now provides a package-selection table. The four
package READMEs now explain their user-facing purpose and benefits before
implementation detail, include first-use examples and common workflows, and
state platform, security, protocol, testing, and compatibility boundaries. The
documentation follows Dio's task-oriented discoverability pattern without
copying its claims or adding benchmark marketing.

## References

- `README.md`
- `packages/alphax/README.md`
- `packages/alphax_native/README.md`
- `packages/alphax_dio/README.md`
- `packages/alphax_test/README.md`
- `examples/waypoint/README.md`
- `docs/MIGRATION.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `https://pub.dev/packages/dio`

## History

- 2026-08-17: Reserved task 22 after comparing AlphaX package READMEs with
  Dio's pub.dev documentation structure.
- 2026-08-17: Completed the root/package README rewrite and focused
  documentation validation.
