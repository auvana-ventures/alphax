# AlphaX rc.5 bounded optionals review

Task 53 closes the approved optional rc.5 scope. It adds no runtime package and
does not change the accepted AlphaX architecture. The retained fixtures and
the ecosystem checks are evidence for the existing A–E surfaces, not new
framework integrations.

## 1. F decision

**OPENAPI TEMPLATE PROOF ACCEPTED**.

The proof is intentionally not a full OpenAPI SDK generator. It demonstrates
that the official OpenAPI Generator customization boundary can emit an
AlphaX-owned declaration which the existing `alphax_generator` then compiles
into a direct AlphaX client.

## 2. OpenAPI mechanism

The selected official seam is the Mustache template overlay passed with
OpenAPI Generator's `--template-dir` option. The proof uses the official Dart
generator and overrides only `templates/api.mustache`. This is the supported
custom-template path documented by OpenAPI Generator:

- [customization](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/customization.md)
- [templating](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/templating.md)
- [CLI usage](https://github.com/OpenAPITools/openapi-generator/blob/master/docs/usage.md)

The checked-in proof is in
[`tooling/openapi/alphax_template_proof`](../tooling/openapi/alphax_template_proof)
and is reproducible with OpenAPI Generator CLI `7.24.0`. The script validates
the OpenAPI document, generates into a disposable directory, formats the
declaration, and compares it with the checked-in declaration.

The fixture deliberately uses OpenAPI `3.0.3`. The official Dart generator
handled this version cleanly, and the bounded proof does not need to claim
3.1-specific behavior.

## 3. OpenAPI proof result

The representative fixture covers:

- `GET` and `POST`;
- a path parameter;
- an optional query parameter;
- a required header parameter;
- JSON request and response models; and
- a declared HTTP 404 response which is exercised as an empty nullable result.

The generated path is:

```text
OpenAPI 3.0.3
  → official Mustache template overlay
  → @AlphaXApi declaration
  → alphax_generator/build_runner
  → AlphaXClient → AlphaXTransport
```

The generated declaration and implementation compile and execute against the
deterministic local fixture. A source audit found no Dio, Retrofit, Chopper,
`package:http`, or duplicate AlphaX request generator in the proof output.
Multipart/file generation is not included: adding its policy would be a
separate template effort and remains a 1.1 candidate. The proof is accepted
without that expansion.

## 4. G decision

**PROTOBUF ERGONOMICS DOCUMENTATION SUFFICIENT**.

The existing AlphaX byte APIs are already enough. No Protobuf-specific helper,
annotation, transport behavior, runtime dependency, or `alphax_protobuf`
package was added.

## 5. Protobuf fixture result

[`examples/protobuf_interop`](../examples/protobuf_interop) compiles a small
message using the maintained Dart Protobuf toolchain and validates this direct
mapping:

```text
GeneratedMessage.writeToBuffer()
  → AlphaXBody.bytes
  → AlphaXRequest → AlphaXClient

AlphaX response bytes
  → Message.mergeFromBuffer()
  → GeneratedMessage
```

The fixture used `protobuf 6.0.0`, `protoc_plugin 25.0.0`, and `protoc 33.4`.
Its one deterministic test passed after generation, analysis, and formatting.
Task E's caller-owned body and decoder hooks are sufficient for the same
pattern; no Protobuf-specific annotation is needed.

Protobuf is a serialization format. It does not imply gRPC support. gRPC still
requires an RPC runtime with HTTP/2 framing, metadata, trailers, streaming, and
status semantics and remains post-1.0.

## 6. H compatibility matrix

The status vocabulary below distinguishes first-class AlphaX surfaces from
adapter paths, caller-owned serialization, and bounded proof evidence.

| Ecosystem | Status | Integration path | Validated version | Limitation |
| --- | --- | --- | --- | --- |
| Direct AlphaX | `FIRST_CLASS` | `AlphaXClient` → selected `AlphaXTransport` | Repository rc.5 source | Provider capability differences remain authoritative. |
| AlphaX typed REST generator | `FIRST_CLASS` | AlphaX annotations → `alphax_generator` → `AlphaXClient` | Repository rc.5 source | Serialization remains caller/model-owned. |
| Dio | `SUPPORTED_VIA_ADAPTER` | Dio → `AlphaXDioAdapter` → AlphaX | Dio 5.11.0 | The adapter is the supported Dio boundary, not full Dio API ownership. |
| Retrofit | `SUPPORTED_VIA_ADAPTER` | Retrofit generated client → Dio → `AlphaXDioAdapter` | Retrofit 4.10.0; generator 10.2.9 | Features outside ordinary Dio `fetch` behavior remain generator-specific. |
| `package:http` | `SUPPORTED_VIA_ADAPTER` | `http.Client` consumer → `AlphaXHttpClient` → AlphaX | http 1.6.0 | BaseClient cannot carry all AlphaX metrics, protocol, file, or rich request policy. |
| Chopper | `SUPPORTED_VIA_ADAPTER` | Chopper generated service → injected `AlphaXHttpClient` | Chopper 8.7.0; generator 8.7.0 | Requires Chopper's normal injectable `http.Client` boundary. |
| GraphQL HTTP | `SUPPORTED_VIA_ADAPTER` | `HttpLink` → injected `AlphaXHttpClient` → AlphaX | graphql 5.2.4; gql_http_link 1.2.0 | GraphQL parsing, cache, and GraphQL errors remain GraphQL-owned. |
| GraphQL WebSocket/subscriptions | `PROOF_ONLY` | `TransportWebSocketLink` → caller-owned `WebSocketChannel` bridge → AlphaX session | gql_websocket_link 2.1.0; web_socket_channel 3.0.3 | A small caller bridge is required; no AlphaX GraphQL adapter is shipped. |
| OpenAPI direct AlphaX template | `PROOF_ONLY` | official OpenAPI template → AlphaX declaration → `alphax_generator` | OpenAPI Generator CLI 7.24.0 | Bounded GET/POST proof, not a mature OpenAPI product. |
| OpenAPI-generated Dio client | `SUPPORTED_VIA_ADAPTER` | official `dart-dio` output → injectable Dio → `AlphaXDioAdapter` | OpenAPI Generator CLI 7.24.0; Dio 5.11.0 | Validated fixture uses the normal injectable Dio constructor. |
| OpenAPI-generated `package:http` client | `SUPPORTED_VIA_ADAPTER` | official Dart output → injectable `http.Client` → `AlphaXHttpClient` | OpenAPI Generator CLI 7.24.0; http 1.6.0 | Generated client must expose its normal client setter/constructor. |
| `json_serializable` | `COMPATIBLE_CALLER_LAYER` | Application model hooks used by generated or Retrofit clients | json_serializable 6.14.1 | AlphaX does not own model generation. |
| Freezed | `COMPATIBLE_CALLER_LAYER` | Application model hooks used by generated or Retrofit clients | Freezed 4.0.1 | AlphaX does not own model generation. |
| Protobuf | `COMPATIBLE_CALLER_LAYER` | `writeToBuffer`/`mergeFromBuffer` with AlphaX byte bodies | protobuf 6.0.0; protoc_plugin 25.0.0 | Serialization only; no gRPC behavior. |
| SSE | `FIRST_CLASS` | `AlphaX` response stream → `AlphaXSseParser` | Repository rc.5 source | Reconnect and `Last-Event-ID` remain caller-owned. |
| WebSocket | `FIRST_CLASS` | AlphaX connector/session → maintained provider API | Repository rc.5 source | No automatic reconnect, GraphQL protocol, or frame API. |
| gRPC | `DEFERRED_POST_1_0` | No rc.5 AlphaX integration | Not applicable | The official gRPC runtime remains the future integration boundary. |

## 7. Dio

The existing `alphax_dio` adapter suite remained green. In addition, an
official OpenAPI Generator `dart-dio` output was generated into a disposable
fixture, analyzed, and executed with an injected `Dio` whose
`HttpClientAdapter` was `AlphaXDioAdapter`. GET path/query/header mapping and
typed JSON decoding reached the fake AlphaX transport.

## 8. Retrofit

The retained Task 45 fixture remains the evidence for the Retrofit path. It
used Retrofit `4.10.0`, `retrofit_generator 10.2.9`, and Dio `5.11.0`, and
passed generated GET/POST, DTO, nullable/wrapped response, stream,
cancellation, redirect, multipart, error, and progress coverage through
`AlphaXDioAdapter`. The current `alphax_dio` package suite also passed.

No Retrofit code or AlphaX adapter behavior was changed in Task 53.

## 9. `package:http`

The existing `alphax_http` suite and its generic consumer proof remained green.
The maintained `BaseClient.send(BaseRequest)` seam is sufficient for ordinary
request/response consumers, and the adapter continues to borrow the supplied
AlphaX client rather than creating a client or transport per request.

## 10. Chopper

A disposable fixture generated a Chopper service with
`chopper_generator 8.7.0`, injected `AlphaXHttpClient`, and passed analysis and
tests for GET path/query mapping and JSON response conversion. The earlier
Task B fixture also covered Chopper request/response interceptors. No Chopper
dependency or production-specific code was added to AlphaX.

## 11. GraphQL HTTP

A disposable fixture used `graphql 5.2.4` and `gql_http_link 1.2.0`. Its
`HttpLink` received the injected `AlphaXHttpClient`; the query request reached
the fake AlphaX transport and the GraphQL response was parsed by the GraphQL
link. GraphQL-level data/error ownership remains above AlphaX.

## 12. GraphQL WebSocket

The maintained `gql_websocket_link 2.1.0` transport link exposes
`TransportWsClientOptions.socketMaker`, whose generator returns a
`WebSocketChannel`. A disposable test-only bridge mapped the frozen AlphaX
session's complete text/binary messages and close operation to that channel.
The subscription handshake and one `next` response passed using
`web_socket_channel 3.0.3`.

This is a clean caller-layer seam, but it is not a shipped GraphQL adapter.
Reusable GraphQL-specific lifecycle/auth/reconnect policy remains deferred
post-1.0. The AlphaX WebSocket contract was not changed for this validation.

## 13. OpenAPI existing clients

Both official OpenAPI Generator client families were validated from the same
fixture with CLI `7.24.0`:

- the `dart-dio` output accepted an injected Dio and reached
  `AlphaXDioAdapter`;
- the standard Dart output exposed an injectable `http.Client` and reached
  `AlphaXHttpClient`.

The direct AlphaX template proof is separate from these existing-client
paths. None of these results claims universal support for every generator
configuration or generated transport.

## 14. `json_serializable` and Freezed

The Task E native consumer fixture continued to compile and exercise manual,
`json_serializable`, and Freezed model hooks. Those packages remain caller-side
serialization tooling and are absent from AlphaX runtime dependencies.

## 15. SSE and WebSocket

The existing SSE parser and native/Web response-stream fixtures passed. The
existing core, native, and WebSocket connector suites passed. These are
first-class AlphaX capabilities with their own contracts; no ecosystem
framework behavior was added here.

## 16. gRPC boundary

No gRPC package or integration was added. The Protobuf fixture proves only
serialization to and from AlphaX byte bodies. gRPC remains
`DEFERRED_POST_1_0` and is not implied by the Protobuf result.

## 17. Package impact

No new runtime package was created. The affected tracked additions are:

- one bounded OpenAPI template proof under `tooling/` and its consumer fixture;
- one Protobuf interoperability fixture and recipe;
- this review, the Task 53 record, and freeze/current-facing documentation.

No AlphaX production API, transport, adapter, or dependency graph was changed
for F/G/H.

## 18. Production API changes

None. Existing AlphaX APIs remain the source of truth, including direct
transport injection, `alphax_http`, `alphax_dio`, the SSE sub-library, the
WebSocket contract, and the direct typed REST generator. No helper package was
created for OpenAPI, Protobuf, GraphQL, Chopper, or gRPC.

## 19. Documentation changes

Updated current-facing documentation now records:

- the official OpenAPI template proof and its bounded status;
- the compile-tested Protobuf byte recipe and gRPC boundary;
- explicit ecosystem classifications rather than generic compatibility claims;
- GraphQL HTTP support through `alphax_http` and GraphQL WebSocket caller-layer
  proof with no shipped adapter;
- the final feature-freeze boundary and rc.5 release sequence.

The detailed recipes remain in
[`examples/openapi_template_proof`](../examples/openapi_template_proof) and
[`examples/protobuf_interop`](../examples/protobuf_interop).

## 20. Validation

The final consolidated validation completed after the Task 53 batch:

- Dart formatting and analysis for all eight workspace packages;
- all eight current package test suites;
- OpenAPI spec validation, official template generation, AlphaX declaration
  compilation, and deterministic runtime fixture;
- Protobuf generation, formatting, analysis, and byte round-trip test;
- Dio and Retrofit compatibility evidence;
- package:http, Chopper, GraphQL HTTP, and generic consumer fixtures;
- GraphQL WebSocket test-only channel bridge proof;
- typed generator, SSE, WebSocket, and model compatibility fixtures;
- Dartdoc with link validation for touched public packages;
- package dry-runs and archive inspection for affected packages;
- Markdown/internal-link, dependency, security/path, generated-artifact, and
  protected-work audit;
- `git diff --check`.

The affected publishable package `alphax` dry-run reported a 66 KB compressed
archive and contained no Task 53 fixture or build output. The new OpenAPI and
Protobuf fixtures are `publish_to: none` examples rather than independently
published packages. The archive listing was inspected for local paths,
secrets, `.dart_tool`, and build output.

No performance benchmark, new platform feature, package publication, or tag was
run or created. The unrelated pre-existing benchmark/release worktree changes
were excluded from Task 53 commits.

## 21. Final rc.5 scope state

Terminal decisions are recorded as:

| Item | Decision |
| --- | --- |
| A | Complete |
| B | Complete |
| C | Complete |
| D | Complete |
| E | Complete |
| F | `OPENAPI TEMPLATE PROOF ACCEPTED` |
| G | `PROTOBUF ERGONOMICS DOCUMENTATION SUFFICIENT` |
| H | `VALIDATED` with the matrix above |

No item remains pending, in review, or TBD. OpenAPI multipart/file expansion
and a reusable GraphQL WebSocket adapter are post-1.0 candidates, not open
rc.5 work.

## 22. Feature-freeze declaration

The scope lock and ADR-0011 now record A–E completion and terminal F/G/H
decisions. [`ALPHAX_1_0_FEATURE_FREEZE.md`](ALPHAX_1_0_FEATURE_FREEZE.md) is the
short stable-boundary authority.

From the freeze declaration onward, only correctness, security, frozen API
consistency, platform conformance, compatibility regressions, documentation,
migration, metadata, packaging/build, and release validation are permitted.
The freeze declaration commit is
`1cf2ed49f1ab2d586d57189807b7e549b437a883`.

## 23. Exact next task

The next task is **ALPHAX 1.0.0-RC.5 RELEASE PREPARATION**. It may coordinate
versions, changelogs, migration material, dry-runs, and publication readiness;
it may not add features.

ALPHAX 1.0 FEATURE FREEZE
