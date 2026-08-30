# Changelog

## 1.0.0-rc.5 - 2026-08-30

- Added the one-import `createAlphaXClient()` façade, delegating transport
  selection to the existing native factory while preserving explicit transport
  construction and client-owned close semantics.
- Re-exported the ordinary public AlphaX API and exposed the native
  WebSocket connector alongside the existing Dart IO, Android, Apple, and
  browser-boundary behavior.
- Validated native SSE response-stream parsing and the frozen WebSocket
  lifecycle contract without adding a second networking engine.

## 1.0.0-rc.4 - 2026-08-29

- Corrected Apple URLSession phase-duration conversion so reported
  millisecond metrics are scaled exactly once.
- Hardened Apple URLSession bounded response backpressure, cancellation, and
  completion ordering while preserving the `64 KiB × 4` delivery window and
  `256 KiB` pending bound.
- Improved Apple native-file finalization with
  `FileManager.replaceItemAt` when replacing an existing destination; atomic
  replacement is not claimed.
- Suppressed native progress-event construction and delivery when an operation
  has no progress observer, while retaining authoritative byte accounting.
- Added `createAlphaXTransport()` for automatic Android Cronet/HttpEngine,
  Apple URLSession, and Dart IO selection without adding platform dependencies
  to `alphax` core.

## 1.0.0-rc.3 - 2026-08-17

- Added a runnable example using the Dart IO fallback transport and reading
  completion-time protocol metadata.

## 1.0.0-rc.2 - 2026-08-17

- Corrected the theme-aware README logo URLs to absolute repository assets so
  pub.dev and other Markdown renderers load both SVG variants.

## 1.0.0-rc.1 - 2026-08-17

- Added the platform transport integration boundary.
- Added the Dart IO fallback transport with HTTP/1.1 request/response
  streaming, file transfers, cancellation, timeouts, redirects, progress,
  normalized errors, and reusable-client lifecycle handling.
- Added the Android Cronet/HttpEngine adapter behind a reusable engine with
  actual protocol reporting, bounded response delivery, cancellation,
  progress, and native-capable file paths. Physical-device validation is
  complete for the accepted Phase 1C evidence.
- Added the shared iOS/macOS URLSession adapter with actual task-metric
  protocol reporting, bounded streaming, native file paths, progress,
  cancellation, redirects, and normalized errors. macOS and signed iPhone
  correctness evidence covers H1/H2/H3 and fallback behavior.
- Added release-hardening documentation for secure TLS/pinning, system-managed
  proxy behavior, cross-origin redirect credential stripping, and the 1.0
  platform matrix.

Known limitations are provider-dependent H3 availability, Dart IO H1-only
fallback, unsupported mTLS, selected-provider Android custom trust limits,
unsupported Dart IO SPKI pinning, explicit HTTPS-proxy endpoint parity, and
deferred Swift Package Manager packaging.
