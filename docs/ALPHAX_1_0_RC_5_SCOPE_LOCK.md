# AlphaX 1.0.0-rc.5 Scope Lock

Status: Accepted
Governing decision: [ADR-0011](decisions/0011-rc5-final-feature-candidate.md)
Purpose: authoritative feature boundary for the final feature RC before stable 1.0.0

## Governing rule

AlphaX 1.0.0-rc.5 is the final feature release candidate before stable 1.0.0.
There will be no rc.6 feature cycle. After rc.5 is completed and published,
development moves directly into stable-1.0 stabilization.

An additional prerelease artifact may be produced only when a correctness,
security, API-consistency, documentation, packaging/build, compatibility, or
platform-validation fix needs stabilization verification. Such an artifact is
stabilization-only and may not add features.

## Architecture preserved

The approved Task 47 Model A+ architecture remains authoritative:

- `alphax` remains pure Dart and transport-independent;
- rc.4 package names and public boundaries remain compatible;
- native and Web entry façades simplify ordinary application setup;
- there is no universal Flutter-aware `alphax` umbrella;
- there is no `alphax_core` split;
- there is no package-per-feature expansion;
- there is no second networking engine;
- Android remains Cronet/HttpEngine-backed, Apple remains URLSession-backed,
  Linux/Windows retain Dart IO fallback, and Web retains browser Fetch.

## MUST_HAVE_RC5

### A. Entry façades and package-role UX

Implement the additive Model A+ experience:

```text
native Flutter   alphax_native façade → alphax
Web              alphax_web façade → alphax
pure Dart/custom alphax directly
```

The implementation must:

- materially simplify ordinary native setup;
- materially simplify ordinary Web setup;
- keep all rc.4 constructors/imports valid;
- preserve explicit transport selection;
- preserve custom `AlphaXTransport` injection;
- keep platform/provider types outside `alphax`;
- avoid a universal umbrella package or hidden per-request transport creation.

### B. `alphax_http` compatibility

Implement one broad `package:http` compatibility seam:

```text
AlphaXClient → AlphaXHttpClient → package:http Client/BaseClient consumers
```

The package is justified only as one ecosystem boundary. It must not be split
into `alphax_chopper`, `alphax_graphql`, or framework-specific HTTP packages.

The implementation must cover the common `BaseClient` request/response stream,
body, headers, status, error, close, and lifecycle contract. It must document
which AlphaX facts are not representable through `package:http`, including
capabilities, protocol requirement/fallback metadata, completion metrics,
native-file mode, progress, and any cancellation/timeout limitations.

The seam should unlock, where the upstream client accepts injection:

- Chopper;
- GraphQL HTTP links;
- injectable OpenAPI-generated `package:http` clients;
- other ordinary `package:http` consumers.

## Committed SHOULD_HAVE_RC5 features

These are promoted into the committed final feature-RC scope. They are not
optional discovery items.

### C. First-class SSE

Implement SSE as an `alphax` sub-library, preferably
`package:alphax/sse.dart`.

Required behavior:

- incremental UTF-8 decoding;
- LF, CRLF, and CR line endings;
- multiline `data` fields;
- `event`, `id`, and `retry` fields;
- comments/keep-alives;
- bounded response-stream compatibility;
- cancellation and stream errors;
- deterministic malformed-input behavior;
- native and Web validation where the provider exposes the required stream.

Do not implement hidden automatic reconnect. The caller or an explicitly
configured policy owns reconnect, delay limits, and `Last-Event-ID` behavior.
Do not create `alphax_sse`.

### D. First-class WebSocket

Implement a separate AlphaX WebSocket lifecycle contract rather than forcing a
full-duplex session through `AlphaXTransport.send()`.

Required portable concepts:

- connect and cancellation;
- text and binary messages;
- send and message stream;
- close, close code, and close reason;
- negotiated subprotocol where available;
- normalized errors and lifecycle;
- idempotent close;
- honest provider capability differences;
- documented backpressure behavior.

