# ADR-0003: Keep the Public API Transport-Independent

- Status: Accepted for Phase 0
- Date: 2026-08-12

## Context

AlphaX may change its native transport or add platform-native implementations. A
public API coupled to libcurl, Rust types, or a particular callback model would make
that change expensive and leak implementation details to applications.

## Decision

The `alphax` package defines immutable request/response metadata, body and header
abstractions, cancellation, timeout, metrics, protocol, error, event, and transport
contracts. Native implementations depend on those contracts rather than exposing
raw library handles or error codes as the primary API.

The contract is deliberately minimal during Phase 0 and must be reviewed before
stabilization. Unsupported metrics use nullable capability semantics.

## Consequences

Future transports can be added behind the same client facade. Some transport-specific
features require capability negotiation or a later contract revision. The initial
API cannot promise every advanced protocol or file-transfer feature.

## Revisit conditions

Revisit only with compatibility analysis, benchmark evidence where performance is
affected, and an ADR describing migration impact.
