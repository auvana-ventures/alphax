# ADR-0005: Completion-time protocol metadata

Status: Accepted

## Context

The Phase 1A response contract exposed protocol metadata with response headers.
That is sufficient for transports that know the negotiated protocol at response
start, but Apple URLSession exposes authoritative protocol information through
task metrics at operation completion. Treating an initial unknown value as
HTTP/1.1 or as fallback would make the public contract inaccurate.

Streaming callers also need a terminal representation of the final protocol and
preferred-protocol fallback without depending on URLSession, Cronet, or Dart IO
types.

## Decision

Keep response-start protocol metadata best-effort and transport-neutral:

- `AlphaXProtocol.unknown` is valid at request start and response headers;
- `AlphaXResponse.completionMetrics` is the authoritative final metrics future;
- `AlphaXResponse.completionProtocolFallback` is the corresponding final
  preference-mismatch future;
- `AlphaXResponseCompleted` carries final metrics, the retained preference, and
  final fallback metadata for streaming consumers; and
- a transport may report a known protocol earlier when it can prove it.

Unknown never means HTTP/1.1, H2, H3, or fallback. A final fallback is emitted
only when a concrete preference differs from a known negotiated protocol. When
the transport cannot identify the precise cause, the fallback reason is
`AlphaXProtocolFallbackReason.unknown`.

## Compatibility and migration

This is an additive change to the pure-Dart `alphax` contract. Existing
response fields and synchronous consumers remain source-compatible. Callers
that require authoritative protocol information after a streamed/native
operation should await `completionMetrics` and, when needed,
`completionProtocolFallback`; streaming callers should inspect
`AlphaXResponseCompleted`.

No native type, Flutter dependency, buffering requirement, or transport-specific
public symbol is introduced. Dart IO can retain unknown protocol metadata when
it cannot observe negotiation; Cronet and URLSession may provide final values
when their providers expose them.

## Consequences

- Protocol reporting is truthful across transports with different observation
  timing.
- Consumers must handle an unknown response-start protocol explicitly.
- Completion futures remain pending until the operation reaches its natural
  terminal state or fails with a normalized error.
- Release claims still depend on platform/provider validation; this ADR does
  not claim global H1/H2/H3 support.

## Revisit

Revisit only if a supported production transport can provide authoritative
protocol metadata at a portable earlier lifecycle point, or if a later API
requires richer protocol diagnostics than the transport-neutral fallback model
can represent.
