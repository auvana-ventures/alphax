# Changelog

## 1.0.0-rc.1 - 2026-08-17

- Added a deterministic fake AlphaX transport with delayed responses, failures,
  cancellation, request recording, streamed events, and file fixtures.
- Added reusable transport conformance tests for adapter packages.
- Added lazy fixture-URI resolution so the same conformance suite can run
  against deterministic local adapter servers.
- Added focused release-gate fixtures without adding a transport dependency.

The package provides deterministic test utilities only and is not a production
transport.
