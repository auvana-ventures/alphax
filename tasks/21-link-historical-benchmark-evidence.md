# Link Historical Benchmark Evidence

Status: [x] Completed

## Goal

Make the root README's benchmark disclaimer directly traceable to the
historical benchmark policy and linked result summaries without adding numeric
performance claims to user-facing package READMEs.

## Scope and Non-goals

Scope:

- update the root README benchmark disclaimer with a direct link to
  `docs/benchmarks.md`;
- preserve the package README policy of omitting unqualified benchmark numbers;
- run focused Markdown, link, whitespace, and repository-state checks.

Non-goals:

- no benchmark rerun or result rewriting;
- no package README performance claims;
- no source, API, transport, version, or release changes;
- no commit, tag, publication, or push.

## Owner

Codex coordinator; maintainer review remains required.

## Dependencies

- root README;
- `docs/benchmarks.md` historical benchmark policy and result links;
- current 1.0 release-gate documentation.

## Assumptions

- historical Phase 0 results remain valid evidence only for their measured
  HTTP/1.1 scenarios;
- the existing package READMEs need no numeric benchmark additions.

## Work Items

- [x] Reserve task 21 and confirm the documentation-only scope.
- [x] Update the root README with a direct historical benchmark link.
- [x] Run focused documentation and whitespace validation.
- [x] Review the diff and record the outcome.

## Validation

Completed on 2026-08-17:

- Markdown lint passed for the changed README/task scope;
- direct relative-link target checks passed for `docs/benchmarks.md` and task
  references;
- `git diff --check` and trailing-whitespace checks passed;
- package README scan found no benchmark, latency, throughput, or performance
  claims.

## Next Action

Maintainer review the documentation diff. No benchmark rerun or publication is
required.

## Blockers

None.

## Outcome

Completed. The root README now links the historical benchmark disclaimer to
`docs/benchmarks.md` and its linked result summaries. Numeric benchmark data
remains outside package READMEs, and no performance claim was added.

## References

- `README.md`
- `docs/benchmarks.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `packages/alphax/README.md`
- `packages/alphax_native/README.md`
- `packages/alphax_dio/README.md`
- `packages/alphax_test/README.md`

## History

- 2026-08-17: Reserved task 21 for the approved benchmark-documentation
  traceability improvement.
- 2026-08-17: Added the root README link and completed Markdown, link,
  whitespace, and package-claim checks.
