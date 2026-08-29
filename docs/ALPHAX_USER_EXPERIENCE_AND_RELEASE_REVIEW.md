# AlphaX User Experience and Release Review

Status: final pre-publication review for the coordinated `1.0.0-rc.4` candidate.

This review audits the public APIs and current-facing documentation. It does not
publish packages, create a tag, or make a performance claim.

## 1. Executive summary

The original public API required every caller to construct or inject a transport:

```dart
AlphaXClient(transport: transport)
```

That is the correct shape for pure-Dart `alphax`, but it left ordinary Flutter
callers without a package-owned automatic selection path. The smallest correction
is now in `alphax_native`:

```dart
final transport = await createAlphaXTransport();
final client = AlphaXClient(transport: transport);
```

The factory selects Android Cronet/HttpEngine, Apple URLSession, or Dart IO for
the current native target. Web remains explicit through `WebFetchTransport()`;
this keeps browser capability and dependency boundaries visible. `alphax` remains
pure Dart and still supports explicit or custom transports.

Classification: **AUTO_UX_COMPLETE** for the supported Flutter/native package
path, with explicit package selection remaining intentional for pure-Dart callers
and Web.

No transport architecture was replaced. No new engine, FFI layer, background
worker pool, progress coalescing, credit batching, or benchmark rerun was added.

## 2. Actual public API audit

### Core client and transport

`AlphaXClient` has one public constructor:

```dart
AlphaXClient({
  required AlphaXTransport transport,
  Iterable<AlphaXMiddleware> middleware = const [],
})
```

There is no `AlphaXClient()` no-argument constructor and no `AlphaXClient.auto()`.
The core client exposes request methods, streaming, file transfer, capabilities,
configured TLS/proxy policy, middleware, and `close()`.

`AlphaXTransport` is a public abstract contract. A caller may implement it and
inject it into `AlphaXClient`. Its required behavior is `capabilities`, `send`,
`sendStreaming`, and `close`; `download` and `upload` have generic stream-backed
defaults and may be specialized by a transport.

### Native and Web constructors

| Package/API | Construction | Selection or limitation |
| --- | --- | --- |
| `alphax_native.createAlphaXTransport()` | asynchronous factory | Android Cronet/HttpEngine; iOS/macOS URLSession; other native targets Dart IO |
| `DartIoTransport()` | synchronous constructor | explicit reusable Dart `HttpClient` fallback; H1 capability scope |
| `AndroidCronetTransport.create()` | asynchronous constructor | explicit provider-selected Cronet/HttpEngine transport |
| `AppleUrlSessionTransport.create()` | asynchronous constructor | explicit URLSession transport |
| `WebFetchTransport()` | synchronous constructor | explicit browser Fetch adapter from `alphax_web`; protocol is unknown to Dart |
| `AlphaXDioAdapter(client)` | adapter constructor | Dio owns its client API; AlphaX client/transport is injected |
| `FakeAlphaXTransport(...)` | test constructor | deterministic test transport from `alphax_test` |
| `alphax_transform.decodeJson(...)` | function | explicit, buffered, one-shot native isolate transform; Web fails closed |

For a pure-Dart CLI/server that does not use Flutter, the core-compatible minimum
is explicit `DartIoTransport()` from a package that can provide it. The automatic
factory belongs to `alphax_native`, which is the Flutter package boundary and has
the native plugin dependencies needed for Cronet and URLSession.

### Configuration scope

| Scope | Actual public values |
| --- | --- |
| Request | body, headers, timeout, cancellation token, redirects, protocol preference/requirement, upload/download progress, priority |
| Client | ordered middleware, transport lifetime, close state |
| Transport | TLS policy, proxy policy, provider/session construction, capability set, native-file support |

Portable policy types express caller intent. The selected provider decides whether
that intent can be honored and reports unsupported controls through normalized
AlphaX errors rather than silently weakening them.

### Unsupported behavior and discovery timing

`client.capabilities` is available before dispatch for the configured transport.
Actual negotiated protocol and completion metrics may only be authoritative after
body completion, especially for URLSession streamed responses. Web reports
unknown protocol metadata rather than inferring H1/H2/H3.

