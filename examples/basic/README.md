# Basic example

This small Flutter example demonstrates the released AlphaX API:

- basic GET with HTTP/3 preference, final protocol metadata, and truthful fallback;
- fail-closed HTTP/3 protocol requirement;
- idempotent cancellation;
- progressive response streaming;
- file download and upload with progress;
- capability discovery.

## What you need

You need a Flutter application and a connected desktop, Android, or Apple
device. This directory contains the example source and tests, but intentionally
does not contain an Android, iOS, or macOS host project.

## Check the example source

From this directory, run:

```sh
flutter pub get
flutter test
flutter build bundle --debug --target lib/main.dart
```

These commands check the example without contacting a server or requiring a
platform host project.

## See the example on a device

1. Open an existing Flutter application, or create a new Flutter application.
2. Copy `lib/main.dart` from this directory into that application's `lib/`
   directory.
3. Add `alphax` and `alphax_native` to the application's dependencies. The
   package installation steps are in the [root README](../../README.md).
4. Run `flutter pub get`, then run the application normally.

The example uses the Dart IO fallback so it can be built without changing the
source. In an Android or Apple application, replace only the transport
construction with `AndroidCronetTransport.create()` or
`AppleUrlSessionTransport.create()` when you want the native provider.

The default URL is `https://example.com`, so the GET button is the simplest
first check. The other buttons need a test server that provides these routes:

| Button | Route needed |
| --- | --- |
| Cancel request | `GET /delay/1000` |
| Stream response | `GET /stream/3/16` |
| Download/upload file | `GET /bytes/32` and `POST /upload` |

For a local desktop-only demonstration, the repository's deterministic fixture
server provides those routes. Start it from the repository root:

```sh
cd benchmarks/server
dart pub get
dart run server.dart --host 127.0.0.1 --port 8080
```

Then use `http://127.0.0.1:8080` as `ALPHAX_EXAMPLE_BASE_URL` when running the
example from a desktop host:

```sh
flutter run --dart-define=ALPHAX_EXAMPLE_BASE_URL=http://127.0.0.1:8080
```

This server is a local test fixture, not a production endpoint and not a
performance benchmark. On a physical device, `127.0.0.1` means the device;
use a reachable HTTPS test server instead.

The `Require HTTP/3` button is expected to fail closed in this example because
it uses Dart IO, which cannot authoritatively report H2 or H3. That result is a
correct demonstration of the API.
