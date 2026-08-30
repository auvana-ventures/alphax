# AlphaX rc.5 HTTP Compatibility Review

Task 49 adds `alphax_http` as a narrow interoperability seam for libraries that
accept an injected `package:http` client. It does not add another transport or
another request policy layer.

## 1. Final public API

The package exposes one public class from `package:alphax_http/alphax_http.dart`:

```dart
final alpha = await createAlphaXClient();
final httpClient = AlphaXHttpClient(alpha);
```

`AlphaXHttpClient` extends `package:http`'s `BaseClient` and implements
`send(BaseRequest)` by delegating to the injected `AlphaXClient`. There are no
public AlphaX-specific request, response, transport, middleware, options, or
ownership types in this package.

Direct AlphaX construction remains available:

```dart
final explicit = AlphaXClient(transport: MyTransport());
final httpClient = AlphaXHttpClient(explicit);
```

The boundary was reconfirmed against `package:http` 1.6.0: `BaseClient.send` is
the maintained injection seam, and implementing it is sufficient for normal
`Client` convenience methods. No Flutter or native/provider dependency is
needed by the compatibility package.

## 2. Dependency graph

Runtime dependencies are intentionally:

```text
alphax_http
├── alphax
└── http
```

Development dependencies are `alphax_test`, `test`, and `lints`. Chopper,
GraphQL, OpenAPI tooling, Flutter, Dio, `alphax_native`, and `alphax_web` are
fixture/application dependencies only; none enters the runtime graph.

The package uses the repository's coordinated source version
`1.0.0-rc.4`. No rc.5 package was published and no version policy was changed.

## 3. Ownership model

`AlphaXHttpClient(alphaClient)` borrows the injected client. The adapter does
not own or close it, and no ownership flag or alternate wrapper constructor was
needed.

```dart
final alpha = await createAlphaXClient();
final http = AlphaXHttpClient(alpha);

http.close();       // closes only the package:http view
await alpha.close(); // the caller closes AlphaX and its transport
```

The borrowed contract is documented and tested. It avoids surprising a caller
that shares an `AlphaXClient` with direct AlphaX code or another adapter.

## 4. Request mapping

| `package:http` input | AlphaX mapping |
| --- | --- |
| `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS` | Corresponding `HttpMethod` |
| Other methods | Deterministic `ClientException`; the AlphaX request contract has no value to represent them |
| URL | The original `Uri` object, without parse/reconstruction |
| Headers | All finalized `BaseRequest.headers` entries through `AlphaXHeaders.fromEntries`; repeated values remain represented |
| `contentLength` | `AlphaXStreamBody.contentLength`, including unknown length |
| Finalized body | `AlphaXStreamBody` over the original `Stream<List<int>>` |
| `followRedirects`, `maxRedirects` | AlphaX follow/manual mode and redirect limit |
| Persistent connection preference | Not mapped; AlphaX has no corresponding request field |
| Timeout, protocol, progress | Not installed or invented; these remain direct AlphaX concerns |

`finalize()` is called before headers are copied so package:http requests such as
`MultipartRequest` have added their final content type and length metadata.

## 5. Request streaming

The bridge passes the finalized package:http body stream directly to
`AlphaXStreamBody`. It does not eagerly buffer normal requests, including
`StreamedRequest` bodies with known or unknown content length and large chunks.
The AlphaX transport controls consumption and backpressure through its existing
stream contract. A stream body remains single-use unless the caller supplied a
replayable body through the AlphaX API; the bridge does not add a replay cache.

The deterministic tests cover empty bodies, bytes, known and unknown lengths,
large streamed bodies, and body reuse through concurrent requests. Any buffering
in the tested recording transport belongs to that test transport, not the
production bridge.

## 6. Multipart

`MultipartRequest` is finalized by package:http and its already-encoded stream
is passed through unchanged. The bridge does not implement a second multipart
encoder. Tests cover fields, text, binary bytes, filename, content type,
content length, and a streamed multipart file part.

## 7. Response streaming

The response path is fundamentally:

```text
AlphaX response stream → package:http StreamedResponse
```

The bridge does not turn every response into a buffered `http.Response`.
`StreamedResponse` receives status, joined public headers, known content length,
the original request, and AlphaX redirect status metadata. The response stream
is not listened to until the package:http consumer listens. Subscription pause,
resume, and cancellation are forwarded to the AlphaX stream where its stream
contract supports those operations.

AlphaX currently has no authoritative reason phrase, redirect-hop list, or
persistent-connection observation. The adapter therefore leaves reason phrase
unknown, does not invent redirect hops, and uses package:http's required
persistent-connection interface default rather than claiming an observed
transport fact.

