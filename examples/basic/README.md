# Basic example

This small Flutter example uses the Dart IO fallback and demonstrates the same
transport-neutral API that Android Cronet and Apple URLSession implement:

- basic GET with HTTP/3 preference, final protocol metadata, and truthful fallback;
- fail-closed HTTP/3 protocol requirement;
- idempotent cancellation;
- progressive response streaming;
- file download and upload with progress;
- capability discovery.

Run it from this directory with a Flutter target. The default endpoint is
`https://example.com`; set `ALPHAX_EXAMPLE_BASE_URL` to a deterministic fixture
when exercising the stream, file, or cancellation buttons:

```sh
flutter pub get
flutter run --dart-define=ALPHAX_EXAMPLE_BASE_URL=https://example.com
```

This directory does not contain a platform host project. Use
`flutter build bundle --debug --target lib/main.dart` for a host-independent
compile check, or run it from an application that supplies the target platform.

The source is intentionally small and uses `DartIoTransport`. Replace only the
transport construction with `AndroidCronetTransport.create()` or
`AppleUrlSessionTransport.create()` in a platform application; the client API
does not change. The Dart IO example reports an H3 requirement as unsupported
and fails closed because Dart IO cannot authoritatively report H2/H3.
