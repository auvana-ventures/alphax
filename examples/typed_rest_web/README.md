# Direct typed REST Web fixture

This is a clean Dart Web consumer for `alphax_generator`. Its runtime AlphaX
dependency is only `alphax_web`; the generator and fake transport are
development-only.

```sh
dart pub get
dart run build_runner build
dart analyze
dart test
dart compile js lib/web_example.dart -o /tmp/alphax_typed_rest_web.js
```

The declaration imports only `package:alphax_web/alphax_web.dart` and creates
one browser-backed `AlphaXClient`. Fetch, CORS, TLS, proxy routing, and
protocol behavior remain browser-owned.
