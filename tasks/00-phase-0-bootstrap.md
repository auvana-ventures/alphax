# Phase 0 Repository Bootstrap

Status: [x] Completed

## Goal

Bootstrap the public AlphaX monorepo and implement the minimum transport-independent
Dart contracts, testing foundation, documentation, and reproducible macOS/Linux
transport-prototype scaffolding required by the approved Phase 0 specification.

## Scope and Non-goals

Scope:

- Create the `alphax` public monorepo structure with Apache-2.0 licensing.
- Preserve the working name and initial package set: `alphax`, `alphax_native`,
  `alphax_dio`, and `alphax_test`.
- Copy all 12 PRDs into `docs/prd/`.
- Implement the initial pure-Dart request, response, transport, cancellation,
  timeout, metrics, protocol, and error contracts.
- Add deterministic contract tests and a fake transport package.
- Add macOS/Linux Dart, libcurl/FFI, and Rust benchmark prototype foundations.
- Add CI for Dart quality, package validation, and native prototype build/test.

Non-goals:

- Publishing packages to pub.dev before AlphaX naming clearance.
- Creating `alphax_flutter` or other future packages.
- Selecting a production native transport before benchmark evidence and an ADR.
- Implementing the complete Dio adapter, cache, resilience, offline, DevTools, or
  telemetry modules.

## Owner

Codex, with maintainer review required for public API and transport decisions.

## Dependencies

- Dart SDK `>=3.8.0 <4.0.0`.
- Rust toolchain for the Rust HTTP prototype.
- libcurl development headers/library for the libcurl prototype.
- GitHub organization access for creating `auvana-ventures/alphax`.

## Assumptions

- The repository is public, but packages remain unpublished during Phase 0.
- `alphax` is pure Dart and is usable by Flutter applications without a Flutter
  dependency.
- Phase 0 native validation targets macOS and Linux; Android, iOS, and Windows
  follow transport selection.
- Make is used for the libcurl prototype because CMake is not currently available.
- The original `prd/` directory is retained as source input and duplicated under
  `docs/prd/` as the repository source-of-truth copy.

## Work Items

- [x] Inspect workspace, toolchains, and GitHub repository state.
- [x] Create root governance, workspace, documentation, and CI files.
- [x] Create the four package skeletons and initial package metadata.
- [x] Implement and test the `alphax` transport-independent contracts.
- [x] Implement `alphax_test` deterministic fake transport helpers.
- [x] Add Dart, libcurl/FFI, and Rust benchmark prototype foundations.
- [x] Review the combined task-owned diff and fix blocking findings.
- [x] Run consolidated Dart, package, documentation, and native validation.
- [x] Create the public GitHub repository without publishing packages.

## Validation

Executed validation:

- `dart format --set-exit-if-changed .` — passed.
- `dart analyze` — passed with no issues.
- `tooling/scripts/test_packages.sh` — all four package suites passed.
- `tooling/scripts/validate_packages.sh` — all four packages passed `dart pub publish --dry-run`;
  no package was published.
- `tooling/scripts/analyze_prototypes.sh` — both Dart FFI harnesses passed.
- `make -C prototypes/libcurl_ffi test` — macOS shared-library build and smoke test passed.
- `cargo test --manifest-path prototypes/rust_http/Cargo.toml` — passed.
- `cargo build --release --manifest-path prototypes/rust_http/Cargo.toml` — passed.
- Deterministic server runtime smoke — Dart, libcurl/FFI, and Rust/FFI clients returned
  matching 200 responses and 1024-byte bodies on macOS.
- `bash -n tooling/scripts/*.sh benchmarks/scripts/run-local.sh` — passed.
- GitHub repository verification — public `auvana-ventures/alphax` created successfully.

Linux native execution remains delegated to the configured GitHub Actions matrix because
the current workspace is macOS; the workflow installs Linux libcurl headers and runs the
same Make/Cargo checks on `ubuntu-latest`.

## Next Action

Maintainer review and explicit authorization are required before creating the initial
commit and pushing the local worktree to `origin`.

## Blockers

None currently.

## Outcome

Phase 0 repository bootstrap is complete locally. The public GitHub repository exists at
https://github.com/auvana-ventures/alphax, with no commit pushed and no pub.dev package
published. The initial contract API, test helpers, docs, CI, deterministic server, and
macOS/Linux prototype paths are ready for review.

## References

- `prd/01_PRODUCT_VISION.md` through `prd/12_PHASE_0_IMPLEMENTATION_SPEC.md`
- `prd/12_PHASE_0_IMPLEMENTATION_SPEC.md`, sections 4–32

## History

- 2026-08-12: Created after approval of AlphaX name, Apache-2.0 license, pure-Dart
  Phase 0 core, and macOS/Linux native prototype scope.
- 2026-08-12: Completed local bootstrap, validation, and public repository creation;
  intentionally left commit/push and pub.dev publication pending explicit authorization.