## 8. Error mapping

The compatibility contract is deterministic:

| AlphaX result | `package:http` result |
| --- | --- |
| HTTP 4xx/5xx response | Normal `StreamedResponse`; status is not converted to a transport exception |
| `AlphaXCancellationException` | `RequestAbortedException` |
| Other `AlphaXException` | `ClientException` with normalized AlphaX kind/message and request URI |
| Unknown provider/internal exception | Generic `ClientException` without provider-specific detail |
| Existing `ClientException` | Preserved |

Response body failures are mapped on the response stream, so they do not force
buffering. Native provider exception classes are not the primary compatibility
contract, and request headers/body data are not logged.

## 9. Cancellation limitations

`AbortableRequest.abortTrigger` is bridged to an `AlphaXCancellationToken`.
Cancellation before headers fails `send` with `RequestAbortedException`; for an
unbuffered response it terminates the response stream with the same standard
exception. A buffered response has already completed the AlphaX operation when
its `StreamedResponse` is returned, so the adapter does not manufacture a later
abort for that completed body.

Cancelling a package:http response subscription cancels the underlying AlphaX
response subscription. A streamed request body receives the AlphaX token, but
`BaseClient` has no separate request-body cancellation hook, so cancellation of
the body producer itself remains transport-dependent. `http.Client.close()` on
this borrowed adapter does not cancel active AlphaX work. Rich cancellation
reasons and AlphaX cancellation tokens remain available through direct AlphaX
requests only.

## 10. Timeout limitations

The adapter does not add a timeout parameter or silently install an AlphaX
timeout policy. A package:http consumer or framework that wraps the returned
future retains its existing timeout semantics. AlphaX connect/request/read/
overall timeout phases remain available through direct AlphaX request usage.

## 11. Redirect and security semantics

`followRedirects` and non-negative `maxRedirects` are transferred to AlphaX's
follow/manual redirect policy. Invalid negative limits fail as a
`ClientException`. AlphaX remains responsible for redirect credential
stripping, secure TLS defaults, certificate pinning, and proxy policy. The
compatibility layer does not add trust-all behavior or weaken cross-origin
credential protection.

Browser-owned TLS, proxy routing, CORS, redirect behavior, and protocol
authority remain browser concerns when the underlying client is built with
`alphax_web`; `alphax_http` does not turn a browser request into a native one.

## 12. Capability-loss matrix

| AlphaX capability | Through `AlphaXHttpClient` | Direct AlphaX path |
| --- | --- | --- |
| `AlphaXCapabilities` | Not observable through `StreamedResponse` | Available |
| Protocol preference/requirement | Not representable by `BaseRequest` | Available |
| Actual protocol and fallback metadata | Not representable by `StreamedResponse` | Available after completion |
| Completion metrics | Not exposed | Available |
| Native file paths | Not representable | Available on supported transports |
| AlphaX progress callbacks | Not representable | Available |
| Rich cancellation | Only `AbortableRequest` trigger semantics | Available |
| Rich timeout phases | Not representable; no timeout is installed | Available |
| TLS/proxy construction controls | Configure the underlying AlphaX transport first; not request fields | Available at transport/client construction |
| Middleware/auth/cookies/retry/cache/resilience | Remain active when configured on the underlying AlphaX client | Available |

Using the seam is therefore interoperability, not full AlphaX API parity.

## 13. Close and lifecycle

Each adapter has one injected AlphaX client. `send` creates neither a client nor
a transport and performs no provider initialization. Concurrent requests reuse
the same AlphaX client and transport.

`close()` is idempotent, marks the adapter closed, and rejects later sends. It
does not close or cancel the borrowed AlphaX client, and active response streams
may finish. The AlphaX owner calls `AlphaXClient.close()`; existing AlphaX
ownership then closes the one underlying transport. These behaviors are covered
by close, repeated-close, reuse, active-stream, and independently-closed-client
tests.

## 14. `package:http` conformance

Focused deterministic tests cover:

- GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS;
- URI/query identity, headers, empty/bytes/streamed bodies, known/unknown length;
- streamed response metadata and inherited buffered convenience behavior;
- multipart fields and streamed file parts;
- redirects, errors, HTTP error statuses, close, reuse, and concurrency;
- `AbortableRequest` cancellation and response subscription cancellation.

The maintained `package:http` public seam is `BaseClient.send`; no separate
public conformance utility was required. Existing AlphaX transport conformance
suites were reused through `alphax_test` only where appropriate and were not
duplicated in the production package.

## 15. Chopper result