An explicit protocol requirement fails closed if the selected transport cannot
support or authoritatively observe that protocol. Unsupported TLS, proxy, file,
or other provider capabilities similarly produce normalized AlphaX failures.

## 3. Automatic transport selection

The new `createAlphaXTransport()` factory is the only automatic selection facade;
it is exported from `alphax_native` and does not add any native dependency to
`alphax`:

```text
Flutter/native application
        |
        +-- alphax_native.createAlphaXTransport()
              |
              +-- Android -> Cronet/HttpEngine
              +-- iOS/macOS -> URLSession
              +-- Linux/Windows/other native -> Dart IO

Web application
        |
        +-- alphax_web.WebFetchTransport()
```

The factory passes the caller's `AlphaXTlsPolicy` and `AlphaXProxyPolicy` to the
selected adapter and completes only after asynchronous native initialization.
It does not enable middleware or invent protocol guarantees.

The factory is deliberately not in `alphax` because conditional platform/plugin
selection there would violate the pure-Dart core boundary. A separate automatic
Web selection layer is also not added: browser transport is a distinct package
and browser authority must remain visible.

## 4. Platform and protocol matrix

| Target | Default/automatic path | What AlphaX can report | Boundary |
| --- | --- | --- | --- |
| Android | Cronet/HttpEngine through `alphax_native` | provider capabilities, actual protocol and fallback where available | H1/H2/H3 depend on provider, server, proxy, and network |
| iOS | URLSession through `alphax_native` | capabilities; authoritative protocol and phase metrics may arrive at completion | H1/H2/H3 are OS/provider/server/network decisions |
| macOS | URLSession through `alphax_native` | same URLSession-family behavior as iOS | same provider and network boundary |
| Linux | Dart IO fallback | H1 capability in AlphaX's truthful model | no AlphaX H2/H3 claim |
| Windows | Dart IO fallback | H1 capability in AlphaX's truthful model | no AlphaX H2/H3 claim |
| Web | explicit browser Fetch through `alphax_web` | protocol remains unknown to Dart | browser owns CORS, TLS, proxy, cookies, route, and negotiation |

`http3` preference means “prefer H3 if the provider can use it.” It does not
mean that a request used H3. `http3` requirement means the operation must fail
closed unless H3 is authoritatively observed.

## 5. Automatic defaults

| Behavior | Default | Opt-in or limitation |
| --- | --- | --- |
| Transport | Native factory chooses the current native adapter; Web is explicit | Core always accepts an injected transport |
| TLS | verified platform trust | custom anchors, SPKI pins, and client identity are explicit and provider-dependent |
| Proxy | system proxy policy | direct and explicit proxy modes are provider-dependent |
| Protocol | automatic provider/server/network negotiation | request preference or requirement is explicit |
| Redirects | follow, maximum five | request redirect policy can change this |
| Timeouts | all unset | request `AlphaXTimeouts` is explicit |
| Middleware | empty | retry, authentication, cookies, cache, and resilience are off until added |
| Progress | no observer | native progress traffic is suppressed when unused; requested progress is per provider read |
| JSON | caller-side synchronous `readAsJson()` | `alphax_transform` is explicit, buffered, one-shot, and native-only |
| Client/session reuse | caller-owned long-lived client guidance | closing/recreating per request discards provider reuse opportunities |

AlphaX does not automatically enable retries, cookies, cache, authentication,
resilience, background parsing, or unsafe TLS behavior.

## 6. Customization matrix

