# AlphaX Repository Instructions

Before architectural work:

1. Read `PROJECT_CONTEXT.md`.
2. Read `docs/architecture/overview.md` and the relevant contract document.
3. Read the relevant ADRs.
4. Read the affected PRD and package README.

Rules:

- Implement Phase 0 only unless a task explicitly expands scope.
- Benchmark before optimizing or selecting a native transport.
- Keep `alphax` pure Dart and transport-independent.
- Do not add `alphax_flutter` until Flutter-only integration exists.
- Do not introduce unnecessary dependencies or a Rust-plus-C++ stack without
  measured justification and an accepted ADR.
- Avoid moving large payloads repeatedly across FFI.
- Never silently retry unsafe HTTP mutations.
- Preserve secure TLS defaults and redact credentials/body data in diagnostics.
- Add tests for public behavior and benchmarks for transport-sensitive changes.
- Update README/docs whenever public API, platform support, package status,
  architecture, or performance claims change.
- Never describe planned capabilities as implemented.
- Record major architecture decisions as ADRs.
- Keep package boundaries independently publishable.
