<!-- markdownlint-disable MD013 -->

# AlphaX ecosystem compatibility review

## Executive result

RETROFIT_SUPPORTED_VIA_ALPHAX_DIO

The maintained Retrofit generator produced a client that ran through the
intended boundary without a Retrofit fork or an AlphaX production-code change:

```text
Retrofit annotations
  → retrofit_generator/build_runner
  → generated Dio client
  → Dio
  → AlphaXDioAdapter
  → AlphaXClient
  → FakeAlphaXTransport
```

The review used a disposable, deterministic fixture with local path
dependencies on the RC4 `alphax`, `alphax_dio`, and `alphax_test` packages. The
fixture did not add Retrofit or code-generation dependencies to any AlphaX
manifest and did not exercise a live network or benchmark transport speed.

No `alphax_dio` runtime or public API correction was required. The coordinated
`1.0.0-rc.4` package set remains unchanged and no publication action was taken.

## 1. Fixture environment and dependency resolution

| Component | Resolved version | Role |
| --- | ---: | --- |
| Dart SDK | 3.13.0 | Native VM validation |
| Flutter SDK | 3.47.0 | Repository context only; no Flutter fixture was required |
| `alphax` | 1.0.0-rc.4, local path | Core contract and client |
| `alphax_dio` | 1.0.0-rc.4, local path | Dio `HttpClientAdapter` under test |
| `alphax_test` | 1.0.0-rc.4, local path | Deterministic fake transport |
| Dio | 5.11.0 | Generated-client runtime |
| Retrofit | 4.10.0 | Runtime annotations and `HttpResponse` types |
| `retrofit_generator` | 10.2.9 | Generated implementation |
| `build_runner` | 2.16.0 | Code-generation runner |
| `json_annotation` | 4.12.0 | Ordinary DTO annotations |
| `json_serializable` | 6.14.1 | Ordinary DTO generation |
| Freezed | 4.0.1 | Optional DTO generation check |
| `freezed_annotation` | 3.1.0 | Freezed annotations |

The hosted Retrofit and generator packages were resolved from the maintained
pub.dev releases available on 2026-08-29. The fixture used a local
`dependency_overrides` entry only for the unpublished local `alphax` package;
the override was not applied to repository manifests or published packages.

