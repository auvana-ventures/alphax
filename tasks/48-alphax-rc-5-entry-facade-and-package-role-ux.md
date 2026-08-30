# Task 48 — AlphaX rc.5 Entry Façade and Package-Role UX

Status: [x] Completed

## Goal

Implement the first locked rc.5 feature: an additive Model A+ entry experience
that makes ordinary native Flutter and Web setup materially simpler while
preserving rc.4 APIs, the pure-Dart `alphax` boundary, explicit transport
selection, and custom `AlphaXTransport` injection.

## Scope and Non-goals

In scope:

- audit the exact rc.4 native/Web constructors and package exports before editing;
- design and implement the smallest additive façade in existing integration
  packages;
- provide the native Flutter path `alphax_native façade -> alphax`;
- provide the Web path `alphax_web façade -> alphax` without claiming browser
  protocol/TLS/proxy/file parity;
- preserve explicit concrete transport construction and custom transport
  injection;
- add deterministic API/close/lifecycle tests and compile-tested examples;
- update current-facing package/user documentation for the final API.

Out of scope:

- changing `alphax` into a Flutter-aware or provider-aware umbrella;
- adding `alphax_core`, merging, renaming, or removing published packages;
- changing Cronet/HttpEngine, URLSession, Dart IO, or Fetch transport behavior;
- creating `alphax_http`, SSE, WebSocket, generator, OpenAPI, or other rc.5
  feature work;
- provider-specific Cronet/URLSession fields in the core API;
- hidden per-request client/transport creation;
- performance benchmarking or provider architecture changes.

## Owner

AlphaX maintainers / implementation agent.

## Dependencies

- Accepted [ADR-0011](../docs/decisions/0011-rc5-final-feature-candidate.md).
- Accepted [rc.5 scope lock](../docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md).
- Task 47 Model A+ architecture recommendation.
- Published rc.4 package APIs and the existing native/Web integration packages.

## Assumptions

- rc.4 imports and constructor forms remain source-compatible.
- The façade may re-export core types only when this does not create duplicate
  type identities or ambiguous ownership.
- The selected client/transport is created once per owning application scope and
  closed explicitly or through an unambiguous ownership contract.
- No new package is technically necessary; if dependency isolation proves that
  assumption false, stop for maintainer review before creating one.
- Protected benchmark/mobile/signing work remains untouched and unstaged.

## Work Items

- [x] Reconfirm current public exports, package dependencies, and client lifecycle.
- [x] Choose and document the smallest native/Web façade API.
- [x] Implement the additive façade without changing core transport semantics.
- [x] Add API, lifecycle, close-ownership, and compatibility tests.
- [x] Add compile-tested native/Web quick-start examples and update user docs.
- [x] Run scoped analysis, tests, builds, docs checks, and package dry-runs.
- [x] Review the task-owned diff and request maintainer approval before the next
  locked rc.5 task.

## Validation

Planned validation:

- Dart/Flutter formatting and analysis for affected packages;
- affected package tests and rc.4 compatibility tests;
- native Flutter and Web compile-tested examples;
- available macOS/iOS/Android/Web build checks appropriate to the façade;
- Dartdoc and Markdown/internal-link validation;
- package dry-runs and archive inspection for affected packages;
- dependency/security/path audit;
- `git diff --check` with protected work excluded.

No transport benchmark or broad performance experiment is authorized.

Completed validation:

- `dart format --output=none --set-exit-if-changed` passed for all changed Dart
  files;
- `bash tooling/scripts/analyze_dart_packages.sh` passed;
- `bash tooling/scripts/test_packages.sh` passed all six package suites;
- native and Web clean consumers passed dependency resolution, analysis, and
  compilation with only their deployment package declared directly;
- Android, macOS, iOS (`--no-codesign`), and Web checks passed where available;
- Dartdoc, Markdown/internal-link checks, package dry-runs/archive inspection,
  dependency/security/path audit, and `git diff --check` passed; and
- no benchmark, version, tag, release, or publication operation was performed.

## Next Action

Return for maintainer review. Do not begin Task B or any later rc.5 task.

## Blockers

None.

## Outcome

Implemented and validated the additive native/Web entry façades, one-import
re-exports, lifecycle/error/compatibility tests, clean consumer examples, and
deployment-path documentation. The review record is
[`docs/ALPHAX_RC5_ENTRY_FACADE_REVIEW.md`](../docs/ALPHAX_RC5_ENTRY_FACADE_REVIEW.md)
and concludes `RC5 ENTRY FACADE READY`. No rc.5 package was published.

## References

- [ADR-0011](../docs/decisions/0011-rc5-final-feature-candidate.md)
- [rc.5 scope lock](../docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md)
- [rc.5 architecture plan](../docs/ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md)
- [Task 47](47-alphax-1-0-rc-5-architecture-and-ecosystem-plan.md)
- `packages/alphax/lib/src/alpha_x_client.dart`
- `packages/alphax_native/lib/src/alpha_x_transport_factory.dart`
- `packages/alphax_web/lib/alphax_web.dart`

## History

- 2026-08-30: Reserved Task 48 as the next implementation task for the locked
  rc.5 entry-façade/package-role UX feature. No implementation was started.
- 2026-08-30: Maintainer approved implementation. The task moved to In Progress;
  scope remains limited to the locked native/Web entry façades, compatibility,
  documentation, examples, and validation.
- 2026-08-30: Implemented and validated Task 48. Native and Web façades,
  one-import re-exports, lifecycle/error/compatibility tests, clean consumers,
  examples, and current-facing documentation are complete. Task marked
  Completed; return for maintainer review before Task B.