Use maintained/platform APIs. Do not build another WebSocket engine or enable
automatic reconnect by default. Prefer a sub-library and existing native/Web
provider boundaries. If dependency isolation proves a new package is necessary,
stop for maintainer approval before creating it.

### E. Direct typed REST generator

Implement one AlphaX-owned dev-time generator surface, proposed as
`alphax_generator`. It must use AlphaX-owned annotation names and generate:

```text
typed generated API → AlphaXClient → AlphaXTransport
```

It must not copy Retrofit's annotation namespace or generate
`typed API → Dio → AlphaXDioAdapter` as its direct architecture. Existing
Retrofit-through-Dio support remains supported through `alphax_dio`.

The initial useful surface includes:

- GET, POST, PUT, PATCH, and DELETE;
- path, query, and header parameters;
- JSON request bodies;
- typed, nullable, and justified wrapper responses;
- caller/model response hooks;
- cancellation and timeout/request options exposed by AlphaX;
- multipart and file upload/download representations;
- streaming where the AlphaX contract represents it honestly;
- protocol preference/requirement where appropriate.

The generator is not a model serialization framework. It must not add Retrofit,
Freezed, `json_serializable`, Protobuf, or Dio as AlphaX runtime dependencies.

## BOUNDED_OPTIONAL_RC5

These items may enter rc.5 only within the definitions below. They may be
removed or deferred without creating an rc.6 feature backlog, and they must not
delay stable 1.0 disproportionately.

### F. OpenAPI template proof

Prove a useful OpenAPI 3.x to AlphaX generated-client path using the official
OpenAPI Generator template/customization seam first.

Minimum proof:

- representative OpenAPI 3.0/3.1 fixture;
- GET/POST;
- path/query/header mapping;
- JSON request/response;
- errors;
- multipart/file behavior where supported;
- generated AlphaX client compilation;
- generated consumer test.

Do not build a full OpenAPI compiler. If the template route becomes a substantial
independent project, defer it to 1.1 rather than holding stable 1.0.

### G. Protobuf ergonomics

Validate the existing byte mapping:

```text
GeneratedMessage → writeToBuffer() → AlphaX bytes request
AlphaX response bytes → mergeFromBuffer()/fromBuffer → GeneratedMessage
```

Documentation alone is sufficient if the existing APIs are already clear. Add
helpers only when they remove meaningful repeated or error-prone code. Do not add
Protobuf to core runtime dependencies or create `alphax_protobuf` for a trivial
mapping.

### H. Ecosystem validation

Validate representative fixtures after the relevant seams exist:

- Chopper through `alphax_http`;
- GraphQL HTTP through an injected `http.Client` or the existing Dio path;
- GraphQL subscription/WebSocket integration only where the maintained library
  exposes a clean connector/link seam;
- an OpenAPI-generated Dio client through `alphax_dio`;
- an OpenAPI-generated `package:http` client through `alphax_http`.

This is compatibility validation, not implementation of Chopper, GraphQL, or
OpenAPI generator internals.

## POST_1_0

The following are explicitly outside the rc.5 feature scope and must not block
stable 1.0:

- gRPC AlphaX integration; use the official `grpc` package and revisit in 1.1+
  only through a separate feasibility/integration review;
- a full OpenAPI compiler;
- an AlphaX GraphQL client/framework/cache/schema toolchain;
- `alphax_core` or universal-umbrella package-role restructuring;
- advanced provider controls such as DoH, 0-RTT, connection migration, custom
  DNS, or experimental QUIC knobs;
- any new Phase-0-style performance campaign, FFI/shared-memory work, second
  engine, or zero-copy project.

## Explicit non-goals

Do not create a package per integration or capability by default, including:

