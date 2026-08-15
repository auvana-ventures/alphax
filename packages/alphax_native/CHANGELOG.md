# Changelog

## Unreleased (0.1.0 pre-release)

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
- Added release-hardening documentation for system-managed proxy behavior,
  cross-origin redirect credential stripping, and the 1.0 platform matrix.