Official package references: [`retrofit`](https://pub.dev/packages/retrofit),
[`retrofit_generator`](https://pub.dev/packages/retrofit_generator), and the
[Retrofit API documentation](https://pub.dev/documentation/retrofit/latest/).

## 2. Generated-client architecture

The fixture declared a normal Retrofit interface with a generated factory:

```dart
@RestApi(baseUrl: 'https://example.test/api/')
abstract class FixtureApi {
  factory FixtureApi(Dio dio, {String? baseUrl}) = _FixtureApi;

  @GET('/users/{id}')
  Future<User> getUser(
    @Path('id') String id,
    @Query('search') String search,
    @Header('X-Request-ID') String requestId,
  );
}
```

The generated `_FixtureApi` called `_dio.fetch(...)` with ordinary Dio
`RequestOptions`. `AlphaXDioAdapter.fetch` converted those options into an
`AlphaXRequest`, and the fake transport recorded the request before returning a
deterministic `AlphaXResponse`. No AlphaX type appeared in the Retrofit
interface or generated source.

The generated part was produced from a clean fixture with:

```sh
dart run build_runner build
```

The generated source compiled under `dart analyze` and the fixture executable
ran successfully. Running the generator again produced no unexpected source
changes.

## 3. Tested Retrofit features

| Generated behavior | Result | Evidence |
| --- | --- | --- |
| GET | Passed | Generated call reached `AlphaXRequest` with `HttpMethod.get`. |
| Path parameter | Passed | Path was preserved through Dio URI composition and the adapter. |
| Query parameter | Passed | Encoded query was available as the expected decoded URI parameter. |
| Header parameter | Passed | Generated header reached AlphaX headers. |
| POST JSON body | Passed | `@Body()` used the DTO's generated `toJson`; bytes reached AlphaX. |
| Typed JSON response | Passed | `User.fromJson` ran after the adapter returned the Dio response. |
| Nullable response | Passed | A 204/empty response became `User? == null`. |
| `HttpResponse<T>` wrapper | Passed | Typed data and status/header metadata were both retained. |
| Response stream | Passed | `@DioResponseType(ResponseType.stream)` generated a `Stream<Uint8List>` path. |
| Error response | Passed | Status 422 became a `DioException` with response metadata. |
| Cancellation | Passed | `@CancelRequest() CancelToken` cancelled AlphaX and mapped back to Dio cancellation. |
| Redirect/options behavior | Passed | `@DioOptions() Options` reached AlphaX redirect policy and response redirect metadata. |
| Multipart/form-data | Passed | Generated `FormData` and `MultipartFile.fromFileSync` reached AlphaX as a request stream. |
| File upload | Passed for the tested multipart shape | File bytes were included in the generated multipart request. |
| Receive progress | Passed | `@ReceiveProgress()` remained a Dio receive callback. |
| Send progress | Passed | `@SendProgress()` remained a Dio send callback for multipart upload. |

The file-upload result is specifically a Retrofit/Dio multipart request through
`fetch`. It does not claim that a generated Retrofit method invokes AlphaX's
separate native `download`/`upload` file-transfer API. Applications that need
AlphaX native file-backed transfer should use the AlphaX file API directly or
define an explicit application boundary for it.

## 4. Dio adapter compatibility

The generated client exercised the adapter behavior Retrofit depends on:

- `RequestOptions.method` became the corresponding AlphaX `HttpMethod`.
- Dio-composed URI path and query values arrived as one absolute AlphaX URI.
- Header values, including generated method headers, reached the case-insensitive
  AlphaX header collection.
- JSON and multipart request data reached the adapter as the request stream
  supplied by Dio. The adapter did not need to know about Retrofit annotations.
- `Options.contentType`, `sendTimeout`, `receiveTimeout`, redirect settings,
  response type, and cancellation were handled at the normal Dio boundary.
- AlphaX status, headers, response bytes, response stream, and redirect records
  were mapped to Dio's `ResponseBody`/`Response` model.
- AlphaX cancellation and normalized transport errors remained Dio cancellation,
  timeout, connection, TLS, or unknown `DioException` categories as appropriate.
- Protocol and completion metrics remain available through the adapter's Dio
  `ResponseBody.extra` keys; Retrofit does not hide those extras.

The compatibility boundary is the focused Dio `HttpClientAdapter`, not full
Dio source/API compatibility. Retrofit features that use ordinary Dio
`fetch`/`RequestOptions` are consequently the relevant supported surface.

## 5. Serialization compatibility

Two DTO paths were generated and exercised:

1. An ordinary `@JsonSerializable()` `User` with generated `fromJson` and
   `toJson` methods.
2. A Freezed `FreezedUser` using `freezed` plus `json_serializable` generation.

Both were application-side serialization layers. AlphaX saw only the Dio
request/response boundary and did not gain a dependency on `retrofit`,
`retrofit_generator`, `json_serializable`, Freezed, or `build_runner`.

`built_value` was not added to the fixture because it has the same architectural
relationship: its generated serializer is application-side and does not require
an HTTP transport adapter. It is classified as compatible caller-layer
serialization, not as an AlphaX integration.

### Generator-specific caveat observed

As a disposable probe, a method returning `Future<Map<String, dynamic>>` was
generated with `retrofit_generator` 10.2.9. The generator emitted an invalid
`dynamic.fromJson(...)` expression. This failed during generated-source
analysis, before any Dio or AlphaX code ran. It is therefore recorded as a
Retrofit-generator limitation, not an `AlphaXDioAdapter` incompatibility. The
verified fixture used typed DTOs and a `Future<String>` minimal documentation
example instead. Applications should validate unusual generic return shapes
against their chosen generator version.

## 6. OpenAPI-generated clients

Generated client compatibility depends on the transport abstraction selected by
the generator:

| Generated transport | Classification | Boundary |
| --- | --- | --- |
| Dio | **SUPPORTED_THROUGH_DIO** | Use the generated client's supplied/injected `Dio` with `AlphaXDioAdapter`. This is conditional on the generator not replacing Dio's normal adapter boundary with a private engine. |
| `package:http` | **NOT_INTEGRATED** | AlphaX does not ship a `package:http` `BaseClient` adapter in RC4, so a generated `package:http` client is not automatically AlphaX-backed. |
| Custom/native transport | **OUT_OF_SCOPE** | Requires a generator-specific integration or a caller-owned bridge; no universal claim is made. |

The current [`openapi_generator`](https://pub.dev/packages/openapi_generator)
documentation includes a Dio generator, so such output is a plausible
`alphax_dio` use case when its generated client accepts a caller-provided Dio.
That is a conditional ecosystem statement, not validation of every OpenAPI
generator, template, or generated feature.

## 7. Broader ecosystem classification

| Ecosystem | Classification | Verified relationship |
| --- | --- | --- |
| Dio | **SUPPORTED_DIRECTLY** | `alphax_dio` is a focused Dio 5.x `HttpClientAdapter`. |
| Retrofit | **SUPPORTED_THROUGH_DIO** | Task 45 generated-client fixture passed on the tested surface. |
| `json_serializable` | **COMPATIBLE_CALLER_LAYER** | Ordinary DTO generation passed; no AlphaX dependency. |
| Freezed | **COMPATIBLE_CALLER_LAYER** | One Freezed + JSON DTO passed; no AlphaX dependency. |
| `built_value` | **COMPATIBLE_CALLER_LAYER** | Serializer/model layer is transport-independent; not directly exercised. |
| OpenAPI-generated Dio clients | **SUPPORTED_THROUGH_DIO** | Conditional on ordinary injectable Dio usage; generator-specific validation remains required. |
| OpenAPI-generated `package:http` clients | **NOT_INTEGRATED** | No AlphaX `BaseClient` bridge exists in RC4. |
| Chopper | **NOT_INTEGRATED** | Chopper owns a `ChopperClient` and its `package:http` client boundary; no AlphaX Chopper adapter exists. |
| GraphQL clients | **NOT_INTEGRATED** | GraphQL link/HTTP/WebSocket transport remains caller-owned; no AlphaX link exists. |
| gRPC | **OUT_OF_SCOPE** | Separate RPC/protobuf client and transport scope, not AlphaX REST/HTTP client integration. |
| WebSocket | **OUT_OF_SCOPE** | AlphaX RC4 is an HTTP client; no WebSocket contract or adapter is provided. |
| SSE | **COMPATIBLE_CALLER_LAYER** | A caller may consume and parse an ordinary AlphaX response stream, but AlphaX supplies no SSE parser or event API. |

The classifications avoid treating the existence of a protocol or serializer
package as proof of an AlphaX adapter. The relevant question is whether its
caller can inject the boundary AlphaX actually provides.

References for the neighboring boundaries include the
[Chopper client API](https://pub.dev/documentation/chopper/latest/chopper/),
[`graphql`](https://pub.dev/packages/graphql),
[`grpc`](https://pub.dev/packages/grpc), and Dart's
[`web_socket`](https://pub.dev/packages/web_socket) package documentation.

## 8. Documentation changes

The current-facing documentation now includes a concise **Using Retrofit**
section in:

- [root README](../README.md);
- [usage and customization guide](USAGE_AND_CUSTOMIZATION.md); and
- [`alphax_dio` README](../packages/alphax_dio/README.md).

Each explains:

- Retrofit remains the API/code-generation layer;
- Dio remains the application client;
- AlphaX owns the transport and policy boundary below `AlphaXDioAdapter`;
- normal Retrofit annotations and generated constructors remain unchanged;
- Retrofit packages are application/tooling dependencies, not AlphaX runtime
  dependencies; and
- the integration is not a claim of universal generator or full Dio parity.

The examples use only actual public AlphaX/Dio APIs. The annotated interface
shape and generated constructor in the documentation were mirrored in the
disposable fixture; the fixture also ran the equivalent adapter wiring with
`FakeAlphaXTransport` for deterministic execution. Production applications
replace that fake transport with `createAlphaXTransport()` from
`alphax_native`.

## 9. Production changes and release impact

| Area | Result |
| --- | --- |
| `alphax` runtime | No change |
| `alphax_native` runtime | No change |
| `alphax_web` runtime | No change |
| `alphax_dio` runtime/API | No change; no adapter defect observed |
| Package dependencies | No change; no Retrofit dependency added |
| RC version | Remains `1.0.0-rc.4` |
| Transport benchmarks | Not run |
| Publication/tag/release | Not performed |

Task-owned repository changes are limited to the compatibility review task,
this report, and the three current-facing documentation additions. Existing
benchmark, mobile/signing, and historical evidence work remains untouched.

## 10. Validation record

Disposable fixture commands and outcomes:

```sh
dart pub get
dart run build_runner build
dart format lib test
dart analyze
dart test -r compact
dart run lib/documented_example.dart
```

Results:

- dependency resolution succeeded with hosted maintained Retrofit tooling and
  local RC4 AlphaX path packages;
- clean generation succeeded and generated source compiled;
- analysis reported no issues;
- all 9 compatibility tests passed;
- the compile-tested generated example ran and returned its deterministic fake
  response;
- no transport benchmark was run.

Repository validation after documentation changes:

- `bash tooling/scripts/test_packages.sh` passed for all six AlphaX packages;
- targeted Dart and Flutter analysis passed for all six packages;
- `dart format --output=none --set-exit-if-changed` passed with 0 changed files;
- `dart doc --dry-run` passed for `alphax_dio` with 0 warnings and 0 errors;
- `dart pub publish --dry-run --ignore-warnings` succeeded for `alphax_dio`
  and reported a 15 KB compressed archive containing only expected package
  files. The plain dry-run's single warning was the intentional uncommitted
  `README.md` documentation edit, not a package-content warning;
- Markdownlint passed for the new report and Task 45 task file. A full-file
  lint of the existing README/usage documents still reports their pre-existing
  HTML branding and long-line baseline; it was not used as a reason to rewrite
  unrelated documentation;
- a local relative-link check passed for the changed docs;
- `git diff --check` passed;
- no package publication command is part of this task.

## 11. Remaining limitations

- This validates the maintained Retrofit/Dio path, not every Retrofit annotation
  or every generator release.
- The generator-specific `Future<Map<String, dynamic>>` issue described above
  remains upstream/application-side.
- Retrofit multipart file upload uses the Dio request-stream path in this
  boundary; it does not automatically invoke AlphaX native file transfer.
- OpenAPI compatibility is conditional on generated Dio injection and was not
  a full generator matrix.
- There is no Chopper, GraphQL, `package:http`, gRPC, WebSocket, or SSE adapter
  in AlphaX RC4.
- No claim is made about network throughput, latency, or performance from this
  correctness fixture.

## Conclusion

The original compatibility requirement is met for the intended standard shape:
an unchanged Retrofit generated client can use Dio with `AlphaXDioAdapter`, and
the request, response, serialization, cancellation, multipart, stream,
progress, error, redirect, and wrapper behaviors tested here reach AlphaX
correctly.

READY TO PUBLISH ALPHAX 1.0.0-RC.4
