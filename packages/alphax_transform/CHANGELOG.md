# Changelog

## 1.0.0 - 2026-08-30

- First stable release of the optional one-shot JSON transform package; its
  explicit buffered isolate contract is unchanged from rc.5.

## 1.0.0-rc.5 - 2026-08-30

- Coordinated the optional one-shot transform package with the final rc.5
  package family; its transform contract and runtime behavior remain unchanged
  after rc.4.
- Revalidated that large JSON transformation remains explicit, buffered, and
  separate from the frozen transport and streaming contracts.

## 1.0.0-rc.4 - 2026-08-29

- Prepared the first coordinated RC publication of the optional pure-Dart
  `decodeJson` helper for explicit one-shot JSON
  decoding and caller-supplied transforms on native Dart isolates.
- Preserved explicit sendability, cooperative cancellation/discard semantics,
  and fail-closed Web behavior.
- Documented buffered-input ownership and the absence of automatic thresholds,
  streaming parsing, and persistent workers.
