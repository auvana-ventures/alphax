# alphax_generator

`alphax_generator` is AlphaX's dev-time source generator for small, typed REST
API declarations. It emits ordinary Dart implementations that call the supplied
`AlphaXClient` directly:

```text
AlphaX annotations → alphax_generator → AlphaXRequest → AlphaXClient
```

It is for applications that want a direct AlphaX typed API without adding Dio,
Retrofit, or `package:http`. Existing Retrofit applications remain supported
through [`alphax_dio`](https://pub.dev/packages/alphax_dio).

For deployment, use [`alphax_native`](https://pub.dev/packages/alphax_native),
[`alphax_web`](https://pub.dev/packages/alphax_web), or
[`alphax`](https://pub.dev/packages/alphax) with a custom transport. The
generator is development tooling; generated applications do not use its
analyzer or source-generation dependencies at runtime.

## Setup

For a native Flutter application, keep the runtime dependency at the deployment
boundary and add the generator only to development tooling:

```yaml
dependencies:
  alphax_native: ^1.0.0

dev_dependencies:
  alphax_generator: ^1.0.0
  build_runner: ^2.16.0
```

The annotations are lightweight const metadata in `alphax`; they do not bring
analyzer, source_gen, or build_runner into the runtime dependency graph.

Pure-Dart consumers import `package:alphax/alphax.dart` and
`package:alphax/annotations.dart`, then supply their own `AlphaXTransport`.
The compile-tested pure-Dart hand-off is in
[`examples/typed_rest_dart`](../../examples/typed_rest_dart).

## Declare an API

The deployment package re-exports the AlphaX annotation and client surface, so
the API declaration needs one AlphaX deployment import:

```dart
import 'package:alphax_native/alphax_native.dart';

part 'users_api.g.dart';

@AlphaXApi(baseUrl: 'https://api.example.com')
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXGet('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<User> getUser(@AlphaXPath('id') String id);

  @AlphaXPost('/users')
  @AlphaXDecode('User.fromJson')
  Future<User> createUser(@AlphaXBodyParam() CreateUser input);
}
```

Run the normal builder:

```sh
dart run build_runner build
```

The complete compile-tested native declaration is in
[`examples/typed_rest/lib/users_api.dart`](../../examples/typed_rest/lib/users_api.dart).
The Web equivalent is in
[`examples/typed_rest_web/lib/users_api.dart`](../../examples/typed_rest_web/lib/users_api.dart).

## Supported first slice

The generator supports GET, POST, PUT, PATCH, DELETE, and HEAD; absolute or
relative endpoints; URI path-segment encoding; scalar and repeated query
parameters; static and dynamic headers; JSON, text, byte, stream, file, and
existing multipart bodies; caller-owned cancellation and
`AlphaXRequestOptions`; typed JSON decoders; raw AlphaX responses; typed
`AlphaXApiResponse<T>` metadata; streamed byte responses; and AlphaX file
transfers.

URI resolution uses Dart's `Uri.resolveUri`: a relative endpoint resolves
against the API base URL, a leading slash replaces the base path, and an
absolute `http`/`https` endpoint does not inherit the base URL's query. For
relative endpoints, base and endpoint query values are retained and generated
query values are appended for repeated keys. Static headers use
API-level-then-method-level precedence case-insensitively; a dynamic header
binding is emitted last and replaces either static value.

`AlphaXBodyParam` is intentionally named as a parameter binding. It avoids
colliding with the existing `AlphaXBody` and `AlphaXRequestBody` runtime API.
For custom models, use a decoder expression that accepts one decoded JSON value,
such as `User.fromJson` or a caller-owned `decodeUser` function. Serialization
and model generation remain caller-owned; json_serializable and Freezed work
without becoming AlphaX runtime dependencies.

Static API/method headers are emitted into generated source. Do not place
credentials or other secrets in those annotations; use AlphaX middleware or a
dynamic header parameter so secret values remain application-owned.

Non-2xx HTTP responses remain AlphaX responses. They are not converted into
transport exceptions by generated code. Transport, TLS, cancellation, and
request-body failures retain AlphaX's normal error semantics.

## Ownership and escape hatches

Generated services borrow the `AlphaXClient` passed to their factory and never
close it. The application owns one client and closes it after all generated
services stop using it. Middleware, authentication, retry, cookies, cache,
resilience, TLS, proxy, protocol, timeout, progress, and cancellation policy
remain AlphaX concerns below the generated service.

For direct control, use the unchanged explicit path:

```dart
final client = AlphaXClient(transport: MyTransport());
final api = UsersApi(client);
```

This package is the direct annotation generator foundation. The OpenAPI
template is a bounded proof that emits AlphaX declarations, and the Protobuf
recipe is caller-layer serialization guidance; neither adds a runtime schema or
serialization package. Framework-specific generator integrations remain outside
this package.
