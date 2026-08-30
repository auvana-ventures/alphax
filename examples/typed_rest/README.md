# Direct typed REST native fixture

This is a clean native Flutter consumer for `alphax_generator`. Its runtime
AlphaX dependency is only `alphax_native`; `alphax` is a development dependency
used by the tests and the generator remains development-only.

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

The declaration imports only `package:alphax_native/alphax_native.dart`, calls
`createAlphaXClient()` at the application boundary, and passes that borrowed
client to the generated `UsersApi` service. The fixture also compiles
json_serializable and Freezed model hooks, exercises a local Dart IO HTTP
server, and retains explicit file/multipart/stream/request-option examples.
