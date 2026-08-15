# ADR-0006: Protocol preference versus protocol requirement

Status: Accepted

## Context

AlphaX 1.0 needs to express both “prefer HTTP/3 but allow a provider to use
HTTP/2 or HTTP/1.1” and “do not send this request unless HTTP/3 is actually
negotiated.” A capability snapshot is not proof of the protocol used by one
request, and a preference must not be treated as a requirement.

## Decision

`AlphaXRequest` carries two independent values:

- `protocolPreference` records the protocol a provider should prefer when its
  platform API supports such a hint. It permits fallback. The response retains
  the preference and reports a fallback only from a known final protocol.
- `protocolRequirement` requires the exact protocol. A transport must reject a
  request when the provider cannot support the protocol, when completion-time
  protocol metadata is unknown, or when the observed protocol differs.

The normalized `AlphaXProtocolRequirementException` includes both the required
protocol and the observed protocol, where `unknown` is a valid observed value.
`AlphaXProtocol.unknown` never satisfies a concrete requirement.

The platform adapters do not invent protocol selection mechanisms. Cronet
retains provider-controlled negotiation with H2/QUIC enabled at engine
construction; URLSession maps an H3 preference to its documented
`assumesHTTP3Capable` hint on supported Apple OS versions. Both enforce
requirements against authoritative provider metadata. Dart IO rejects H2/H3
requirements before dispatch because `HttpClient` cannot expose authoritative
negotiated protocol metadata.

## Consequences

- Applications can safely choose fallback or fail-closed semantics.
- H3 preference followed by H2 is a successful request with explicit fallback.
- H3 requirement followed by H2 is a normalized failure.
- Protocol capability, preference, requirement, and actual negotiation remain
  separate public concepts.
- Provider-specific protocol forcing remains outside the public AlphaX API.

## Validation

Pure-Dart and fake-transport tests cover preference/requirement distinction,
unknown completion, and requirement failures. Android and Apple adapters carry
the requirement through the native request and check the final observed
protocol. Release-device H3 requirement checks remain part of focused platform
acceptance, not a benchmark.

## Revisit

Revisit only if a supported provider exposes a portable, authoritative
pre-dispatch protocol guarantee that changes the enforcement boundary.
