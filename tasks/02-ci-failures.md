# GitHub Actions CI Failures

Status: [x] Completed

## Goal

Restore a green GitHub Actions CI run on the default branch by fixing the
reproducible Dart package-analysis and Linux libcurl compilation failures.

## Scope and Non-goals

Scope:

- Make CI resolve and analyze each independent Dart package from its package root.
- Run benchmark contract and harness tests in the Dart CI job.
- Make the libcurl C prototype expose the required POSIX mutex API on Linux.
- Validate the affected checks locally and verify the pushed GitHub run.

Non-goals:

- No public AlphaX API or transport behavior changes.
- No production transport selection, C++ engine, pub.dev publication, or Phase 1 work.
- No unrelated workflow redesign.

## Owner

Codex, with maintainer review of the CI change.

## Dependencies

- GitHub Actions on `origin/main`.
- Dart stable, libcurl development headers, and a POSIX C11 compiler.

## Assumptions

- Nested benchmark and prototype packages are intentionally independent from the
  root Dart workspace.
- POSIX feature visibility must be defined before system headers are included.
- Existing local package scripts remain the source of truth for package checks.

## Work Items

- [x] Inspect failed GitHub Actions runs and identify root causes.
- [x] Add explicit nested Dart package resolution and analysis to CI.
- [x] Add benchmark contract/harness tests to the Dart CI job.
- [x] Fix Linux POSIX mutex feature visibility in the libcurl prototype.
- [x] Run affected local validation and review the task-owned diff.
- [x] Commit, push, and verify a green GitHub Actions run.

## Validation

Passed locally on 2026-08-12:

- `dart format --set-exit-if-changed .`
- `tooling/scripts/analyze_dart_packages.sh`
- `tooling/scripts/test_packages.sh`
- `tooling/scripts/validate_packages.sh` with zero warnings.
- `tooling/scripts/analyze_prototypes.sh`
- `tooling/scripts/test_benchmark_contract.sh`
- `tooling/scripts/test_benchmark_harness.sh`
- `make -C prototypes/libcurl_ffi test`
- Rust `cargo test` and release build.
- `git diff --check`.
- GitHub Actions CI run 31611116051 on commit `6ccec32`: all jobs passed.

## Next Action

Review the focused CI fix; no further implementation action remains.

## Blockers

None currently.

## Outcome

The CI workflow now analyzes each independent Dart package from its own package
root, tests the benchmark packages, and compiles the libcurl prototype on Linux
with POSIX 2008 feature visibility enabled before system headers. Local CI-equivalent
validation passed. GitHub Actions run 31611116051 passed on all Dart and native
jobs. The fix does not change public APIs, transport selection, or the no-C++
Phase 0 architecture.

## References

- `.github/workflows/ci.yml`
- `tooling/scripts/analyze_dart_packages.sh`
- `prototypes/libcurl_ffi/native/alphax_curl.c`
- Failed run: https://github.com/auvana-ventures/alphax/actions/runs/31610293083
- Passing run: https://github.com/auvana-ventures/alphax/actions/runs/31611116051

## History

- 2026-08-12: Latest CI run failed because root analysis did not resolve nested
  package URIs and Ubuntu lacked POSIX feature visibility for recursive mutex APIs.
- 2026-08-12: Added per-package Dart analysis/bootstrap, benchmark tests to CI, and
  POSIX 2008 feature visibility for the libcurl C prototype. Local CI-equivalent
  validation passed; pushed for GitHub verification.
- 2026-08-12: Commit `6ccec32` passed GitHub Actions run 31611116051 across Dart,
  Ubuntu native, and macOS native jobs.
