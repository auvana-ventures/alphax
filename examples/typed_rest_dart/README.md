# Direct typed REST pure-Dart fixture

This is a clean pure-Dart consumer for `alphax_generator`. Its only runtime
AlphaX dependency is `alphax`; the application supplies the transport. The
generator, build_runner, fake transport, and test tooling are development-only.

```sh
dart pub get
dart run build_runner build
dart analyze
dart test
```

Pure-Dart declarations import `package:alphax/alphax.dart` and
`package:alphax/annotations.dart` explicitly. The generated service accepts
the caller-owned `AlphaXClient` and remains independent of the transport
implementation.
