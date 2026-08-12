# Contributing to AlphaX

AlphaX is in Phase 0 research. Contributions should keep the transport decision
evidence-based and the public Dart contract independent from any one native stack.

## Before coding

Read `PROJECT_CONTEXT.md`, the relevant PRD, architecture documents, and ADRs. For
work that leaves repository changes, record the scope and validation in a task file
under `tasks/`.

## Development

The supported Phase 0 SDK range is Dart `>=3.8.0 <4.0.0`. The core package has no
Flutter SDK constraint. Use sound null safety, public API documentation, immutable
metadata where practical, and deterministic error semantics.

## Validation

Run the smallest relevant checks during development and the consolidated affected
scope before handoff:

```text
dart format --set-exit-if-changed .
dart analyze
dart test
```

For native prototype changes, also run the relevant Make and Cargo checks described
in `docs/benchmarks.md`.

## Performance and security

Do not publish selective benchmark results or unsupported “Nx faster” and
“zero-copy” claims. Do not log authorization headers or complete bodies by default.
Transport-sensitive changes require reproducible scenarios and raw result metadata.

## Pull requests

Keep changes focused. Update documentation in the same change as public behavior,
platform support, package status, architecture, or performance claims. Do not
publish packages or create releases from Phase 0 work.
