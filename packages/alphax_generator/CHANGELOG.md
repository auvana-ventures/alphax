# Changelog

## 1.0.0-rc.5 - 2026-08-30

- Finalized the direct AlphaX typed REST generation contract for common HTTP
  methods, path/query/header bindings, JSON bodies, typed decoding,
  cancellation, request options, multipart/file representations, and honest
  streaming seams.
- Confirmed generated clients call `AlphaXClient` directly, borrow its
  lifecycle, keep serialization caller-owned, and remain independent of Dio,
  Retrofit, and `package:http` at runtime.

## 1.0.0-rc.4 - 2026-08-30

- Added the AlphaX-owned direct typed REST source-generation surface.
