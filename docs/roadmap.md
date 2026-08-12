# Roadmap

## Phase 0 — Research

Repository, contracts, ADRs, Dart/libcurl/Rust prototypes, deterministic benchmark
infrastructure, and evidence-based transport selection.

## Phase 1 — Core transport MVP

Reliable core client, H1/H2, pooling and reuse, streaming, cancellation/timeouts,
direct file transfer, and baseline metrics.

## Phase 2 — Compatibility and platforms

Dio adapter, Retrofit validation, desktop/mobile platforms, web-compatible transport,
multipart, proxy/certificate support, and expanded tests.

## Phase 3 — Advanced transport

HTTP/3/QUIC, stronger backpressure, priorities, deduplication/coalescing, expanded
metrics, and scoped WebSocket/SSE where justified.

## Phase 4 — Production modules

Standards-aware cache, resilience/circuit breaker, DevTools, OpenTelemetry, security
hardening, and stable documentation.

## Phase 5 — Optional experiments

Offline queue/resumable metadata and Cronet/URLSession comparisons. Adopt alternate
transports only when measured gains justify the maintenance and binary cost.

## Stable 1.0 gate

Public API stability, supported-platform CI, security reporting, migration policy,
reproducible benchmarks, documentation/examples, cancellation/resource tests, and
binary-size reporting.
