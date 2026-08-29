# Changelog

## 1.0.0-rc.3 - 2026-08-29

- Added the optional pure-Dart `decodeJson` helper for explicit one-shot JSON
  decoding and caller-supplied transforms on native Dart isolates.
- Added normalized AlphaX cancellation/discard behavior, honest JSON/transform
  error forwarding, and fail-closed Web behavior.
- Documented isolate sendability, buffered-input ownership, measured usage
  guidance, and the absence of automatic thresholds, streaming parsing, or
  persistent workers.
