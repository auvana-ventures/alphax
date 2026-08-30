# Changelog

## 1.0.0 - 2026-08-30

- First stable release of the package:http compatibility bridge, preserving
  streamed mapping and borrowed AlphaXClient ownership from rc.5.

## 1.0.0-rc.5 - 2026-08-30

- Finalized `AlphaXHttpClient` as the coordinated rc.5 `package:http`
  compatibility seam for Chopper, GraphQL HTTP, generated clients, and other
  injectable `http.Client` consumers.
- Preserved streamed request/response behavior, borrowed-client ownership, and
  standard package:http status/error semantics without adding framework-specific
  runtime dependencies.

## 1.0.0-rc.4 - 2026-08-30

- Added the AlphaX-backed `package:http` `BaseClient` compatibility seam.