| Feature | Automatic/default behavior | Portable customization | Provider-dependent boundary | Unsupported/fail-closed behavior |
| --- | --- | --- | --- | --- |
| Transport selection | Native factory on supported native Flutter targets | inject any `AlphaXTransport` | Web package selection is explicit | no hidden cross-package Web selection |
| HTTP protocol | `auto` preference | `AlphaXProtocolPreference` | provider/server/proxy/network negotiate | requirement fails if not observed |
| TLS verification | platform trust | `AlphaXTlsPolicy` | trust-anchor and identity support varies | unsupported policy throws |
| Custom trust | no custom anchors | trust-anchor list | provider and OS support varies | unsupported trust throws |
| SPKI pinning | off | host-scoped `AlphaXSpkiPin` | Android and Apple adapters support it | unsupported or mismatched pins fail |
| Proxy | system | `system()`, `direct()`, `http()`, `https()` | provider/OS support varies | unsupported mode throws |
| Retries | off | `AlphaXRetryMiddleware` | replayability and HTTP safety | unsafe/non-replayable work is not silently retried |
| Authentication | off | `AlphaXAuthenticationMiddleware` | token refresh belongs to the caller | no token is invented |
| Cookies | off in core | `AlphaXCookieMiddleware` and a store | browser cookies remain browser-managed | persistence is not assumed |
| Cache | off | `AlphaXCacheMiddleware` and a store | storage and credential identity are caller policy | unsafe credential reuse is not implicit |
| Redirects | follow up to five | `AlphaXRedirectPolicy` | adapter controls native redirect mechanics | reject/manual policy is explicit |
| Streaming | single-consumption body/event stream | `sendStreaming`, pause/resume, body APIs | adapter owns bounded delivery | unsupported stream capability fails |
| File transfer | generic AlphaX file abstraction | `download`/`upload` | native adapters may use native file paths | Web does not claim native file transfer |
| Progress | no observer | request callbacks | provider granularity varies | unsupported progress is not fabricated |
| Cancellation | caller token and client close | `AlphaXCancellationToken` | provider maps cancellation to its task/client | cancellation stays distinct from timeout |
| Timeouts | unset | `AlphaXTimeouts` | phase precision varies | unavailable precision remains unavailable |
| Resilience | off | `AlphaXResilienceMiddleware` | circuit state is client-owned | no hidden retries or circuit |
| JSON transformation | synchronous caller-side decode | explicit `alphax_transform.decodeJson` | native isolate availability | Web helper fails closed |
| Metrics/capabilities | honest fields only | client capabilities and completion metrics | provider reporting differs | unknown/null remains visible |

## 7. What AlphaX controls versus providers

AlphaX owns the transport contract, request/response/body model, policy
composition, preference-versus-requirement semantics, capability and fallback
reporting, normalized errors, bounded stream contract, file abstraction, and
opt-in retry/authentication/cookie/cache/resilience middleware.

Cronet/HttpEngine, URLSession, Dart IO, and the browser own the actual route,
provider pools, QUIC availability, TLS session resumption, native scheduling,
some trust/proxy/client-identity features, and actual protocol negotiation. On
Web, the browser also owns CORS, cookie, redirect, TLS, proxy, and protocol
authority. AlphaX reports these boundaries instead of claiming control it does
not have.

### Provider-control classification

| Category | Current examples |
| --- | --- |
| Already configurable | native adapter choice, TLS policy, SPKI pins/custom trust where supported, system/direct/explicit proxy policy, request protocol preference/requirement |
| Useful but intentionally not exposed | Cronet engine/provider construction details, URLSession configuration/delegate objects, raw native handles, provider cache/logging knobs |
| Provider-managed | connection pools, multiplexing, TLS resumption, route selection, QUIC availability, browser CORS/proxy/cookie rules |
| Unsafe or nonportable | trust-all callbacks, common DoH/0-RTT/migration knobs, raw private keys, native task handles, provider diagnostics that could log credentials |

No provider-specific omission currently prevents ordinary transport control.
Advanced controls remain a separate future design question and are not added to
the 1.0 API.

## 8. Client reuse guidance

Construct one client and transport per useful application or feature scope and
close it when that scope ends. Reuse gives Dart IO, Cronet, URLSession, or the
browser an opportunity to retain connection/session state, pooling, HTTP/2 or
HTTP/3 multiplexing, and TLS/session reuse.

```dart
final client = AlphaXClient(
  transport: await createAlphaXTransport(),
);

try {
  await client.get(Uri.https('example.com', '/first'));
  await client.get(Uri.https('example.com', '/second'));
} finally {
  await client.close();
}
```

The guidance is reuse, not a claim that Dart IO lacks connection pooling.

## 9. Bring your own transport

The public `AlphaXTransport` contract allows test, enterprise, or specialized
implementations without forking AlphaX. A custom implementation must provide:

