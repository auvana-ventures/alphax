# Changelog

## 1.0.0-rc.5 - 2026-08-30

- Added the concise browser-backed `createAlphaXClient()` façade while
  retaining explicit `WebFetchTransport()` construction.
- Re-exported the ordinary public AlphaX API and exposed the browser
  WebSocket connector through the separate Web deployment boundary.
- Validated SSE over Fetch response streams while keeping TLS, proxy, CORS,
  protocol reporting, and connection behavior browser-owned.

## 1.0.0-rc.4 - 2026-08-29

- Aligned package metadata with the coordinated AlphaX `1.0.0-rc.4` release;
  no runtime changes were made since `rc.3`.

## 1.0.0-rc.3 - 2026-08-17

- Added a browser Fetch example showing a request, response body, and the
  intentionally unknown browser protocol metadata.
- Expanded package metadata to describe the adapter's supported use case.

## 1.0.0-rc.2 - 2026-08-17

- Corrected the theme-aware README logo URLs to absolute repository assets so
  pub.dev and other Markdown renderers load both SVG variants.

## 1.0.0-rc.1 - 2026-08-17

- Added `WebFetchTransport`, an AlphaX transport backed by browser Fetch.
- Added browser response streaming, cancellation through Fetch abort signals,
  overall timeout handling, redirect configuration, and normalized transport
  errors.
- Added truthful Web capability reporting: browser protocol negotiation is
  unknown to Dart and concrete protocol requirements fail closed.
- Documented CORS, browser credential, file, TLS, proxy, upload, and protocol
  limitations.

This package is a separate Web adapter. It does not add browser support to the
pure `alphax` package or the native `alphax_native` plugin.
