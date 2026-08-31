# Contributing to AlphaX

AlphaX `1.0.0` is the current stable release. Contributions should preserve the
public Dart contract's independence from any one native stack and keep changes
focused on correctness, security, compatibility, documentation, and supported
platform conformance unless a new feature has been explicitly approved.

## Before coding

Read `PROJECT_CONTEXT.md`, the relevant architecture documents, and ADRs. For
work that leaves repository changes, describe the scope and validation in the
issue or pull request. Local maintainer workflow records are not part of the
public repository.

## Development

The supported SDK range is Dart `>=3.8.0 <4.0.0`. The core package has no
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

For native transport changes, also run the relevant platform and package checks
described in the affected package documentation and CI configuration. Historical
benchmark material is retained under `benchmarks/` for maintainers.

## Performance and security

Do not publish selective benchmark results or unsupported “Nx faster” and
“zero-copy” claims. Do not log authorization headers or complete bodies by default.
Transport-sensitive changes require reproducible scenarios and raw result metadata.

## Pull requests

Keep changes focused. Update documentation in the same change as public behavior,
platform support, package status, architecture, or performance claims. Do not
add features or publish stable packages from stabilization work. Package
publication, tags, and releases require their separately authorized release
tasks.
