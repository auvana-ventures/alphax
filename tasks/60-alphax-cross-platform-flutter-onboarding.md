# Task 60: Clarify cross-platform Flutter package selection

Status: [x] Completed

## Goal

Explain how one Flutter project targeting native platforms and Web selects the
appropriate AlphaX deployment package without making users mistake `alphax`
for the platform provider package.

## Scope and Non-goals

Scope is limited to a concise root/core README example and documentation
validation. Non-goals are runtime behavior, public APIs, package boundaries,
dependency changes, version changes, publication, and transport changes.

## Owner

AlphaX maintainers / Codex implementation agent.

## Dependencies

- Stable AlphaX 1.0.0 package family.
- Existing `alphax_native` and `alphax_web` entry façades.

## Assumptions

- Native Flutter uses `alphax_native`.
- Flutter Web uses `alphax_web`.
- A cross-platform Flutter application may declare both and hide selection
  behind an app-local conditional import.
- Existing protected benchmark/mobile/history changes remain untouched.

## Work Items

- [x] Add a cross-platform Flutter package-selection example to the root README.
- [x] Add the same essential guidance to the core package README used on pub.dev.
- [x] Validate the documented factory signatures, formatting, links, and diff.

## Validation

- [x] `dart format` check for the documented Dart example.
- [x] Markdown/internal-link validation.
- [x] `git diff --check`.
- [x] Confirm no runtime source, API, dependency, version, or publication changes.

## Next Action

No further implementation is required. The README guidance is ready for
maintainer review.

## Blockers

None.

## Outcome

Completed. The root and core READMEs now explain that a single Flutter project
targeting native and Web uses both deployment packages behind a conditional
app-local entry point, while shared code uses one normalized client factory.

## References

- `README.md`
- `packages/alphax/README.md`
- `packages/alphax_native/lib/src/alpha_x_client_factory.dart`
- `packages/alphax_web/lib/src/alpha_x_client_factory.dart`

## History

- 2026-08-31: Created and completed as a focused documentation clarification;
  no runtime or package behavior changed.
