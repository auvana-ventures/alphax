# ADR-0002: Benchmark Before Selecting a Native Transport

- Status: Accepted for Phase 0
- Date: 2026-08-12

## Context

Native stacks have different protocol support, memory behavior, binary costs, build
complexity, and maintenance burdens. Request latency alone is not a sufficient
product decision criterion.

## Decision

Phase 0 compares a properly configured Dart `dart:io` baseline, libcurl through an
FFI prototype, and a Rust reqwest/hyper prototype on macOS and Linux. Equivalent
scenarios, network profiles, correctness checks, and environment metadata must be
used. Cronet and URLSession are later experiments, not first-phase requirements.

The selection score considers real-world performance, streaming/file transfer,
memory, protocols, cross-platform consistency, maintainability, binary size,
build/CI complexity, security ecosystem, and contributor accessibility.

## Consequences

Phase 0 takes longer than choosing a stack by preference, but prevents unsupported
performance claims and makes binary and maintenance tradeoffs visible. The
production native package remains experimental until the transport decision ADR is
accepted.

## Revisit conditions

Revisit the candidate set if a platform requirement or measured workload exposes a
candidate that the initial comparison cannot represent fairly.
