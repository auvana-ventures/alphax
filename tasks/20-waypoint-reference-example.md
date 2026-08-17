# Waypoint Reference Example

Status: [x] Completed

## Goal

Build a polished, original Flutter reference application named Waypoint that
demonstrates AlphaX through a coherent travel-planning experience rather than
through disconnected API buttons. The example must use released AlphaX APIs,
remain safe to run without credentials, and give package users a clear path
from installation to a realistic UI integration.

## Scope and Non-goals

Scope:

- add `examples/waypoint` as a real Flutter host application;
- provide a mobile-first and desktop-responsive Waypoint UI;
- demonstrate trips, discovery, itinerary, live activity, file transfers, and
  transport diagnostics;
- keep data access behind a repository/data-source boundary;
- provide deterministic demo data and an opt-in local network fixture path;
- demonstrate `alphax`, `alphax_native`, `alphax_dio`, and `alphax_test` without
  changing their public APIs;
- add focused widget, repository, and fixture tests;
- update relevant documentation with simple, non-technical setup instructions.

Non-goals:

- no new public AlphaX APIs;
- no transport architecture changes or performance benchmarking;
- no authentication, real booking, payments, maps, push notifications, or
  production backend;
- no external credentials, real certificate pins, or production endpoints;
- do not replace or remove `examples/basic`, which remains the minimal API
  smoke test;
- do not publish packages, create a tag, or create a release.

## Owner

Codex coordinator with maintainer review required before release publication.

## Dependencies

- AlphaX 1.0.0-rc.1 public contracts and existing package boundaries;
- `alphax_native` platform transport factory and capability reporting;
- `alphax_dio` focused Dio adapter boundary;
- `alphax_test` deterministic transport helpers;
- Flutter SDK and the existing package workspace;
- Mobbin travel-planning patterns used only as UX inspiration.

## Assumptions

- the existing four-package RC publication set remains unchanged;
- Waypoint can use the existing public APIs without extending the frozen API;
- demo mode is the default so a new user can launch the UI without a server;
- local network mode is opt-in and uses deterministic fixtures, never benchmark
  or production endpoints;
- the bundled `fixture_server/server.dart` is only a local/demo integration
  server and is not a production backend;
- one cohesive reference application is sufficient for all four packages;
- the app will use original visual design, copy, and assets rather than copied
  Mobbin branding or screen artwork.

## Work Items

- [x] Reserve task 20 and confirm the app scope against the repository contract.
- [x] Create the Waypoint Flutter host project and package dependencies.
- [x] Implement domain models, data sources, repositories, and deterministic
  demo fixtures.
- [x] Implement the Waypoint UI shell and feature screens.
- [x] Wire native AlphaX and Dio-compatible data-source configurations.
- [x] Add transport diagnostics, streaming, cancellation, and file-transfer
  demonstrations.
- [x] Add widget, repository, and fixture tests.
- [x] Update package/example documentation with beginner-friendly instructions.
- [x] Review the combined diff and run consolidated validation.

## Validation

Completed on 2026-08-17:

- `dart format lib test fixture_server` — passed for 22 Dart files;
- `flutter analyze` — no issues found;
- `flutter test` — all 9 tests passed, including widget navigation, Dio
  streaming cancellation, split UTF-8 decoding, failed-transfer rejection,
  and deterministic `alphax_test` fixtures;
- `flutter build bundle --debug --target lib/main.dart` — passed;
- `flutter build apk --debug` — passed;
- `flutter build ios --debug --no-codesign` — passed;
- `flutter build macos --debug` — passed;
- `xcodebuildmcp macos build --workspace-path macos/Runner.xcworkspace
  --scheme Runner --configuration Debug --extra-args
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` — passed;
- bundled fixture server curl checks for home, search, NDJSON activity, upload,
  and protocol probe — passed;
- Markdown lint/link checks and `git diff --check` — passed;
- security audit found no signing credentials, `DEVELOPMENT_TEAM`, private-key
  material, machine-specific paths, or production/test endpoints in defaults;
- broad transport performance benchmarks were intentionally not rerun.

## Next Action

Maintainer review the Waypoint reference app and documentation diff. No
publication, tag, release, or transport benchmark is part of this task.

## Blockers

None.

## Outcome

Completed. Added one cohesive, original Flutter reference app rather than
several disconnected package demos. Waypoint starts offline in deterministic
demo mode and includes a bundled opt-in fixture server for network-mode
integration. Its repository/data-source boundary demonstrates direct AlphaX,
the `AlphaXDioAdapter`, native transport selection, protocol preference versus
requirement, completion-time protocol reporting, capabilities, cancellation,
streaming/backpressure, progress callbacks, and file transfers. The UI uses a
responsive desktop/mobile shell with Trips, Discover, Live Activity, and
Transport Lab screens. Package and root READMEs now point beginners to
Waypoint while preserving `examples/basic` as the minimal smoke test.

The focused review also resulted in incremental UTF-8 decoding, genuine Dio
response streaming, failed-transfer checks, narrow-phone layout handling, and
truthful demo-mode TLS/proxy labels. No AlphaX public API or transport
architecture was changed.

## References

- `PROJECT_CONTEXT.md`
- `docs/architecture/overview.md`
- `docs/architecture/transport_contract.md`
- `packages/alphax/README.md`
- `packages/alphax_native/README.md`
- `packages/alphax_dio/README.md`
- `packages/alphax_test/README.md`
- `examples/basic/README.md`
- `https://mobbin.com/flows/032b47c1-3ad5-4051-8600-e8a50fea2786`
- `https://mobbin.com/flows/94014eb5-84cb-436c-882c-8cc2c3ac4a2e`
- `https://mobbin.com/flows/54b23081-11b3-43a4-a3b7-098297d7e2a9`

## History

- 2026-08-16: Reserved task 20 after maintainer approval of the Waypoint
  reference-app recommendation.
- 2026-08-17: Completed implementation, review fixes, host builds, fixture
  checks, documentation checks, and security audit; waiting for maintainer
  review.
