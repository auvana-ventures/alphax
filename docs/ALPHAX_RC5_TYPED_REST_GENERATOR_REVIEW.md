# AlphaX rc.5 direct typed REST generator review

Task E adds one AlphaX-owned development-time source-generation surface. It is
bounded to ordinary typed REST declarations and emits direct `AlphaXClient`
calls. It does not change the existing Retrofit → Dio → `alphax_dio` path and
does not begin OpenAPI, Protobuf, or ecosystem-template work.

## 1. Final package structure

The implementation adds one package only:

```text
packages/alphax_generator/
├── build.yaml
├── lib/alphax_generator.dart
├── lib/builder.dart
├── lib/src/alpha_x_api_generator.dart
└── test/
```

Lightweight annotations, `AlphaXRequestOptions`, empty-body-aware response
helpers, and `AlphaXApiResponse<T>` are additive APIs in `alphax`. No
`alphax_annotations`, `alphax_codegen_core`, runtime model package, or
framework-specific package was created.

## 2. Annotations

`package:alphax/annotations.dart` contains const metadata only:

- `AlphaXApi`, `AlphaXGet`, `AlphaXPost`, `AlphaXPut`, `AlphaXPatch`,
  `AlphaXDelete`, and `AlphaXHead`;
- `AlphaXPath`, `AlphaXQuery`, and `AlphaXHeader`;
- `AlphaXBodyParam` with JSON, text, bytes, stream, file, and multipart
  encodings;
- `AlphaXDecode`, `AlphaXOptions`, `AlphaXCancellation`,
  `AlphaXFileSourceParam`, and `AlphaXFileTargetParam`.

The metadata has no analyzer, source_gen, build_runner, model-generator, or
Flutter dependency. The default `package:alphax/alphax.dart` surface remains
focused; `alphax_native` and `alphax_web` re-export `annotations.dart` so
deployment-family declarations retain the one-import experience. A pure-Dart
declaration can import `alphax.dart` and `annotations.dart` explicitly.

`AlphaXBodyParam` is intentional: `AlphaXBody` and the existing
`AlphaXRequestBody` alias remain unambiguous runtime types.

## 3. Generator API

The public tooling surface is `AlphaXApiGenerator` and the normal
`alphaxBuilder` build_runner builder. A declaration uses an AlphaX-owned
annotation namespace and a redirecting factory:

```dart
@AlphaXApi(baseUrl: 'https://api.example.com')
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXGet('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<User> getUser(@AlphaXPath('id') String id);
}
```

The generator emits a conventional `.g.dart` part using build_runner and
source_gen. It performs generation-time validation rather than reflection or a
runtime registry.

## 4. Generated architecture

Generated services contain one borrowed `AlphaXClient` field and construct
`AlphaXRequest` values directly. The request path is:

```text
AlphaX annotations → alphax_generator → AlphaXRequest → AlphaXClient → AlphaXTransport
```

The generated source has no Dio, Retrofit, Chopper, GraphQL, OpenAPI,
Protobuf, or `package:http` runtime calls. The native and Web generated-source
audit tests verify that seam directly.

## 5. Dependency graph

The new package's tooling graph is:

```text
alphax_generator
├── alphax                 (annotations and AlphaX contracts)
├── analyzer
├── build
├── build_config
├── dart_style
└── source_gen
```

`build_runner`, `source_gen_test`, and `test` are development dependencies.
The generator package owns tooling dependencies because it is the tooling
package; normal generated application runtime dependencies do not include
analyzer, source_gen, or build_runner.

The clean native fixture declares only `alphax_native` as its direct AlphaX
runtime dependency. Its direct `alphax`, generator, model tooling, and test
packages are development dependencies. The clean Web fixture has the same
shape with `alphax_web` as its only direct AlphaX runtime dependency.

## 6. HTTP methods

GET, POST, PUT, PATCH, DELETE, and HEAD are supported. Each ordinary generated
method maps to `AlphaXRequest` and `_client.send(request)`. File uploads and
downloads use the existing `AlphaXClient.upload` and `AlphaXClient.download`
operations instead of buffering files into a new generator-specific body path.

## 7. URL, path, query, and header mapping

URL resolution uses Dart `Uri` semantics:

- relative endpoints resolve against the API base URL;
- a leading slash replaces the base path;
- absolute `http`/`https` endpoints do not inherit the base URL query;
- for relative endpoints, base and endpoint query values are retained;
- generated query values are appended for repeated keys;
- null query values are omitted;
- scalar values use `toString()`, enum values use `.name`, and iterable values
  produce repeated query keys;
- path values use `Uri.encodeComponent` per placeholder segment;
- missing, duplicate, or unused path bindings are generation errors.

API static headers are emitted first, method static headers replace them
case-insensitively, and dynamic header bindings are emitted last and replace a
static value. Header names and static values are validated for unsafe syntax.
Generated code never logs header values.

## 8. Request bodies

`AlphaXBodyParam` supports:

