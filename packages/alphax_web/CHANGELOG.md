# Changelog

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
