# AlphaX Phase 1A API review

Status: Phase 1A implementation complete; maintainer review required before
Phase 1B.

Phase 1A only stabilizes pure-Dart, transport-independent contracts. It does not
implement Dart IO, Cronet/HttpEngine, URLSession, FFI, a C++ engine, or any
deferred feature. H2/H3 are represented as future protocol/capability outcomes;
the package makes no H2/H3 support claim at this stage.

## 1. Public API inventory

The reviewed inventory is in
[`phase1a-public-api-inventory.md`](phase1a-public-api-inventory.md). The public
entry point is `packages/alphax/lib/alphax.dart`. It exports typed methods,
immutable request/response models, body/file abstractions, protocol and
capability models, lifecycle/error primitives, middleware, progress, and metrics.

`alphax_test` exports a fake transport, in-memory file fixtures, and a reusable
conformance-test definition function.

## 2. Body and stream model

Request bodies cover empty, bytes, text, JSON, single-use/replayable streams,
file sources, and multipart parts. Buffered bodies own immutable bytes. Stream
bodies declare replayability and reject a second open when single-use. Multipart
parts are emitted sequentially, so a transport does not need to buffer the full
body.

Response bodies can be buffered or single-consumption streams. Buffered bodies
support repeated byte/text/JSON reads. Streamed bodies expose one stream and
reject a second consumer. `AlphaXEvent` provides an explicit start/chunk/
completion lifecycle for transports that need bounded streaming control.

## 3. Cancellation semantics

`AlphaXCancellationToken` is idempotent and exposes `whenCancelled`. A token is
checked before transport dispatch and is carried through upload, response, and
file operations. Transport adapters must connect it to setup, active transfer,
paused stream, and cleanup cancellation. Closing a client marks it closed before
delegating to the transport; the transport owns cancellation of its in-flight
native work and must make close idempotent.

## 4. Timeout semantics

The portable categories are `connect`, `request`, `read`, and `overall`.
`connect` covers DNS/socket/TLS establishment; `request` covers dispatch through
response headers including upload; `read` covers response-body inactivity; and
`overall` covers the full operation. An adapter may leave a category unset when
its provider cannot map it precisely. The contract forbids inventing phase
metrics or silently mapping one phase to another.

## 5. Error taxonomy

`AlphaXException` normalizes DNS, connection, TLS, timeout, cancellation,
protocol, redirect, request-body, response-body, unsupported-capability, and
transport/internal failures. Platform exceptions and native codes can remain as
optional diagnostic causes, but are not the primary application-facing type.

## 6. Capability model

`AlphaXCapabilities` reports `supported`, `unsupported`, or `unknown` for H1,
H2, H3, streaming upload/download, native file paths, progress, proxy
configuration, certificate pinning, mTLS, connection migration, background
transfer, and actual protocol reporting. Capability is discovery only; a
response's negotiated protocol remains authoritative. Unsupported optional
behavior must be reported or fail with `AlphaXUnsupportedCapabilityException`.

## 7. Protocol model

`AlphaXProtocolPreference` records caller intent. `AlphaXProtocol` records the
actual `http10`, `http11`, `http2`, `http3`, or `unknown` result. A
`AlphaXProtocolFallback` explicitly records preference, actual protocol, and
reason. H3 preference followed by H2 negotiation therefore reports H2, never H3.

## 8. Middleware semantics

Middleware enters in registration order and unwinds in reverse order. Each
operation receives an immutable request and a per-operation next handler. A
middleware may pass `copyWith`, short-circuit, or transform an error with
`try`/`catch`. Buffered, streaming, upload, and download operations have separate
next-handler types. A middleware must not replay a single-use body accidentally;
retry/auth/cache/telemetry/resilience behavior is intentionally absent.

## 9. Conformance-test architecture

`defineAlphaXTransportConformanceTests` creates isolated tests for response
dispatch, stream event ordering, pre-cancelled requests, idempotent close, and
default bounded file transfer. Adapter packages can pass a fresh factory and run
the same suite:

```text
DartIoTransport  ─────┐
CronetTransport  ─────┼── alphax_test conformance suite
URLSessionTransport ──┘
```

The fake also covers predefined responses, delayed operations, failures, request
recording, progress-aware file upload, and in-memory file destinations.

## 10. Known API risks

- Platform providers differ in timeout granularity, redirect details, proxy
  configuration, and whether connection reuse is observable.
- A native adapter must preserve bounded stream backpressure while converting
  callbacks into a Dart `Stream`.
- Native file-backed operations may complete without delivering all body bytes
  through Dart, so metrics and progress must identify unavailable values rather
  than infer them.
- Multipart content length can be unknown for non-replayable or unknown-length
  file parts.
- The compatibility aliases for the Phase 0 names should be removed only through
  a separately reviewed breaking-change policy.

## 11. Unresolved questions before DartIoTransport

- Which Dart IO implementation boundary will provide file targets without making
  `alphax` depend on `dart:io`?
- Which response-stream pause/resume guarantees can `HttpClient` provide across
  connection reuse and cancellation?
- Which timeout phases can Dart IO measure without overstating DNS/TLS
  boundaries?
- How should the first platform adapter expose provider-specific proxy and TLS
  options through a future transport-neutral configuration model?
- What conformance fixtures will verify actual ALPN/H3 fallback on physical
  Android and Apple devices?

## 12. Proposed breaking changes to Phase 0 contracts

The Phase 0 scaffold accepted string methods, buffered-only response bytes, a
single total timeout, and no capability/file contract. Phase 1A intentionally
replaces those as the production shape with typed methods, body abstractions,
phase-specific timeouts, actual protocol reporting, capabilities, middleware,
and file operations. Compatibility aliases remain for `AlphaXBody`,
`AlphaXTimeout`, `AlphaXConnectException`, and `AlphaXCancelledException` where
they do not weaken the new contract.

No native transport was started. No H2/H3 support claim was added. Maintainer
review is required before Phase 1B or any platform-specific implementation.
