# Changelog

## 1.0.0-rc.4 - 2026-08-29

- Prepared the first coordinated RC publication of the optional pure-Dart
  `decodeJson` helper for explicit one-shot JSON
  decoding and caller-supplied transforms on native Dart isolates.
- Preserved explicit sendability, cooperative cancellation/discard semantics,
  and fail-closed Web behavior.
- Documented buffered-input ownership and the absence of automatic thresholds,
  streaming parsing, and persistent workers.
