# Basic example

This small Flutter example uses the Dart IO fallback and demonstrates the same
transport-neutral API that Android Cronet and Apple URLSession implement:

- basic GET and final protocol metadata;
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

The source is intentionally small and uses `DartIoTransport`. Replace only the
transport construction with `AndroidCronetTransport.create()` or
`AppleUrlSessionTransport.create()` in a platform application; the client API
does not change.