- JSON-safe primitives, maps, and lists directly;
- custom JSON objects through a zero-argument caller-owned `toJson()` hook;
- text through `AlphaXBody.text`;
- bytes through `AlphaXBody.bytes`;
- caller-owned `Stream<List<int>>` through `AlphaXStreamBody`;
- `AlphaXFileSource` through `AlphaXFileBody`; and
- existing `AlphaXMultipartBody` values without a second multipart encoder.

No json_serializable, Freezed, built_value, or Protobuf dependency is embedded
in the generator.

## 9. Response decoding

Generated methods support `Future<T>` for `String`, bytes, JSON-safe primitive
values, maps/lists, and caller-provided typed decoders. `@AlphaXDecode` accepts
a constrained Dart callable expression such as `User.fromJson` or
`decodeUser`; list-of-model responses map that decoder over decoded JSON list
items.

Callers needing metadata can return `Future<AlphaXApiResponse<T>>`, which keeps
the decoded value together with the original `AlphaXResponse`, status, headers,
protocol, redirects, and metrics. Raw `AlphaXResponse`, `void`,
`Stream<List<int>>`, `Future<Stream<List<int>>>`, and file-transfer results are
also supported where their representations are coherent.

## 10. Nullability

The generator respects Dart null safety. Nullable `String` and byte returns use
empty-body-aware `AlphaXResponse` helpers; nullable JSON/model returns preserve
an empty body as `null`. Non-nullable returns use the normal decoding helpers.
Nullable path, file-source, and file-target parameters are rejected. A file
operation must return `Future<AlphaXTransferResult>`, and unsupported wrapper
combinations are diagnosed during generation rather than producing a partial
client.

## 11. HTTP error semantics

Generated code does not convert HTTP 4xx/5xx responses into transport
exceptions. Typed methods decode the AlphaX response body according to their
declared return type; raw and wrapper returns preserve status and headers.
Transport, TLS, timeout, cancellation, body-stream, and decoding failures
retain their normal AlphaX error behavior.

## 12. Cancellation and request options

Generated methods can bind the existing `AlphaXCancellationToken` directly or
use the compact additive `AlphaXRequestOptions` bundle. The bundle carries
existing request-scoped timeouts, cancellation, protocol preference and
requirement, redirect policy, priority, and progress callbacks. No second
cancellation or timeout system was introduced, and no factory-level request
policy was added.

Protocol preference remains allowed to fall back; protocol requirement remains
fail-closed through the existing `AlphaXRequest` contract. Generated services
do not hide completion metadata when callers select the response wrapper.

## 13. Multipart and file support

The fixture exercises text fields, binary multipart parts, filenames, content
types, and content lengths through `AlphaXMultipartBody`. Uploads use
`AlphaXFileSource`; downloads use `AlphaXFileTarget`. The generated code calls
the existing AlphaX transfer APIs, preserving native/file-provider optimization
opportunities and avoiding an eager byte-buffering layer.

## 14. Streaming support

`Stream<List<int>>` and `Future<Stream<List<int>>>` methods expose the existing
AlphaX response stream. Generated code does not JSON-decode an unbounded stream
and does not add SSE or WebSocket semantics. A caller can apply
`AlphaXSseParser` separately when an endpoint is an SSE endpoint.

## 15. Diagnostics

Generation diagnostics cover invalid API declarations, missing or duplicate
path/body/options bindings, invalid paths and headers, unsupported parameter
combinations, missing decoders, invalid body types, unsupported stream/file
returns, and unsupported query maps. Errors identify the API and method and
include an actionable `todo`.

The pure-Dart generator diagnostic fixture covers missing path bindings,
duplicate bodies, missing decoders, and a valid generation surface. The
separate pure-Dart consumer also compiles the generated output and runs it
against a caller-supplied fake transport. The native fixture additionally runs
the generated output against fake and local transports.

## 16. Model compatibility

Serialization stays caller-owned. The native fixture includes:

- a manual `fromJson`/`toJson` model;
- a json_serializable model and decoder wrapper; and
- a Freezed plus json_serializable model and decoder wrapper.

Those model packages appear only in fixture dependencies and do not enter the
generator or AlphaX runtime graph.

The pure-Dart fixture has only `alphax` as a direct runtime dependency and
explicitly supplies its `AlphaXClient`; its generated API is the same
transport-neutral source consumed by the deployment-package fixtures.

## 17. Native consumer

`examples/typed_rest` is a clean Flutter consumer. Its declaration imports only
`package:alphax_native/alphax_native.dart`, uses one `createAlphaXClient()`
call, performs a generated GET in `native_example.dart`, and closes the
caller-owned client. The fixture builds generated output, analyzes, tests
against a local Dart IO API, and covers all common methods, options,
serialization hooks, files, multipart, streams, cancellation, timeout, and
concurrency behavior.

The native commands `flutter pub get`, `dart run build_runner build`,
`flutter analyze`, and `flutter test` completed successfully; the final fixture
run reported 9 passing tests.

## 18. Web consumer

`examples/typed_rest_web` is a clean Dart Web consumer. Its declaration imports
only `package:alphax_web/alphax_web.dart`, creates the synchronous browser
client, performs a generated GET in the compile-tested example function, and
closes the caller-owned client. Its generated implementation remains
transport-independent and uses no native/provider type.

