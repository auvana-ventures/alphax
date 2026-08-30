<!-- markdownlint-disable MD013 -->

# AlphaX 1.0.0-rc.5 Architecture and Ecosystem Plan

Status: APPROVED WITH FINAL FEATURE RC LOCK
Date: 2026-08-30
Scope: architecture, feasibility, migration, and release-candidate planning only

## Executive summary

AlphaX rc.4 is technically modular but still asks users to understand more package
names than the normal application path should require. The source audit also shows
that the desired single universal `AlphaXClient.auto()` cannot be implemented inside
`alphax` without breaking the package's most important boundary: `alphax` is pure
Dart and transport-independent.

The recommended direction is **Model A+**:

- retain the six published package names and their technical boundaries;
- keep `alphax` as the canonical contract and policy namespace;
- add a thin, additive user-facing façade to the existing native/browser integration
  packages so normal users do not construct a transport manually;
- keep platform selection in the integration package, not in `alphax`;
- add one justified `package:http` compatibility package if the implementation proves
  it can preserve the useful `BaseClient` contract;
- consolidate direct typed REST and OpenAPI work behind one dev-time generator surface;
- put an SSE parser and WebSocket contract in AlphaX sub-libraries rather than
  creating one package per protocol;
- keep Dio/Retrofit compatibility, GraphQL, and Chopper as ecosystem seams rather
  than reimplementing those frameworks;
- keep gRPC outside rc.5 unless a separate official-channel feasibility task proves a
  clean integration.

This is a user-experience simplification, not a transport rewrite. It does not change
the accepted Cronet/HttpEngine, URLSession, Dart IO, or browser Fetch architecture.

### Proposed rc.5 scope decision

| Candidate | Proposed tier | rc.5 meaning |
| --- | --- | --- |
| User/package simplification | `MUST_HAVE_RC5` | Additive entry façades and one obvious installation path per deployment family; preserve rc.4 imports. |
| `package:http` compatibility | `MUST_HAVE_RC5` | One broad AlphaX-backed `BaseClient` package, proposed as `alphax_http`; no `alphax_chopper` or `alphax_graphql`. |
| Direct typed REST | `SHOULD_HAVE_RC5` | AlphaX-specific annotations/generator foundation that calls `AlphaXClient` directly. Do not copy Retrofit names. |
| SSE | `SHOULD_HAVE_RC5` | Pure-Dart first-class parser/stream contract in an AlphaX sub-library; caller-owned reconnect policy. |
| WebSocket | `SHOULD_HAVE_RC5` | First-class lifecycle contract with provider implementations using existing official WebSocket APIs; no new engine. |
| Chopper | `SHOULD_HAVE_RC5` | Validation through the one `package:http` seam; no dedicated adapter package. |
| OpenAPI | `OPTIONAL_RC5` | Prove an official OpenAPI Generator template/output path after the direct generator seam; defer a full compiler. |
| Protobuf | `OPTIONAL_RC5` | Documentation and small ergonomic helpers only; no runtime dependency or package unless a real seam requires it. |
| GraphQL | `OPTIONAL_RC5` | HTTP compatibility through `package:http` and/or Dio; WebSocket link compatibility only; no GraphQL client. |
| gRPC | `POST_1_0` / `DO_NOT_IMPLEMENT` for rc.5 | Preserve the official `grpc` stack; no competing HTTP/2/gRPC transport. |

The tier labels are scope recommendations, not implemented rc.5 features. Each
feature must earn inclusion with implementation, tests, documentation, examples,
capability matrices, failure semantics, dry-runs, and consumer validation.

## Evidence and source policy