- honest `AlphaXCapabilities`;
- `send` and a single-consumption `sendStreaming` path;
- cancellation and normalized error behavior;
- accurate completion bytes, protocol, fallback, and timing fields where known;
- bounded delivery/backpressure when it advertises streaming;
- deterministic and idempotent `close()` behavior; and
- generic or specialized file-transfer behavior consistent with its capabilities.

Provider types such as Cronet, URLSession, Flutter channels, browser handles,
and native file descriptors must not leak into the public core contract. The
`alphax_test` fake and conformance helper are the supported starting point for
validation.

## 10. JSON transformation

`alphax` does not automatically move response parsing to a worker. Normal
`readAsJson()` remains explicit caller-side work. `alphax_transform` is an
optional package for a measured large buffered payload:

- input is already-buffered `Uint8List` data;
- one fresh native `Isolate.run` performs UTF-8 decode, `jsonDecode`, and the
  caller-supplied transform;
- the transform and returned result must be isolate-sendable;
- cancellation after dispatch discards the result but does not hard-kill worker
  CPU work;
- Web background execution is unsupported and fails closed; and
- there is no universal byte threshold, persistent worker, middleware, or
  streaming JSON parser.

This is an opt-in ergonomics package, not transport ownership or a promise of
lower total latency.

## 11. Package selection

| Package | Purpose | Common use |
| --- | --- | --- |
| `alphax` | pure-Dart contracts and policies | all AlphaX applications |
| `alphax_native` | Dart IO, Cronet/HttpEngine, URLSession, local files, automatic native factory | Flutter Android/iOS/macOS/Linux/Windows |
| `alphax_web` | Browser Fetch transport | Flutter Web or browser Dart |
| `alphax_test` | fakes, fixtures, conformance | development dependencies |
| `alphax_dio` | Dio `HttpClientAdapter` boundary | existing Dio applications |
| `alphax_transform` | optional one-shot large buffered JSON transform | profiled native Flutter/Dart UI workloads |

Common combinations are `alphax` + `alphax_native`, `alphax` + `alphax_web`,
`alphax` + `alphax_native` + `alphax_dio`, and an optional `alphax_test` or
`alphax_transform` addition.

## 12. Factual ecosystem comparisons

### `package:http` and its native clients

`package:http` deliberately provides a small `BaseClient`/`Client` abstraction.
The ecosystem also provides separate `cronet_http` and `cupertino_http` clients.
AlphaX does not claim that those clients are slow or that Dart IO has no reuse.

AlphaX's different contract is a typed transport seam with normalized capability
discovery, protocol preference versus requirement, completion-time protocol and
fallback facts, portable policy middleware, bounded streaming/file operations,
and shared conformance helpers. An application that only needs the thin common
HTTP API may reasonably choose `package:http` plus its native client.

### Dio

Dio remains a capable client with its interceptor, transformer, cancellation,
response, and adapter ecosystem. `alphax_dio` is intentionally a focused
adapter, not a replacement for all Dio APIs. AlphaX contributes its transport,
policy, capability, protocol, error, and file boundaries below Dio. Dio's
transformer behavior is response-processing behavior and must not be read as a
network transport speed claim.

### Nitro

The available Nitro package evidence describes a general native/runtime and FFI
tooling ecosystem rather than a directly comparable AlphaX HTTP client contract.
No Nitro HTTP feature is marked as equivalent or inferior here without a
verified implementation match.

## 13. Documentation changes

Current-facing guidance now includes:

- root README quick start using the automatic native factory;
- explicit Web setup and explicit adapter choices;
- “Choose your level of control” progressive disclosure;
- package-selection and long-lived-client guidance;
- defaults and portable customization matrices;
- platform/provider ownership boundaries;
- protocol preference, requirement, actual, and fallback examples;
- custom transport expectations;
- factual Dio and `package:http` comparisons;
- optional `alphax_transform` behavior and limitations; and
- links from all six package READMEs to the full user guide where appropriate.

The examples in the native, Web, transform, core documentation test, Dio, and
package README paths were inspected or compile-tested. Historical benchmark,
release-review, and signing evidence was not rewritten.