`dart run build_runner build`, `dart analyze`, `dart test`, and
`dart compile js lib/web_example.dart` completed successfully. Browser Fetch,
CORS, TLS, proxy routing, and protocol behavior remain the responsibility of
the Web provider and browser.

## 19. Retrofit coexistence

The existing path remains supported and unchanged:

```text
Retrofit generated client → Dio → AlphaXDioAdapter → AlphaX
```

The direct generator is an additional AlphaX-owned option for new declarations;
it is not a migration requirement and does not add a Retrofit or Dio dependency.

## 20. Generator lifecycle and client ownership

Every generated service borrows the `AlphaXClient` supplied to its factory. It
does not create a client or transport in a generated method, does not initialize
a provider per request, and never closes the injected client automatically.
One caller-owned client can be shared across multiple generated services. The
caller closes that client after all services stop using it, so the existing
AlphaX client-to-transport ownership remains authoritative.

## 21. Security review

The generated seam preserves AlphaX TLS, pinning, proxy, redirect, protocol
requirement, authentication middleware, and cancellation policies. It does not
trust invalid certificates, convert requirements into preferences, catch and
hide security failures, or introduce a new auth framework.

Static annotation headers are emitted into source and the documentation warns
against placing credentials or other secrets there. Dynamic sensitive headers
remain application-owned. Generated code contains no request/response logging,
credential logging, body logging, or generation-time secret embedding. The
source and path audits found no private keys, signing material, user-local
source paths, generated build output, or secret fixtures in Task E package
artifacts. The Web fixture's `/tmp` JavaScript output is a disposable command
destination only and is not shipped.

## 22. Package sizes and dry-runs

Final dry-run archive sizes before the Task E commit were:

| Package | Compressed archive | Warnings | Result |
| --- | ---: | ---: | --- |
| `alphax` | 66 KB | 1 expected dirty-worktree warning | pass |
| `alphax_generator` | 17 KB | 1 expected dirty-worktree warning | pass |
| `alphax_native` | 103 KB | 1 expected dirty-worktree warning | pass |
| `alphax_web` | 17 KB | 1 expected dirty-worktree warning | pass |

The warnings identify the intentional Task E edits in the still-dirty
worktree. Archive listings contain the intended public/runtime files only;
they contain no `.dart_tool`, build output, generated fixture output, local
paths, secrets, or signing material. The generator archive contains its
README, license, builder, source, and focused diagnostics fixture only.

## 23. Validation

The consolidated validation completed with these results:

- `dart format --set-exit-if-changed` over all Task E Dart sources: pass;
- Dart analysis for the affected AlphaX packages: pass;
- `dart test packages/alphax`: 95 tests passed;
- `dart test packages/alphax_generator`: 4 tests passed;
- native generated-consumer build, Flutter analysis, and 9 fixture tests: pass;
- pure-Dart generated-consumer build, analysis, and focused transport test:
  pass;
- Web generated-consumer build, analysis, tests, and JavaScript compilation:
  pass;
- `./tooling/scripts/test_packages.sh`: all 8 current AlphaX package suites
  passed (`alphax`, `alphax_native`, `alphax_web`, `alphax_test`, `alphax_dio`,
  `alphax_transform`, `alphax_http`, and `alphax_generator`);
- `dart doc --validate-links` for all 8 workspace packages: 0 errors. The
  repository's existing package README/example cross-package references
  produced 6 warnings for `alphax`, 7 for `alphax_native`, 5 for `alphax_web`,
  0 for `alphax_dio`, 0 for `alphax_test`, 1 for `alphax_transform`, 0 for
  `alphax_http`, and 3 for `alphax_generator`;
- Markdownlint with repository-standard `MD013`, `MD033`, and `MD060`
  exclusions: pass for Task E Markdown;
- relative Markdown target check: pass for the changed documentation set;
- dependency graph, generated-seam, security/path, and archive inspections:
  pass, with the disposable Web `/tmp` command path noted above;
- `git diff --check`: pass;
- no performance benchmark was run.

Android, Apple, and browser platform transport builds were not changed by this
transport-independent generator task; the native and Web generated consumers
were the relevant platform-boundary checks.

## 24. Deferred generator capabilities

The direct generator foundation intentionally defers generic dynamic model
systems, polymorphic/custom converter registries, query maps, exhaustive
response-status annotations, advanced streaming transforms, OpenAPI parsing and
templates, Protobuf ergonomics, and framework-specific integrations. No Task F,
G, or H work was started. The generated AlphaX request/decoder seam is the
bounded contract those later decisions may target.

## 25. Exact next decision: F/G/H

Task E is ready for maintainer review. After approval, the maintainer—not this
implementation—chooses whether to complete or defer one of the bounded optional
follow-ups:

- F — OpenAPI template proof;
- G — Protobuf ergonomics; or
- H — ecosystem compatibility validation.

No follow-up task is started automatically.

RC5 TYPED REST GENERATOR READY