A disposable fixture used maintained Chopper `8.7.0` and
`chopper_generator 8.7.0`. It generated a service, injected `AlphaXHttpClient`,
and passed analysis/tests for:

- GET path and query mapping;
- POST JSON request mapping;
- typed `JsonConverter` responses;
- error responses;
- request and response interceptors above the `http.Client` boundary.

Classification: `SUPPORTED_VIA_ALPHAX_HTTP`.

No Chopper dependency or framework-specific behavior was added to `alphax_http`.

## 16. GraphQL HTTP result

A disposable fixture used `graphql 5.2.4` and `gql_http_link 1.2.0`. Its
`HttpLink` received the injected adapter and passed analysis/tests for a query,
variables, a response, and GraphQL-level error behavior.

Classification: `SUPPORTED_VIA_ALPHAX_HTTP`.

GraphQL parsing, caching, and error semantics remain GraphQL responsibilities;
none was added to the compatibility package.

## 17. OpenAPI/package:http result

No generator fixture was created. Setting up a representative generated client
would expand into Task H generator work, which is outside this locked task.
The general seam was validated independently with the generic consumer fixture.

Classification: `SUPPORTED_WHEN_HTTP_CLIENT_INJECTABLE`.

Generator-specific validation remains bounded to the later Task H scope.

## 18. Generic consumer result

A minimal fixture accepted only `package:http`'s `Client` type and had no AlphaX
knowledge. It performed a request through the injected `AlphaXHttpClient` and
passed with the shared deterministic `FakeAlphaXTransport`.

Classification: generic `http.Client` consumers are supported through the
standard injection seam, subject to the capability limitations above.

## 19. Package size and dry-run

`dart pub publish --dry-run` listed only the intended package files: changelog,
license, README, analysis options, public library, one private implementation,
pubspec, and two tests. The compressed archive was 12 KB. The pre-commit run
reported only the expected local dirty-git-state warning; package validation
reported no content, path, secret, fixture-output, or signing-material issue.

Dependency inspection confirmed the runtime graph is limited to `alphax` and
`http`. No fixture build output or temporary generated source is shipped.

## 20. Documentation

Updated:

- root `README.md` with deployment-path framing and an optional “package that
  expects `package:http`?” escape hatch;
- `docs/USAGE_AND_CUSTOMIZATION.md` with the compatibility configuration,
  ownership, browser/security, and capability-loss guidance;
- `packages/alphax_http/README.md` with the API, Chopper example, streaming,
  lifecycle, and limitations;
- `tasks/49-alphax-http-compatibility.md` with scope, outcome, and validation.

The ordinary AlphaX installation remains the native/Web entry package. The
compatibility package is not presented as another primary product and no
architecture document was reopened.

## 21. Validation

Passed:

- `dart format --output=none --set-exit-if-changed packages/alphax_http/lib packages/alphax_http/test`;
- `bash tooling/scripts/analyze_dart_packages.sh`;
- `bash tooling/scripts/test_packages.sh` — all seven workspace packages,
  including the existing six AlphaX package suites, passed;
- `dart analyze` and `dart test` in `packages/alphax_http`;
- Chopper generation, analysis, and fixture tests;
- GraphQL HTTP fixture analysis and tests;
- local production-capable Dart IO transport Flutter fixture;
- Web package compile-to-JavaScript smoke test;
- `dart doc --dry-run` for `alphax_http`;
- `dart pub publish --dry-run` and archive inspection;
- runtime dependency, security, secret/signing/path audits;
- Markdown/internal-link checks and `git diff --check`.

No performance benchmark was run. Android, macOS, and iOS builds were not
rerun because this task changed no native platform package or native build
source; the required real transport smoke used the existing Dart IO API, and
the package has no Flutter/provider runtime dependency.

## 22. Remaining limitations

- `package:http` cannot carry AlphaX protocol facts, completion metrics,
  progress, file-path, rich timeout, or rich cancellation contracts.
- Request-body cancellation is limited by the `BaseClient` contract and the
  selected transport's stream cancellation behavior.
- AlphaX-supported methods remain the bridge's supported method set; arbitrary
  extension methods cannot be represented by the current AlphaX request type.
- Browser authority remains browser-owned under `alphax_web`.
- OpenAPI generated-client fixture validation is deferred to Task H when bounded
  generator work is in scope.
- The pure-Dart built-in Dart IO provider packaging limitation remains POST_1_0;
  no `alphax_io` package was created.

## 23. Exact next task

Return for maintainer review. After approval, the next locked feature is Task C —
first-class SSE. SSE, WebSocket, generator, OpenAPI, and broader ecosystem work
are not part of Task 49.

RC5 ALPHAX_HTTP READY