## 14. Security and release-boundary review

The reviewed current-facing documentation preserves these boundaries:

- platform trust remains enabled by default;
- trust-all behavior is not exposed;
- pin mismatch and unsupported pin/trust/proxy policies fail closed;
- redirect credential stripping remains part of native behavior;
- native errors are not the recommended application contract;
- credentials, payloads, debug names, and provider handles are not documented
  as diagnostic output;
- no certificates, signing material, development team identifiers, or local
  machine paths are part of the package publication set; and
- no diagnostic QUIC hint or advanced H3 control is presented as production API.

Known limitations remain non-blocking release boundaries: Dart IO H1 scope,
browser protocol opacity, provider-limited trust/proxy features, no mTLS
guarantee, no automatic core parsing, buffered/native-only transform behavior,
no worker pool, no universal zero-copy claim, no common DoH/0-RTT/migration API,
and CocoaPods rather than Swift Package Manager for the Apple plugin.

The standalone Android Gradle unit-test project limitation, absence of a physical
Android run, and missing signed physical-iPhone provisioning remain prior
non-blocking validation limitations. This task does not change native runtime
semantics beyond the automatic factory or require a new physical-device campaign.

## 15. Validation status

No Phase 0 or integration-cost benchmark was rerun.

The task validation set is:

| Check | Result |
| --- | --- |
| Scoped Dart formatting | passed |
| Dart analysis for all six packages | passed |
| Flutter analysis for native package/examples | passed |
| `alphax` tests, including documentation snippets | 72 passed |
| `alphax_test` tests | 10 passed |
| `alphax_native` Flutter tests | 41 passed |
| `alphax_web` tests | 2 passed |
| `alphax_dio` tests | 6 passed |
| `alphax_transform` tests | 11 passed |
| Transform/native example analysis and executable compilation | passed |
| Web example analysis and JS compilation | passed |
| Android profile and release build | passed |
| Clean disposable macOS Flutter consumer build | passed |
| Clean disposable iOS simulator/no-code-sign build | passed |
| Dartdoc for all six packages | generated successfully |
| Workspace dependency resolution | passed |
| `git diff --check` before final staging | passed |
| Six post-commit `dart pub publish --dry-run` checks | passed with zero warnings |

The existing generated Waypoint Apple project initially used stale Pods and did
not contain the newly added native source files. A disposable local consumer was
used to regenerate Pods and prove the current package builds on macOS and the iOS
simulator; no repository user/signing files were changed.

The post-commit package dry-runs completed with zero warnings and these compressed
archive sizes: `alphax` 54 KB, `alphax_test` 12 KB, `alphax_native` 94 KB,
`alphax_web` 11 KB, `alphax_dio` 15 KB, and `alphax_transform` 14 KB. Archive
inspection found only package source, documentation, examples, tests, and the
intended native plugin assets; no benchmark raw data, signing material, private
certificates, or local machine paths were included.

## 16. Worktree and publication disposition

Only Task 44 files will be committed. The following remain intentionally
unstaged:

- pre-existing benchmark Android Gradle files;
- pre-existing benchmark iOS project/signing files;
- benchmark harnesses and raw integration-cost evidence;
- historical Task 36/37/42/43 evidence and review artifacts; and
- ignored logs/build output.

No package will be published, no tag will be created, and no GitHub release will
be created by this task.

## 17. Commits and remote

Task-owned changes were delivered in four focused commits:

| Commit | Subject |
| --- | --- |
| `8813673` | `feat: add automatic AlphaX transport selection` |
| `d8753c3` | `docs: document AlphaX configuration and transport control` |
| `2ab706e` | `docs: record final AlphaX release review validation` |
| `1080f29` | `docs: record AlphaX UX review commits` |

The commits were pushed to `origin/main`. A final report/task bookkeeping update
is part of the current handoff; the final remote check confirms that `HEAD` and
`origin/main` match.

## 18. Remaining blockers

There are no Task 44 correctness or documentation blockers after the automatic
factory correction and documentation validation. Publication still requires a
separate explicit maintainer instruction.

READY TO PUBLISH ALPHAX 1.0.0-RC.4