- `alphax_chopper`;
- `alphax_graphql`;
- `alphax_protobuf`;
- `alphax_websocket`;
- `alphax_sse`;
- a direct Retrofit fork;
- a competing gRPC/HTTP2 stack;
- a second native networking engine;
- automatic background parsing, hidden thresholds, or persistent workers;
- universal H3, TLS, proxy, browser, or zero-copy claims.

## Locked implementation order

Execute these as separate, reviewable tasks:

1. Task A — entry façades/package-role UX;
2. Task B — `alphax_http` compatibility;
3. Task C — SSE;
4. Task D — WebSocket;
5. Task E — direct typed REST generator;
6. Task F — bounded OpenAPI template proof;
7. Task G — Protobuf ergonomics;
8. Task H — ecosystem compatibility validation.

Each task requires explicit maintainer approval before implementation. No task
may silently add unrelated scope.

## Scope-removal rule

A feature may be removed from rc.5 when evidence shows that it:

- is substantially larger than planned;
- cannot normalize provider semantics honestly;
- requires a new networking engine;
- introduces unacceptable dependencies;
- breaks the accepted transport architecture;
- risks delaying stable 1.0 disproportionately.

The removed feature moves to 1.1+ or post-1.0 research. It does not create an
rc.6 feature backlog.

## Scope-addition rule

No newly discovered feature may enter rc.5. Classify it as:

- `RELEASE_BLOCKING`, only if required for correctness, security, frozen API
  coherence, or an already-approved rc.5 feature; or
- `POST_1_0`, in every other case.

“Useful”, “small”, or “found during implementation” is not sufficient to add
scope.

## Feature-freeze rule

When Tasks A–E are complete and the bounded F–H decisions are resolved, declare:

```text
ALPHAX 1.0 FEATURE FREEZE
```

From that commit onward, only regression fixes, API review, platform conformance,
security hardening, documentation, migration, package metadata, hosted-consumer
testing, and release validation are permitted.

## Stable 1.0 gate

After rc.5 publication, use one stable-release task. Do not run another capability
audit. The gate is:

### API

- public API frozen;
- no accidental exports;
- complete Dartdoc and consistent naming;
- rc.4 to rc.5 migration documented;
- no known breaking issue.

### Correctness

- all package tests and conformance tests green;
- cancellation/resource cleanup green;
- streaming/backpressure and file lifecycle green;
- SSE and WebSocket lifecycle green;
- generator fixtures green;
- included OpenAPI/Protobuf fixtures green where those optional items were kept.

### Platforms

Validate only supported claims for Android, iOS, macOS, Linux, Windows, and Web.
Do not invent parity where providers differ.

### Security

- secure TLS defaults;
- pinning, proxy policy, and protocol requirements fail closed;
- redirect credentials protected;
- cookie/cache authorization boundaries preserved;
- WebSocket auth/header limits documented;
- no secrets, signing material, or local paths.

### Ecosystem

Validate the applicable Dio, Retrofit, `package:http`, Chopper, GraphQL,
generator, OpenAPI, and Protobuf fixtures that rc.5 actually includes.

### Packaging

- every stable package dry-run clean;
- archives and dependency graph reviewed;
- hosted clean-consumer resolution;
- current READMEs, changelogs, user guide, and migration guide complete.

## Release progression

```text
1.0.0-rc.4  published
      ↓
1.0.0-rc.5  FINAL FEATURE RC
      ↓
stabilization-only verification
      ↓
1.0.0       STABLE
```

Do not plan an rc.6 feature cycle, another ecosystem-discovery cycle, or another
optimization cycle before stable. Any additional RC number is stabilization-only.

## References

- [ADR-0011: rc.5 final feature candidate](decisions/0011-rc5-final-feature-candidate.md)
- [Task 47: rc.5 architecture and ecosystem plan](../tasks/47-alphax-1-0-rc-5-architecture-and-ecosystem-plan.md)
- [Architecture and ecosystem plan](ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md)
- [Roadmap](roadmap.md)