This plan is based on the rc.4 source, package manifests, architecture documents,
ADRs, retained ecosystem validation, and current upstream documentation checked on
2026-08-30. Upstream facts are linked in the [source register](#source-register).
Where this document says “proposed”, “likely”, or “should”, that is an architecture
inference or a recommendation, not a claim that rc.4 already implements it.

No production code, package manifest, version, transport, benchmark, or public API was
changed for this plan.

## 1. rc.4 package and public-API audit

### Actual package graph

The six published packages have this dependency shape:

```text
                         ┌──────────────────┐
                         │      alphax      │
                         │ pure contracts,  │
                         │ policies, client │
                         └────────┬─────────┘
          ┌───────────────────────┼────────────────────────┐
          │                       │                        │
          ▼                       ▼                        ▼
 ┌────────────────┐     ┌────────────────┐       ┌────────────────┐
 │ alphax_native  │     │  alphax_web    │       │  alphax_dio    │
 │ Flutter/native │     │ Fetch + http   │       │ Dio adapter    │
 └───────┬────────┘     └────────────────┘       └────────────────┘
         │ dev dependency
         ▼
 ┌────────────────┐
 │  alphax_test   │
 │ fakes/conform. │
 └────────────────┘

 ┌─────────────────┐
 │ alphax_transform│
 │ opt-in isolate  │
 └─────────────────┘
```

The actual manifest relationships are:

| Package | Version | Runtime dependencies | Development dependencies | Role |
| --- | --- | --- | --- | --- |
| `alphax` | `1.0.0-rc.4` | none | `lints`, `test` | Canonical pure-Dart contracts, client, policies, errors, metrics, and middleware. |
| `alphax_native` | `1.0.0-rc.4` | `alphax`, Flutter SDK | `alphax_test`, Flutter/test tooling | Android Cronet/HttpEngine, Apple URLSession, and Dart IO adapters plus native file types. |
| `alphax_web` | `1.0.0-rc.4` | `alphax`, `http` | `lints`, `test` | Browser Fetch transport. |
| `alphax_dio` | `1.0.0-rc.4` | `alphax`, `dio` | `alphax_test`, `lints`, `test` | Focused Dio 5 `HttpClientAdapter` bridge. |
| `alphax_transform` | `1.0.0-rc.4` | `alphax` | `lints`, `test` | Explicit one-shot native-isolate JSON transform for buffered bytes. |
| `alphax_test` | `1.0.0-rc.4` | `alphax`, `test` | `lints` | Development/test fakes, file fixtures, and transport conformance helpers. |

`alphax_native` and `alphax_dio` use `alphax_test` only for development. A consumer
does not inherit that test package because pub ignores a dependency's dev
dependencies. The graph intentionally has no reverse dependency from `alphax` to an
optional provider.

### What users currently need to understand

| User scenario | Current packages/imports | Current friction |
| --- | --- | --- |
| Native Flutter app | `alphax` + `alphax_native` | Two packages and two imports; caller manually awaits `createAlphaXTransport()`. |
| Browser app | `alphax` + `alphax_web` | Web selection is intentionally explicit; caller constructs `WebFetchTransport()`. |
| `alphax` alone | Contracts and a caller-supplied `AlphaXTransport` | No built-in transport and no no-argument client. This is correct for the pure core but surprising as a “client” package. |
| Existing Dio app | `alphax` + provider package + `alphax_dio` + `dio` | Several packages, though the application retains its Dio API. |
| Retrofit app | Above plus `retrofit`, `retrofit_generator`, and `build_runner` | Correctly remains a Dio/code-generation stack, but the AlphaX boundary is indirect. |
| Large JSON response | Add `alphax_transform` | Explicit and honest, but another package is visible only for a measured workload. |
| Tests | Add `alphax_test` as a dev dependency | A justified development-only package. |

The technically required boundaries are:

- pure core versus Flutter/plugin/provider implementation;
- browser Fetch versus native/Dart VM APIs;
- Dio compatibility versus a transport-neutral core;
- test-only fixtures/conformance versus production runtime;
- optional isolate transformation versus synchronous response semantics.

The historical/user-experience boundaries are the lack of a convenience client
factory and the need for application code to name the implementation package when it
only wants AlphaX's recommended platform behavior. Those can be improved additively
without merging the packages.

### Exact current public API

The source of truth is [`AlphaXClient`](../packages/alphax/lib/src/alpha_x_client.dart):

```dart
AlphaXClient({
  required AlphaXTransport transport,
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
})
```

There is no `AlphaXClient()` no-argument constructor, no `AlphaXClient.auto()`, and no
factory in `alphax` that can inspect the platform.

The current native factory is
[`createAlphaXTransport`](../packages/alphax_native/lib/src/alpha_x_transport_factory.dart):

```dart
Future<AlphaXTransport> createAlphaXTransport({
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
})
```

It selects Android Cronet/HttpEngine, iOS/macOS URLSession, or Dart IO on the other
native Dart VM targets. The caller still constructs the client:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

final client = AlphaXClient(
  transport: await createAlphaXTransport(),
);
```

Explicit provider constructors are public:

- `DartIoTransport()`;
- `AndroidCronetTransport.create(...)`;
- `AppleUrlSessionTransport.create(...)`;
- `WebFetchTransport()` from `alphax_web`.

`AlphaXTransport` is a public abstract class and can be implemented by an
application or another package. It is injectable through the required
`AlphaXClient.transport` field. The public transport contract includes capabilities,
request/response send, streaming, file download/upload, and close semantics.

There is no public transport-selector enum. The internal platform target helper is
kept under `src/`; callers use the automatic factory or concrete constructors.

### Answers to the current API questions

| Question | Verified rc.4 answer |
| --- | --- |
| Can a user write `AlphaXClient()` and receive the best transport? | No. The transport is required. |
| Minimum native setup | Add `alphax` and `alphax_native`; await `createAlphaXTransport()`; pass it to `AlphaXClient`; reuse and close the client. |
| Inject an `AlphaXTransport`? | Yes, through `AlphaXClient(transport: ...)`. |
| Implement a custom transport? | Yes, `AlphaXTransport` is publicly implementable. |
| Force Dart IO? | Yes, `DartIoTransport()`. It is exposed by `alphax_native`. |
| Force Android Cronet? | Yes, `AndroidCronetTransport.create(...)`, on Android. |
| Force Apple URLSession? | Yes, `AppleUrlSessionTransport.create(...)`, on iOS/macOS. |
| Force Web Fetch? | Yes, `WebFetchTransport()` from `alphax_web`; it is explicit rather than auto-selected. |
| Configure portable policies? | Yes: request fields, `AlphaXTimeouts`, cancellation, redirect, protocol preference/requirement, progress, middleware, auth, retry, cookie, cache, resilience, and transport-neutral TLS/proxy policy values. |
| Configure native provider internals? | Only the exposed transport-level TLS/proxy policies. Cronet engine/provider knobs and URLSession configuration objects are not exposed as generic AlphaX fields. |
| Scope of configuration | Request: body, timeout, cancellation, redirect, protocol, progress. Client: ordered middleware and policy state. Transport: provider construction, TLS policy, proxy policy, lifecycle. |
| Unsupported requested feature | Capabilities can be inspected before dispatch; unsupported policy/capability or an unmet protocol requirement fails through normalized AlphaX errors. A protocol preference may fall back and is reported as such. |
| Capability timing | `client.capabilities` is available before dispatch. Actual negotiated protocol and completion facts are available from the response/completion metrics after dispatch where the provider can report them. |

### Public export surface by package

| Package | Verified public exports relevant to rc.5 planning |
| --- | --- |
| `alphax` | `AlphaXClient`, `AlphaXTransport`, request/response/body/stream/file contracts, cancellation, capabilities, protocol, TLS/proxy values, middleware, retry/auth/cookie/cache/resilience policies, errors, progress, and metrics. |
| `alphax_native` | `DartIoTransport`, `AndroidCronetTransport`, `AppleUrlSessionTransport`, local file source/target types, and `createAlphaXTransport`. The platform-target test helper remains private under `src/`. |
| `alphax_web` | Conditional `WebFetchTransport`; the browser implementation uses Fetch/`http` and the non-Web stub preserves compilation outside the browser. |
| `alphax_dio` | `AlphaXDioAdapter`, a Dio 5 `HttpClientAdapter`; it is not a second AlphaX client or a full Dio API replacement. |
| `alphax_test` | `FakeAlphaXTransport`, in-memory file fixtures, and transport conformance helpers for development/tests. |
| `alphax_transform` | `decodeJson`, `AlphaXJsonTransform`, and the unsupported-target exception; explicit one-shot buffered-input transform only. |

No current package exports an automatic `AlphaXClient` constructor, typed REST
annotations, an OpenAPI generator, an SSE parser, a WebSocket session, or a
`package:http` `BaseClient` bridge. Those are proposed surfaces, not hidden rc.4
features.

### Default behavior that must remain explicit

The current defaults are not “optimize everything automatically”:

- native selection is automatic only through `alphax_native.createAlphaXTransport()`;
- browser selection remains explicit through `WebFetchTransport()`;
- certificate and hostname verification use secure platform defaults;
- the system proxy policy is the default;
- redirects follow up to the default policy limit;
- request protocol preference is `auto`; a requirement forbids fallback;
- response/file streaming and native file paths are provider capabilities, not a
  promise that every transport has them;
- retries, authentication middleware, cookies, cache, and resilience are opt-in;
- JSON decoding remains caller-side and synchronous in core;
- `alphax_transform` is explicit and only for already-buffered payloads;
- progress callbacks are optional observations and completion metrics remain
  authoritative.

## 2. Package simplification models

### Model A — Keep the current package family

This is the lowest-risk technical model. It preserves the pure core and keeps each
optional dependency out of ordinary users' graphs. Documentation can make the
recommended combinations clearer, but documentation alone does not remove the
manual native client construction or the six-name mental model.

**Assessment:** retain as the base architecture, but add an additive façade. Model A
alone is not enough for the rc.5 UX objective.

### Model B — Make `alphax` the umbrella entry point

This is not safe under the current package constraints.

1. `alphax` cannot import `alphax_native` or `alphax_web` without declaring them as
   dependencies. Dart requires imported packages to be declared dependencies, and
   pub resolves immediate dependencies for every consumer.
2. `alphax_native` already depends on `alphax`, so making `alphax` depend on
   `alphax_native` creates a dependency cycle.
3. `alphax_native` has a Flutter SDK dependency. Making it a dependency of `alphax`
   would make Flutter resolution part of the core package and damage Dart server and
   pure-Dart use.
4. Conditional imports can select SDK library branches such as `dart.library.io`
   and `dart.library.js_interop`; they do not make an undeclared optional pub package
   appear. All branches must still implement the same API.
5. Tree shaking can remove unreachable code from an application binary, but it does
   not repair pub dependency resolution, dependency cycles, or Flutter SDK
   requirements.

**Assessment:** reject. A universal umbrella would hide package names at the cost of
the transport-independent boundary and package resolution correctness.

### Model C — `alphax_core` plus an umbrella `alphax`

This could be made technically coherent by moving today's contracts into a new
`alphax_core`, turning `alphax` into a platform-aware façade, and keeping shims for
old imports. It would nevertheless be a large role change:

- rc.4 users would have import and dependency migration work;
- the umbrella still needs a Flutter/native/Web dependency strategy;
- pure-Dart server users would move to a different package, undermining the current
  identity of `alphax`;
- public package scores, documentation, and generated code would need coordinated
  migration;
- a compatibility re-export can preserve source imports temporarily but cannot hide
  the dependency/version role change forever.

**Assessment:** do not do this in rc.5. If the product later decides that AlphaX is
primarily a Flutter bundle rather than a pure-Dart contract library, make it a
separately approved package/major-version decision with a long deprecation window.

### Model D — Add another universal façade package

A new façade would add another installation name without solving the dependency
problem. It would also need to decide whether it depends on Flutter, Web, both, or
only provider callbacks. That is more package indirection, not less.

**Assessment:** reject unless a future platform bundle has a concrete dependency
topology that cannot live in the existing integration packages.

### Recommended Model A+ — Existing-package entry façades

Keep the graph and add small, additive entry points in packages that already own the
platform boundary. The exact names should be finalized in the implementation task,
but the shape is:

```text
Flutter/native application
  package:alphax_native/alphax_native.dart
      → createAlphaXClient(...)       [proposed additive convenience]
      → createAlphaXTransport(...)
      → AlphaXClient / AlphaXTransport contracts

Browser application
  package:alphax_web/alphax_web.dart
      → explicit Web Fetch client convenience [proposed additive convenience]
      → WebFetchTransport
      → AlphaXClient / AlphaXTransport contracts

Pure-Dart/custom transport application
  package:alphax/alphax.dart
      → AlphaXClient(transport: customTransport)
```

The existing constructors and imports remain valid. A convenience factory may
re-export the core AlphaX types from the integration package so a normal Flutter app
can depend on and import its chosen platform bundle as its obvious entry point. This
is an additive façade, not an `alphax` dependency cycle and not a claim that pure
Dart code has a native provider.

The current `alphax_native` manifest is Flutter-constrained even though it contains
the Dart IO fallback. Therefore a pure Dart VM/server user cannot currently get the
built-in Dart IO path from `alphax` alone. That limitation should be called out in
rc.5 documentation; solving it would require a separate package-role design (or a
careful pre-stable split) and should not be smuggled into the façade task.

This model simplifies the normal user path to one obvious **AlphaX platform bundle**
plus opt-in ecosystem packages, while preserving the pure core and avoiding a
package-per-feature taxonomy.

### Should simplification happen before stable 1.0?

**Yes, but only the additive façade and package-role clarity.** Changing the role of
`alphax` after stable 1.0 would be a semver and migration problem. The recommended
rc.5 correction preserves rc.4 package names/imports and does not turn the core into a
Flutter umbrella. A full core split should not happen before stable merely because it
would make the package table look shorter.

## 3. Recommended rc.5 package architecture

### User-facing versus implementation versus development packages

```text
CURRENT RC.4

USER-FACING (all published and visible today)
  alphax             core contracts/client/policies
  alphax_native      native and Dart IO providers
  alphax_web         browser Fetch provider
  alphax_dio         Dio compatibility
  alphax_transform   optional large-payload transform
  alphax_test        test tooling

RECOMMENDED RC.5

PRIMARY USER ENTRY BY DEPLOYMENT FAMILY
  native Flutter     alphax_native façade → alphax
  browser            alphax_web façade → alphax
  pure Dart/custom   alphax → caller transport

OPTIONAL ECOSYSTEM / WORKLOAD CONCERNS
  existing Dio       alphax_dio
  http/Chopper/etc.  proposed alphax_http (one broad compatibility seam)
  large JSON         alphax_transform

DEV/INTEGRATION TOOLING
  tests               alphax_test
  direct REST/OAS     proposed alphax_generator (one dev-time surface)

INTERNAL IMPLEMENTATION OWNERSHIP
  alphax             contracts and portable policies
  alphax_native      Cronet/HttpEngine, URLSession, Dart IO, native files
  alphax_web         browser Fetch conditional implementation
  providers          remain behind AlphaX seams; no second engine
```

The proposed `alphax_http` and `alphax_generator` are not reservations to publish
now. They are the only new package concepts that currently have a strong boundary:
one broad compatibility runtime and one dev-only code-generation surface. SSE,
WebSocket, and Protobuf do not automatically get packages.

### Desired user experience after the façade task

The following is **proposed rc.5 API shape**, not an rc.4 API claim:

```dart
// Native Flutter application: proposed convenience façade.
import 'package:alphax_native/alphax_native.dart';

final client = await createAlphaXClient();
```

The factory would select the same current mapping as
`createAlphaXTransport()` and accept only transport-neutral middleware plus the
already-supported TLS/proxy construction policies. It must not add Cronet or
URLSession fields to `AlphaXClient`.

The current, supported rc.4 form remains:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';

final client = AlphaXClient(
  transport: await createAlphaXTransport(),
);
```

Web remains explicit because browser transport is a separate compilation/runtime
boundary. A proposed Web convenience factory could shorten construction, but it must
not imply that browser Fetch has native protocol, TLS, proxy, or file-path authority.

## 4. Transport ownership and configuration model

### What AlphaX owns

- the request/response/stream/file contract;
- transport-neutral cancellation, timeout, redirect, progress, and protocol
  preference/requirement values;
- capability discovery and normalized unsupported/failure semantics;
- actual protocol/fallback reporting where the provider supplies authoritative data;
- ordered middleware and opt-in auth, retry, cookies, cache, and resilience seams;
- bounded stream and native-file abstractions;
- portable error and completion metric vocabulary;
- custom `AlphaXTransport` injection.

### What the provider/platform owns

- DNS, route selection, connection/session pools, multiplexing, TLS handshakes,
  QUIC state, and provider-specific protocol negotiation;
- whether H3, session resumption, migration, background transfer, or a trust/proxy
  feature is available on that platform/provider;
- browser CORS, browser TLS/proxy/cookie policy, and browser connection behavior;
- provider-specific native cache/session configuration not exposed by AlphaX;
- actual file and socket resources at the native boundary.

AlphaX expresses caller intent. A capability says whether a selected transport can
honor an operation under its current configuration; it is not proof that an individual
request negotiated that protocol. `protocolPreference` may fall back. A
`protocolRequirement` must fail closed when the provider cannot authoritatively prove
the requested protocol.

### Configuration matrix for rc.4 and rc.5 planning

| Concern | Current/default behavior | Portable AlphaX control | Provider-dependent boundary | Unsupported behavior |
| --- | --- | --- | --- | --- |
| Transport selection | Native factory chooses Android/Apple/Dart IO; Web is explicit | Inject any `AlphaXTransport` | Provider constructors and lifecycle | No built-in universal auto client in `alphax`; caller chooses the integration package. |
| HTTP protocol | `auto` preference | `AlphaXProtocolPreference` | Server, proxy, network, and provider negotiate | A requirement fails closed; a preference may report fallback. |
| TLS verification | Secure platform trust | `AlphaXTlsPolicy` | Provider support for anchors, pins, client identity | Unsupported policy fails closed; never trust-all. |
| Proxy | System proxy | `AlphaXProxyPolicy` | OS/provider/browser support | Unsupported proxy mode fails closed. |
| Retries | Off | `AlphaXRetryMiddleware` | Replayability and transport errors | Unsafe mutation is not silently retried. |
| Authentication | Off | `AlphaXAuthenticationMiddleware` or request headers | Token/provider credential storage | Caller handles refresh/error policy. |
| Cookies | Off in AlphaX | `AlphaXCookieMiddleware`/store | Browser-managed cookies remain opaque | Browser credentials do not become an AlphaX cookie jar. |
| Cache | Off | `AlphaXCacheMiddleware`/store | Provider caches are not normalized | Caller opts in and must preserve authorization safety. |
| Resilience | Off | `AlphaXResilienceMiddleware` | Caller policy and operation classification | No hidden circuit breaker/retry. |
| Redirects | Follow up to `AlphaXRedirectPolicy` default | Request-scoped policy | Provider may own some hop details | Reject/manual/follow remains explicit. |
| Streaming | Transport capability and bounded contract | `sendStreaming`, body abstractions | Browser/native provider buffering limits | Capability and normalized failure are authoritative. |
| Native files | Native packages may override file transfer | `download`/`upload` file abstractions | Provider/file APIs | Core fallback can use streams; no universal native path claim. |
| Cancellation | `AlphaXCancellationToken` | Request-scoped | Provider cancellation granularity | Cancellation remains normalized; no hard kill claim for arbitrary workers. |
| Timeouts | `AlphaXTimeouts` defaults | Request-scoped timeout policy | Provider phase coverage | Unavailable phase metrics remain unavailable. |
| JSON transform | Synchronous core; explicit `alphax_transform` one-shot native isolate | Caller chooses when to buffer/offload | Web fails closed for background transform | No automatic threshold or hidden isolate. |
| Metrics/capabilities | Available only where honest | Read capability/response metrics | Native/browser observability | Unknown/null is preferable to an invented fact. |

### Provider knob audit

| Provider knob | rc.4 state | rc.5 recommendation |
| --- | --- | --- |
| Android Cronet/HttpEngine provider selection | `createAlphaXTransport()` selects the AlphaX provider path; arbitrary provider injection is not a generic core field | Keep provider selection in `alphax_native`; expose a provider-specific escape hatch only if a concrete consumer needs it. |
| URLSession/session configuration | URLSession is created by the Apple adapter; Foundation session types do not leak into core | Keep session policy/provider-managed; do not add Foundation objects to `AlphaXClient`. |
| Dart IO client lifecycle | Public `DartIoTransport` and reusable client lifecycle | Keep explicit for troubleshooting; normal callers use the native façade where available. |
| Cache mode and user agent | Not a common transport-neutral AlphaX field | Report as a provider-specific follow-up; do not add to rc.5 automatically. |
| Proxy/TLS policy | Already configurable through AlphaX policy values with capability checks | Keep the normalized policy boundary. |
| H3 toggles, DoH, 0-RTT, migration, custom DNS | Not a common AlphaX control | Keep provider-managed or rejected; no rc.5 knobs. |
| Native diagnostics/logging | Not an application contract | Keep internal/test-only; never log credentials, bodies, or sensitive URLs by default. |

## 5. Direct typed REST and code-generation architecture

### Keep the validated Retrofit path

The rc.4 compatibility result remains:

```text
Retrofit generated client
    → Dio
    → AlphaXDioAdapter
    → AlphaXClient
    → AlphaX transport
```

Retrofit remains a Dio/source-generation layer. AlphaX must not describe this as
direct Retrofit support, replace `retrofit_generator`, or require Retrofit as a
runtime dependency.

### Proposed direct AlphaX generator

Direct typed REST is worth building, but it should use AlphaX-owned names and
semantics. Do not copy `@RestApi`, `@GET`, or Retrofit implementation details merely
to make a familiar example compile. That would couple AlphaX to another project's
API and generator behavior and create an avoidable license/maintenance question.

The proposed dev-time surface is one `alphax_generator` package. Its first slice
could use source generation/build_runner for AlphaX-specific declarations:

```dart
// Proposed only; not an rc.4 API.
@AlphaXApi(baseUrl: 'https://api.example.com')
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXGet('/users/{id}')
  Future<User> getUser(@AlphaXPath('id') String id);

  @AlphaXPost('/users')
  Future<User> createUser(@AlphaXBody() CreateUser input);
}
```

The generated implementation must call `AlphaXClient` directly and preserve:

- request method, URI/path/query/header encoding, and body construction;
- typed response decoding through caller/model hooks;
- nullable and wrapper responses;
- error and cancellation semantics;
- multipart/file and streaming representations where the AlphaX contract can express
  them;
- protocol preference/requirement and capability-aware options without exposing
  native provider types.

The generator must not add `json_serializable`, Freezed, Protobuf, or Retrofit as a
runtime dependency. Model serialization remains application-owned. A generated
client may integrate with those model generators through ordinary `fromJson`,
`toJson`, or binary callbacks.

### Decision among direct-generation options

| Option | Decision | Reason |
| --- | --- | --- |
| Reuse Retrofit annotations and name the result Retrofit-compatible | Reject for direct AlphaX generation | It couples AlphaX to a Dio generator contract and risks implying native/direct Retrofit support. Keep the already validated Retrofit-through-Dio path. |
| AlphaX-owned compatible annotations | Recommend | Gives the generator a small, deep contract that can call `AlphaXClient` directly without importing Dio or native types. |
| Separate OpenAPI-only generator | Defer as the primary surface | OpenAPI is valuable, but a full compiler duplicates mature tooling. Use an official template/customization path first. |
| One generator surface for annotations plus OpenAPI output | Recommend direction, phased | Share emitted AlphaX client/runtime conventions while keeping build-time annotations and OpenAPI template input as separate bounded commands. |

### OpenAPI path

The official OpenAPI Generator marks its Dart/Dio generator stable and provides a
supported customization/template mechanism. The lowest-risk path is:

1. define the AlphaX generated-client runtime contract;
2. prove a custom template or template library for the official OpenAPI Generator;
3. emit AlphaX client calls and application-owned model hooks;
4. support request/response, auth, multipart, file, and stream shapes only when the
   OpenAPI document and AlphaX contract represent them honestly;
5. add a direct parser/compiler only if templates cannot cover required semantics.

Do not build a second OpenAPI compiler in rc.5. Do not claim all third-party OpenAPI
generators are compatible. Classify output by its generated transport:

- generated Dio client: usable through `alphax_dio` when it accepts an ordinary Dio
  instance and does not assume an adapter-specific extension;
- generated `package:http` client: usable through proposed `alphax_http` when its
  client can be injected;
- generated custom transport: requires a generator-specific integration.

This keeps one AlphaX generator/tooling vocabulary while using the official OpenAPI
Generator extension seam where it already exists.

## 6. One `package:http` compatibility seam

### Feasibility

`package:http`'s `BaseClient` is a narrow, widely-used seam: a subclass implements
`send(BaseRequest) -> Future<StreamedResponse>` and may implement `close()`. Chopper
accepts an injected `http.Client`; `gql_http_link` accepts an injected `http.Client`;
many generated clients use the same pattern. That makes one compatibility adapter
more valuable than separate Chopper, GraphQL, and OpenAPI adapters.

The official `package:http` ecosystem already separates the common client contract
from implementations such as the default IO/browser clients and the separate
Cronet/Cupertino clients. AlphaX should use that composability; this proposal does
not rely on the false premise that `package:http` lacks connection reuse or native
implementations.

The proposed package is `alphax_http`, only if implementation validation confirms the
contract. It would depend on `alphax` and `http`, not Dio, Flutter, or a provider.

Conceptual shape:

```dart
final httpClient = AlphaXHttpClient(alphaClient);
final chopper = ChopperClient(client: httpClient, services: <ChopperService>[...]);
```

This is a proposed API, not current rc.4 code.

### Mapping and honest limitations

The adapter can map the common `BaseRequest` surface to `AlphaXRequest` and return an
AlphaX response stream as `StreamedResponse`. It must test:

- method, URI, path/query encoding, headers, and request body streams;
- content length and multipart where `BaseRequest` expresses it;
- response status, headers, reason phrase, redirect flags, and response stream;
- close ownership and reuse of one long-lived AlphaX client;
- normalized transport errors mapped to an appropriate `http.ClientException`;
- request-body and response-stream cancellation behavior where the `http` API offers
  a cancellation seam.

It cannot make the `package:http` abstraction expose every AlphaX fact. In particular,
the standard response type does not carry the complete AlphaX capability set,
protocol requirement/fallback metadata, completion metrics, native-file mode, or
AlphaX progress callbacks. Request-specific AlphaX protocol requirements and rich
file operations remain available through the native AlphaX API, not through a generic
`http.Client`.

`BaseClient` also does not give every caller an AlphaX cancellation token or a
portable per-request timeout/control surface. The adapter must document the exact
behavior instead of pretending parity.

### Chopper

Chopper's maintained client accepts an injected `http.Client`, and generated services
use that client. Therefore the desired classification is:

```text
SUPPORTED_VIA_HTTP_COMPATIBILITY
```

This is contingent on a small generated Chopper fixture passing with `alphax_http`.
No `alphax_chopper` package should be created.

### GraphQL HTTP and generated SDKs

`gql_http_link` accepts an injected `http.Client`, so GraphQL HTTP queries/mutations
can use the same seam. OpenAPI-generated clients that accept `http.Client` can use it
too. This is compatibility through an injected caller layer, not a claim that AlphaX
implements GraphQL or all generated SDKs.

## 7. Protobuf

Protobuf is primarily serialization, not an AlphaX transport. The maintained Dart
`protobuf` runtime and `protoc_plugin` already provide generated messages and binary
buffer operations. AlphaX request bodies already support bytes, so the basic pattern
is sufficient:

```dart
final request = AlphaXRequest(
  method: HttpMethod.post,
  uri: uri,
  body: AlphaXBody.bytes(message.writeToBuffer()),
);

final response = await client.send(request);
final message = UserMessage()..mergeFromBuffer(await response.readAsBytes());
```

This is a caller/model-layer pattern, not a new transport. A `protobuf` dependency in
`alphax` would make every ordinary HTTP user resolve a serialization runtime and
would make the core know a third-party message type. A separate `alphax_protobuf`
package would add a package for a two-line mapping without demonstrated value.

**Recommendation:** `OPTIONAL_RC5`: document the pattern and let the direct generator
emit it where an API schema requires it. Add helpers only if they remove repeated,
correctness-sensitive mapping without adding the runtime dependency to core.

## 8. Server-Sent Events

SSE is a natural AlphaX HTTP-stream feature and should be first-class in rc.5 unless
implementation evidence shows a contract problem. It should live in an AlphaX
sub-library such as `package:alphax/sse.dart`, not `alphax_sse`.

### Proposed scope

The first useful seam is a parser and event stream over the existing bounded
`Stream<List<int>>` response body:

```text
AlphaXClient GET with Accept: text/event-stream
    → bounded UTF-8 byte stream
    → AlphaX SSE parser
    → AlphaXSseEvent(data, event, id, retry)
```

The event model must cover:

- UTF-8 incremental decoding;
- CRLF, LF, and CR line endings;
- comments/keep-alives;
- multiline `data` fields joined according to the specification;
- `event`, `id`, and valid non-negative `retry` fields;
- blank-line dispatch and final buffered field behavior;
- malformed-field handling without inventing data;
- cancellation, backpressure, and stream errors.

The parser should expose `retry` and `id` information, but automatic reconnection
should not be part of the first contract. Reconnect policy, delay limits, and
`Last-Event-ID` request construction belong to the caller or a later explicit policy
layer. This avoids hidden loops and makes cancellation deterministic.

### Browser and native boundaries

Native AlphaX response streaming can feed the same parser. Browser Fetch can feed it
when the response stream is exposed and CORS permits it. Browser `EventSource` is not
a drop-in replacement for the AlphaX request contract: it owns reconnection and does
not expose arbitrary request methods, bodies, or headers. AlphaX must not claim native
and browser parity where the browser does not provide it.

The WHATWG specification is the authority for event framing. The AlphaX parser must
not silently treat a malformed stream as a successful complete event stream.

## 9. WebSocket

WebSocket should be a first-class AlphaX capability, but it must not be forced into
`AlphaXTransport.send`, which is an HTTP request/response contract. A WebSocket has a
long-lived full-duplex lifecycle, message stream, sink, close state, and different
backpressure semantics.

### Proposed contract

The core sub-library could define a transport-neutral connector and session with:

- connect and cancellation;
- text and binary messages;
- a sink/send operation;
- close code/reason and terminal lifecycle;
- negotiated subprotocol where the provider reports it;
- connection/error events;
- provider capability for ping/pong, rather than a fabricated universal guarantee;
- explicit backpressure/queued-byte behavior where observable;
- idempotent close.

Conceptual usage only:

```dart
final socket = await client.connectWebSocket(uri); // proposed, not rc.4
socket.messages.listen(handleMessage);
socket.sendText('hello');
await socket.close();
```

Automatic reconnect should not be enabled by default. Reconnect is application
policy and can duplicate application messages or violate authentication/session
assumptions.

### Provider strategy

Do not build a WebSocket engine. Evaluate the Dart-team `web_socket` abstraction and
existing platform APIs in the implementation task. Native `dart:io` and browser
WebSocket have different header, buffering, and lifecycle authority; Apple and
Android provider-specific implementations must be proven before claiming that the
HTTP Cronet/URLSession transport also owns WebSocket connections.

The likely implementation shape is a core contract plus provider connectors in the
existing `alphax_native`/`alphax_web` boundaries. If dependency isolation proves
that impossible, return with a separate package proposal; do not create
`alphax_websocket` by default.

## 10. GraphQL

AlphaX should not become a GraphQL client. GraphQL owns schema, AST, fragments,
normalized cache, query/mutation semantics, and subscription protocol selection.

The rc.5 relationship should be:

```text
GraphQL client/link layer
  HTTP queries/mutations → injected AlphaX-backed http.Client or Dio
  subscriptions          → an AlphaX WebSocket connector where the link permits it
```

The maintained GraphQL Dart ecosystem exposes link/HTTP-client seams, including an
`HttpLink` that accepts an injected `http.Client`, plus Dio and WebSocket link
packages. Therefore classify AlphaX as:

```text
GRAPHQL_TRANSPORT_COMPATIBILITY
```

not `ALPHAX_GRAPHQL_CLIENT`. A dedicated GraphQL package is not justified by the
current evidence.

## 11. gRPC

gRPC is not “Protobuf over AlphaX HTTP.” The maintained Dart gRPC stack owns a
channel/connection model, HTTP/2 framing, metadata, trailers, unary and all three
streaming directions, deadlines, status, compression, and flow control. Its recent
transport connector seam is channel/connection-oriented rather than a generic
`package:http.Client` or AlphaX request/response seam.

An AlphaX adapter would have to preserve gRPC-specific lifecycle and trailer/status
semantics and either implement or deeply couple to the official gRPC transport
internals. Mapping each RPC to `AlphaXRequest` would lose correctness. Building a
competing HTTP/2/gRPC stack is outside AlphaX's architecture and explicitly out of
scope.

**Classification:** `POSSIBLE_BUT_MAJOR` as a future investigation, therefore
`POST_1_0` / `DO_NOT_IMPLEMENT` for rc.5. Keep using the official `grpc` package for
gRPC applications.

## 12. Ecosystem compatibility classification

| Ecosystem | rc.4 relationship | Proposed rc.5 relationship | Classification |
| --- | --- | --- | --- |
| Retrofit | Validated through `Dio -> AlphaXDioAdapter -> AlphaX`. | Keep this path; direct AlphaX generation uses AlphaX-owned annotations instead. | `SUPPORTED_THROUGH_DIO` |
| `json_serializable` | Caller-owned DTO serialization; validated in the Retrofit fixture. | Generator/model hooks remain application-owned. | `COMPATIBLE_CALLER_LAYER` |
| Freezed | Caller/model layer; representative Retrofit fixture validated compatibility. | No AlphaX dependency. | `COMPATIBLE_CALLER_LAYER` |
| `built_value` | Not an AlphaX runtime dependency. | OpenAPI/generated models may use it when the generator output supports it. | `COMPATIBLE_CALLER_LAYER` |
| OpenAPI-generated Dio clients | Ordinary generated clients may work when they accept injected Dio; no universal generator claim. | Validate representative outputs through `alphax_dio`; offer an AlphaX template path later. | `SUPPORTED_THROUGH_DIO` when the generated client is injectable; otherwise `COMPATIBLE_CALLER_LAYER` |
| OpenAPI-generated `package:http` clients | No AlphaX-backed `http.Client` in rc.4. | Proposed `alphax_http` can unlock clients with injectable client seams. | `COMPATIBLE_CALLER_LAYER` / rc.5 proposal |
| Chopper | No direct AlphaX adapter in rc.4. | Inject proposed `alphax_http`; no dedicated package. | `SUPPORTED_VIA_HTTP_COMPATIBILITY` (proposed) |
| GraphQL HTTP | Possible through existing Dio link plus `alphax_dio`; no GraphQL ownership. | Also use proposed `alphax_http`; subscriptions use a caller/link WebSocket seam. | `SUPPORTED_THROUGH_DIO` / `COMPATIBLE_CALLER_LAYER` |
| gRPC | Separate maintained channel/HTTP2 stack. | No rc.5 adapter. | `OUT_OF_SCOPE` |
| WebSocket | No first-class AlphaX contract in rc.4. | Proposed core lifecycle contract plus existing-provider connectors. | `NOT_INTEGRATED` in rc.4; `SHOULD_HAVE_RC5` proposal |
| SSE | No first-class AlphaX parser in rc.4. | Proposed `alphax` sub-library over HTTP response streams. | `NOT_INTEGRATED` in rc.4; `SHOULD_HAVE_RC5` proposal |

These classifications intentionally distinguish an injected caller-layer seam from
an AlphaX-native integration. “Works through Dio” does not mean that AlphaX replaces
Dio, Retrofit, or GraphQL.

## 13. Factual Dio comparison

| Capability | Dio direct | Dio ecosystem/plugin | AlphaX rc.4 | AlphaX rc.5 proposal |
| --- | --- | --- | --- | --- |
| Basic REST | Dio request API and adapters | Native adapters available in ecosystem | Native/platform transport through AlphaX client | Preserve direct AlphaX API and add simpler entry façade. |
| Typed REST | Not in Dio core | Retrofit and other generators | Retrofit validated through `alphax_dio` | AlphaX-owned direct generator, without calling it Retrofit. |
| OpenAPI | Not in Dio core | Official/third-party generators can emit Dio clients | Works only where generated client uses ordinary Dio and adapter-compatible behavior | Official OpenAPI template path for direct AlphaX output; no universal claim. |
| Protobuf | Body/transform can be supplied by caller | Generator/runtime packages | `AlphaXBody.bytes` and caller decode | Docs/helper ergonomics only; no core protobuf dependency. |
| `package:http` | Not Dio's core client seam | Separate adapters/packages may exist | No direct BaseClient bridge | One proposed `alphax_http` compatibility package. |
| Chopper | Not a Dio core feature | Chopper uses `package:http` | No direct rc.4 path | Unlock through `alphax_http`, no `alphax_chopper`. |
| GraphQL | Not Dio core | `gql_dio_link` exists | Usable through Dio link plus `alphax_dio` | Keep GraphQL caller-owned; add http/WebSocket seams only. |
| gRPC | Not Dio core | Separate gRPC stack | Not integrated | Remain separate/post-1.0. |
| WebSocket | Not Dio's HTTP request contract | Third-party/direct APIs | Not integrated | First-class AlphaX lifecycle contract using existing providers. |
| SSE | Manual stream handling or generated stream shapes | Third-party parsers/links | Not integrated | First-class parser over AlphaX bounded response stream. |
| File transfer | Dio file APIs and adapter behavior | Native adapters vary | Native file paths are an AlphaX transport capability | Keep native file abstraction; no forced Dart stream. |
| H1/H2/H3 | Adapter/provider dependent; not normalized by Dio core | Native adapter-specific | Native AlphaX transports report actual protocol/fallback where supported | Preserve provider truth; no universal H3 claim. |
| Protocol requirement | Not a common Dio core contract | Adapter-specific | AlphaX requirement fails closed | Keep transport-neutral requirement. |
| Transport selection | Dio adapter selection | Plugin/provider configuration | `createAlphaXTransport()` and injection | Additive platform façade; no core provider import. |
| TLS/pinning/proxy | Adapter/provider dependent | Native adapter-specific | AlphaX policy vocabulary and fail-closed capability checks | Preserve normalized policy; provider escape hatches remain scoped. |
| Retry/cache/cookies | Interceptors/plugins and application policy | Rich ecosystem | Explicit AlphaX middleware | Keep opt-in and transport-independent. |
| Background transforms | Dio has transformer/background behavior in its current ecosystem | Behavior is transformer/version-specific | Core synchronous; `alphax_transform` explicit one-shot | No automatic AlphaX transform; generator/model hooks remain explicit. |

Dio remains a strong client and ecosystem. The distinction is architectural: Dio
starts with its client/interceptor/transformer API and delegates transport to an
adapter; AlphaX starts with a transport capability/policy contract and offers Dio
interoperability at a boundary. Neither side should make a universal speed claim.

## 14. Migration and stable-1.0 implications

### rc.4 to proposed rc.5

The safest migration is additive:

```text
rc.4
  import package:alphax/alphax.dart
  import package:alphax_native/alphax_native.dart
  AlphaXClient(transport: await createAlphaXTransport())

rc.5 proposed
  existing imports continue to compile
  optional platform façade shortens construction
  optional alphax_http adds BaseClient compatibility
  optional alphax_generator emits direct AlphaX clients
```

No rc.4 package should be renamed, removed, or repurposed. Existing `alphax_dio`,
`alphax_transform`, and `alphax_test` remain valid. A façade may re-export core types,
but re-exports must not create two competing type identities or duplicate public
contracts.

### Changes to defer

- Do not split `alphax_core` before stable without a separate migration design.
- Do not make `alphax` Flutter-aware.
- Do not change `alphax_native`'s package role merely to reduce the package table.
- Do not copy Retrofit's annotations or generator.
- Do not make an AlphaX package depend on every optional serialization or GraphQL
  ecosystem.

After stable 1.0, changing the role of `alphax` or removing an rc.4 package would
require a major-version strategy. That is why the additive façade is the only
package simplification recommended before stable.

## 15. Proposed rc.5 implementation sequence

These are proposed bounded tasks only; none is being implemented by Task 47.

### Task A — AlphaX entry façades and package-role UX

**Tier:** `MUST_HAVE_RC5`

**Output:** Additive convenience client factories/re-exports in existing native/Web
integration packages, with rc.4 compatibility tests.

**Non-goals:** No core auto-imports, no package merge, no provider-specific fields.

**Exit:** native Flutter and Web examples use one obvious package entry per target;
pure core/custom transport path remains explicit and documented.

### Task B — One `package:http` compatibility package

**Tier:** `MUST_HAVE_RC5`

**Proposed package:** `alphax_http`

**Output:** `http.BaseClient` bridge plus stream/body/error/close conformance tests.
**Consumers:** Chopper, `gql_http_link`, injectable OpenAPI/http clients, and other
`BaseClient` users.
**Exit:** no loss is hidden; capability/protocol/file/progress limitations are
documented; Chopper fixture passes without a dedicated adapter.

### Task C — AlphaX SSE sub-library

**Tier:** `SHOULD_HAVE_RC5`

**Output:** Parser/event contract over an AlphaX byte stream, deterministic framing,
UTF-8, multiline data, cancellation, backpressure, and malformed-input tests.
**Non-goals:** automatic reconnect, hidden retry loops, browser EventSource parity.

### Task D — AlphaX WebSocket contract and providers

**Tier:** `SHOULD_HAVE_RC5`

**Output:** Separate lifecycle contract, capability reporting, provider connector
design, native/Web tests using an existing maintained implementation.
**Non-goals:** a new engine, automatic reconnect, universal ping/pong claim, or
forcing WebSocket through `AlphaXTransport.send`.

### Task E — Direct typed REST generator foundation

**Tier:** `SHOULD_HAVE_RC5`

**Proposed dev package:** `alphax_generator`

**Output:** AlphaX-owned annotations/generator, direct `AlphaXClient` calls,
caller-owned model hooks, typed/error/cancellation/multipart examples.
**Non-goals:** Retrofit fork, model registry, mandatory serialization package,
automatic transport selection.

### Task F — OpenAPI template proof

**Tier:** `OPTIONAL_RC5`

**Output:** One maintained official OpenAPI Generator customization/template path
that emits AlphaX clients for a bounded OpenAPI 3 surface.
**Non-goals:** full OpenAPI compiler, universal generator compatibility, silently
supporting every schema feature.

### Task G — Protobuf ergonomics

**Tier:** `OPTIONAL_RC5`

**Output:** Docs and, only if justified, tiny helpers around `writeToBuffer` and
`mergeFromBuffer`; no runtime core dependency.
**Non-goals:** a protobuf runtime, generator, or gRPC stack.

### Task H — Ecosystem validation bundle

**Tier:** `OPTIONAL_RC5`

**Output:** Compile-tested Chopper, GraphQL HTTP, representative OpenAPI/Dio, and
WebSocket-link fixtures.
**Non-goals:** dedicated framework adapters where an existing injection seam works.

### Task I — gRPC feasibility record

**Tier:** `POST_1_0`

**Output:** Only if separately approved, a read-only feasibility review against the
official `grpc` channel/transport seam.
**Non-goals:** implementation in rc.5 or a competing stack.

## 16. rc.5 exit criteria

An rc.5 feature is not complete because a package or library exists. Each included
feature must have:

- a useful implementation with a small, deep public seam;
- deterministic unit/conformance tests;
- compile-tested examples and current README documentation;
- platform/provider capability and limitation matrices;
- honest cancellation, backpressure, error, and lifecycle semantics;
- package dry-run with no accidental dependencies or local paths;
- at least one clean consumer fixture for each ecosystem integration;
- preserved rc.4 imports and migration notes where the surface is additive;
- no claims based only on provider capability, package marketing, or benchmark
  rankings.

The package simplification task must also prove that the convenience façade does not
create a second client/transport per request and that close ownership is explicit.

## 17. Product differentiation without marketing exaggeration

AlphaX has a meaningful product boundary even after ecosystem compatibility is added,
but it is not “the fastest HTTP client” by default:

- `alphax` makes transport capability, actual protocol, fallback, policy support,
  normalized errors, bounded streaming, and native file behavior explicit;
- official `package:http` native clients provide a deliberately thin common client
  seam and provider-specific packages; an AlphaX compatibility client should preserve
  that composability rather than claim that `package:http` has no pooling or native
  support;
- Dio provides a rich client/interceptor/transformer ecosystem and remains a good
  choice; `alphax_dio` changes the transport boundary underneath it;
- Retrofit remains a valid Dio/code-generation layer; direct AlphaX generation would
  be a separate AlphaX-owned tool;
- GraphQL, gRPC, Chopper, and serialization libraries retain their own ownership
  models. AlphaX should integrate at their documented seams rather than absorb them.

The user-visible advantage to pursue is **clear control with truthful portability**:
one ordinary entry path, explicit escalation for advanced users, and no silent
downgrade of a requested security/protocol policy.

## 18. Explicit non-goals for rc.5

Do not implement these as part of the proposed architecture:

- a universal `alphax` umbrella that imports native/Web packages;
- an `alphax_core` split solely to reduce the visible package count;
- `alphax_chopper`, `alphax_graphql`, `alphax_protobuf`, or `alphax_websocket` by
  default;
- a direct Retrofit fork or copied annotation surface;
- an AlphaX GraphQL client, normalized GraphQL cache, or schema toolchain;
- a competing gRPC/HTTP2 stack;
- a full OpenAPI compiler before template feasibility is tested;
- automatic JSON transformation, hidden isolate thresholds, or a persistent worker;
- provider knobs for DoH, 0-RTT, migration, custom DNS, or other rejected common API
  work;
- a second native HTTP/WebSocket engine;
- universal H3, protocol, TLS, proxy, browser, or zero-copy claims.

## 19. Roadmap decision

The roadmap should identify rc.5 as an **architecture proposal in review**, not as a
release commitment. The recommended order is:

```text
entry façades/package-role UX
          │
          ├── alphax_http compatibility seam ── Chopper/GraphQL/OpenAPI-http validation
          │
          ├── SSE sub-library
          │
          ├── WebSocket contract/providers ─── GraphQL subscription seam
          │
          └── alphax_generator
                    └── OpenAPI template proof

protobuf ergonomics ── optional caller/generator support
gRPC feasibility ───── post-1.0 official-channel review only
```

## 20. Direct answers to the final planning questions

| # | Question | Answer |
| --- | --- | --- |
| 1 | Are there too many packages from a user's perspective? | Yes for ordinary native and ecosystem users, even though the technical boundaries are mostly justified. |
| 2 | Which packages should a normal user know? | `alphax` plus the selected native/Web platform bundle; add `alphax_dio`, `alphax_transform`, or `alphax_test` only for those concerns. |
| 3 | Can `alphax` safely become the single main entry point? | Not as a universal umbrella while it remains pure Dart and transport-independent. |
| 4 | Simplest sound alternative? | Model A+: additive façade/re-export in existing platform packages, with no new universal façade package. |
| 5 | Should simplification happen before stable 1.0? | Yes for additive entry-point ergonomics and documentation; no for a core split or package-role reset. |
| 6 | Should direct typed REST generation be built? | Yes, as a bounded AlphaX-owned generator foundation, separate from Retrofit and Dio. |
| 7 | How should OpenAPI work? | First prove official OpenAPI Generator templates/customization for AlphaX output; defer a full compiler. |
| 8 | Can one `package:http` adapter unlock Chopper and generated SDKs? | Yes where callers inject `http.Client`; it also opens GraphQL HTTP and must document metadata/cancellation/file limitations. |
| 9 | Does Protobuf need a package? | No. Use existing byte bodies and generated-message APIs; add only justified no-core-dependency ergonomics. |
| 10 | Should SSE be first-class? | Yes, as a pure AlphaX sub-library over bounded HTTP response streams, without hidden reconnect. |
| 11 | Should WebSocket be first-class? | Yes, as a separate full-duplex contract using existing provider APIs, not the HTTP request contract. |
| 12 | What should AlphaX do for GraphQL? | Provide transport compatibility at documented HTTP/WebSocket seams; do not build a GraphQL client. |
| 13 | Is gRPC realistic for rc.5? | No. The official channel/HTTP2 seam makes it possible but major; keep it post-1.0. |
| 14 | What creates package bloat? | One package per protocol/framework, a universal umbrella, a core split for naming alone, a GraphQL client, a gRPC stack, and a full OpenAPI compiler. |
| 15 | Exact rc.5 implementation order? | A entry façades, B `alphax_http`, C SSE, D WebSocket, E typed generator, F OpenAPI template proof, G Protobuf ergonomics, H ecosystem fixtures; I gRPC feasibility is post-1.0. |
| 16 | What remains post-1.0? | A possible core/package-role migration, gRPC integration, full OpenAPI compiler, GraphQL-specific adapters, and advanced provider controls unless new evidence justifies them. |

## Source register

Primary/upstream sources used for the feasibility conclusions:

- Dart dependency sources, caret constraints, dev dependencies, path-package
  publication rules, and SDK dependencies: [Dart package dependencies](https://dart.dev/tools/pub/dependencies).
- Conditional imports/exports and `package:web` guidance: [Dart creating packages](https://dart.dev/tools/pub/create-packages).
- Package metadata/dependency declaration rules: [Dart pubspec reference](https://dart.dev/tools/pub/pubspec).
- `package:http` common client seam: [`BaseClient`](https://pub.dev/documentation/http/latest/http/BaseClient-class.html) and the [official http repository](https://github.com/dart-lang/http).
- Chopper injected-client architecture: [Chopper package](https://pub.dev/packages/chopper) and [`ChopperClient`](https://pub.dev/documentation/chopper/latest/chopper/ChopperClient-class.html).
- Dio adapter seam: [Dio package](https://pub.dev/packages/dio) and [`HttpClientAdapter`](https://pub.dev/documentation/dio/latest/dio/HttpClientAdapter-class.html).
- Retrofit/Dio generator relationship: [Retrofit package](https://pub.dev/packages/retrofit), [Retrofit API](https://pub.dev/documentation/retrofit/latest/retrofit/), and [Retrofit generator](https://pub.dev/packages/retrofit_generator).
- Official OpenAPI Dart/Dio generator and extension path: [Dart-Dio generator](https://openapi-generator.tech/docs/generators/dart-dio/), [customization](https://openapi-generator.tech/docs/customization/), and [templating](https://openapi-generator.tech/docs/templating/).
- Dart Protobuf runtime and generator: [`protobuf`](https://pub.dev/packages/protobuf), [`protoc_plugin`](https://pub.dev/packages/protoc_plugin), and [Google protobuf.dart](https://github.com/google/protobuf.dart).
- Maintained Dart gRPC channel/transport surface: [`grpc`](https://pub.dev/packages/grpc), [`ClientChannel`](https://pub.dev/documentation/grpc/latest/grpc/ClientChannel-class.html), and [`ClientTransportConnector`](https://pub.dev/documentation/grpc/latest/grpc/ClientTransportConnector-class.html).
- GraphQL link and injectable HTTP client: [`gql_link`](https://pub.dev/documentation/gql_link/latest/), [`HttpLink`](https://pub.dev/documentation/gql_http_link/latest/gql_http_link/HttpLink-class.html), and [graphql-flutter](https://pub.dev/packages/graphql_flutter).
- Dart/native/browser WebSocket surfaces: [`dart:io WebSocket`](https://api.dart.dev/dart-io/WebSocket-class.html), Dart-team [`web_socket`](https://pub.dev/packages/web_socket), and [`web_socket_channel`](https://pub.dev/packages/web_socket_channel).
- SSE framing, UTF-8, fields, and reconnection authority: [WHATWG Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html).

Repository sources audited:

- [`PROJECT_CONTEXT.md`](../PROJECT_CONTEXT.md)
- [`docs/architecture/overview.md`](architecture/overview.md)
- [`docs/architecture/transport_contract.md`](architecture/transport_contract.md)
- [ADR 0003](decisions/0003-public-api-transport-independence.md), [ADR 0004](decisions/0004-platform-native-mobile-transports.md), and [ADR 0007](decisions/0007-transport-neutral-tls-policy-and-pinning.md)
- [`packages/alphax/lib/alphax.dart`](../packages/alphax/lib/alphax.dart)
- [`packages/alphax_native/lib/alphax_native.dart`](../packages/alphax_native/lib/alphax_native.dart)
- [`packages/alphax_web/lib/alphax_web.dart`](../packages/alphax_web/lib/alphax_web.dart)
- [`packages/alphax_dio/lib/alphax_dio.dart`](../packages/alphax_dio/lib/alphax_dio.dart)
- [`packages/alphax_transform/lib/alphax_transform.dart`](../packages/alphax_transform/lib/alphax_transform.dart)
- [`packages/alphax_test/lib/alphax_test.dart`](../packages/alphax_test/lib/alphax_test.dart)

## Maintainer decision

The architecture recommendation is accepted with the final-feature-RC lock:

```text
APPROVED WITH FINAL FEATURE RC LOCK
```

The approved rc.5 implementation boundary is now authoritative in
[`ALPHAX_1_0_RC_5_SCOPE_LOCK.md`](ALPHAX_1_0_RC_5_SCOPE_LOCK.md) and
[ADR-0011](decisions/0011-rc5-final-feature-candidate.md). The report's
architecture recommendation is distinct from that release governance decision:
rc.5 is the final feature candidate, there is no rc.6 feature cycle, and the
project moves directly to stable-1.0 stabilization after rc.5 publication.

No implementation was started by the architecture task.

## Conclusion

RC5 ARCHITECTURE APPROVED WITH FINAL FEATURE RC LOCK
