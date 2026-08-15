# Changelog

## Unreleased (0.1.0 pre-release)

- Added a deterministic fake AlphaX transport with delayed responses, failures,
  cancellation, request recording, streamed events, and file fixtures.
- Added reusable transport conformance tests for future adapter packages.
- Added lazy fixture-URI resolution so the same conformance suite can run
  against deterministic local adapter servers.
- Added focused release-gate fixtures without adding a transport dependency.
