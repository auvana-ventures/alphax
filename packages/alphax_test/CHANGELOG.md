# Changelog

## 1.0.0-rc.3 - 2026-08-17

- Added a runnable example showing deterministic AlphaX requests with
  `FakeAlphaXTransport`, response assertions, and request recording.

## 1.0.0-rc.2 - 2026-08-17

- Corrected the theme-aware README logo URLs to absolute repository assets so
  pub.dev and other Markdown renderers load both SVG variants.

## 1.0.0-rc.1 - 2026-08-17

- Added a deterministic fake AlphaX transport with delayed responses, failures,
  cancellation, request recording, streamed events, and file fixtures.
- Added reusable transport conformance tests for adapter packages.
- Added lazy fixture-URI resolution so the same conformance suite can run
  against deterministic local adapter servers.
- Added focused release-gate fixtures without adding a transport dependency.

The package provides deterministic test utilities only and is not a production
transport.
