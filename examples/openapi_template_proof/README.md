# OpenAPI template proof

This is the bounded Task F proof for the official OpenAPI Generator template
customization seam. It is not a full OpenAPI compiler or an AlphaX OpenAPI
package.

The proof uses OpenAPI Generator 7.24.0's supported `--template-dir` overlay:

```text
OpenAPI 3.0 document
  → official OpenAPI Generator Dart template overlay
  → AlphaX declaration (`UsersApi`)
  → alphax_generator/build_runner
  → AlphaXClient → AlphaXTransport
```

The custom template emits only the declaration. Caller-owned `User` and
`CreateUser` serialization stays in `lib/fixture_models.dart`. The generated
source contains no Dio, Retrofit, Chopper, or `package:http` runtime calls.

## Reproduce

Download the official CLI artifact from Maven Central and set its path:

```sh
export OPENAPI_GENERATOR_CLI_JAR=/path/to/openapi-generator-cli-7.24.0.jar
bash tooling/openapi/alphax_template_proof/generate.sh
```

The script generates into a disposable directory, formats the result, and
compares it with `lib/users_api.dart`. It does not write generator output,
`.dart_tool`, or build output to the repository.

Then compile the AlphaX implementation and run the local deterministic fixture:

```sh
dart pub get
dart run build_runner build
flutter analyze --fatal-infos
flutter test
```

The checked-in declaration uses the loopback fixture URL. Production callers
provide their OpenAPI server URL to the template as `alphaXBaseUrl`.

## Deliberate boundary

The proof covers GET, POST, path/query/header parameters, JSON request and
response models, and a declared HTTP 404 response. Multipart/file generation is
deferred because adding it would require a separate template policy rather than
the existing Task E annotation seam. Existing AlphaX multipart/file APIs remain
available to direct callers and Task E-generated declarations.
