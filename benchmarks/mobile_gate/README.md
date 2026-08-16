# AlphaX mobile sanity gate

This is a temporary, benchmark-only Flutter runner for the maintainer-approved
mobile sanity gate. It is not `alphax_flutter`, does not change the public
AlphaX API, and must not be used as a production transport recommendation.

The runner compares the existing Dart IO, libcurl C-ABI/FFI, and Rust
reqwest/hyper C-ABI/FFI prototypes on one physical Android device and one
physical iPhone. It runs only:

- warm `GET /bytes/1024`;
- 64 concurrent `GET /bytes/1024` requests;
- `GET /bytes/33554432` download;
- `POST /upload` with an 8 MiB deterministic body;
- the fixed mixed workload: 16 parallel 1 KiB GETs, one 2 MiB bounded stream
  (`/stream/32/65536`), and one 8 MiB upload.

Each candidate/scenario uses three warmups and ten measured runs. The runner
validates status, exact response/request byte counts, deterministic FNV-1a64
content hashes, and completion of all 64 concurrent requests before recording
results. The measured wall-time boundary is the transport operation itself;
file hash validation occurs immediately after the timed operation.

## Build and run

`pubspec.yaml` uses path dependencies on the existing benchmark client and
transport prototypes. Native libraries are generated locally and are ignored
by the repository; do not commit APKs, static archives, or native shared
objects.

The mobile bridge artifacts used by this gate are release/profile native builds:

- libcurl 8.7.1, static, HTTP/1.1 only, TLS disabled for this plain-local gate;
- Rust reqwest 0.12.28 with rustls and HTTP/2 capability in the existing
  prototype; the server URL used by this gate is plain HTTP, so negotiation is
  reported as HTTP/1.1;
- both bridges are the existing minimal C ABI; no C++ engine is involved.

On iOS, the static bridge archives are force-loaded and their C ABI entry
points are explicitly exported by the benchmark executable so
`DynamicLibrary.process()` can resolve them. The signing team is supplied by
the local device-build environment and must not be committed to the project.

Run the deterministic server from the repository root:

```sh
dart run benchmarks/server/server.dart --host 0.0.0.0 --port 18080
```

Build the Flutter runner after placing the target native artifacts under
`android/app/src/main/jniLibs/arm64-v8a/` and `ios/Native/`. The exact native
toolchain versions and artifact sizes must be recorded in the resulting gate
report.

Use a physical device only. Supply the server address reachable from both
devices and a source commit identifier through `--dart-define` values, for
example:

```sh
flutter run --profile --no-pub -d <physical-device> \
  --dart-define=ALPHAX_MOBILE_GATE_BASE_URL=http://<host-ip>:18080 \
  --dart-define=ALPHAX_DEVICE_MODEL=<model> \
  --dart-define=ALPHAX_DEVICE_ARCH=<arch> \
  --dart-define=ALPHAX_FLUTTER_VERSION=<version> \
  --dart-define=ALPHAX_GIT_COMMIT=<commit>
```

The app prints one machine-readable JSON result between
`ALPHAX_MOBILE_GATE_RESULT_BEGIN` and
`ALPHAX_MOBILE_GATE_RESULT_END`. A protocol difference or unavailable resource
metric is recorded explicitly; it is never silently treated as equivalent.

This gate intentionally does not add network shaping, HTTP/2/HTTP/3 work,
extra clients, larger transfer matrices, or production features.

## Self-contained H3 release check

`lib/phase1f_h3_self_check_main.dart` is the focused release-path runner for
the final Android H3 evidence and the corresponding iPhone check. It runs
only two logical checks:

1. an HTTP/3 preference check. For each approved endpoint it performs a safe
   GET prewarm, waits one second for provider Alt-Svc discovery, and retries
   the same endpoint on the same transport with an HTTP/3 preference. It
   accepts success only when completion metadata reports actual `http3`;
2. an HTTP/3 requirement request, accepting success only when the request
   succeeds with actual `http3`.

It uses `cloudflare-quic.com` and, only if needed, `www.google.com` as known
public endpoints. It does not use the local fixture server, a diagnostic
QUIC hint, or any benchmark matrix. The report retains both discovery
attempts, the observed Alt-Svc values, and the final negotiated protocol. The
Android target creates the selected Google Play Services Cronet provider; the
Apple target creates URLSession.

HTTP/3 is opportunistic and remains dependent on the selected provider, server,
proxy, and network path. A `blocked_environment` result means either that the
runner could not acquire a usable path or that the completed discovery
sequence observed truthful H2/H1 fallback; the report distinguishes those
cases. It is not permission to relabel the response as H3 or to weaken
production TLS and protocol behavior. A QUIC-permissive run is useful
additional evidence but is not a universal network guarantee or a reason to
add a production QUIC hint.

The runner writes the latest authoritative report to the app documents
directory as `alphax-phase1f-h3-release.json` and keeps the app open with the
report path visible. On Android 10+, it also exports a timestamped copy to
`Downloads/AlphaX` through scoped `MediaStore` storage, so a tester can attach
the JSON without accessing the app sandbox. This makes device execution
independent of USB/logcat timing.

The Android runner defaults to `ALPHAX_NETWORK_MODE=cellular`. Before creating
Cronet, the disposable runner requests a cellular internet network, binds the
runner process to it, and requires Android to report that network as active,
validated, internet-capable, and unrestricted. If Android cannot acquire or
validate cellular data, the runner records a blocked environment result and
does not perform a misleading H3 probe. Use `system` only when intentionally
testing the device's current default network.

Build Android for a cellular-data run:

```sh
flutter build apk --profile \
  --target lib/phase1f_h3_self_check_main.dart \
  --dart-define=ALPHAX_NETWORK_MODE=cellular \
  --dart-define=ALPHAX_NETWORK_TYPE=Mobile-data \
  --dart-define=ALPHAX_DEVICE_MODEL=<model> \
  --dart-define=ALPHAX_DEVICE_ARCH=arm64-v8a \
  --dart-define=ALPHAX_FLUTTER_VERSION=<version> \
  --dart-define=ALPHAX_GIT_COMMIT=<commit>
```

The report records both the configured label and the runtime network selected
by Android. The configured label is not evidence of the active route.

After the device is reachable over network ADB, retrieve the persisted Android
report without relying on logcat:

```sh
adb -s <network-device> shell run-as com.auvana.ventures.alphax_mobile_gate \
  cat app_flutter/alphax-phase1f-h3-release.json
```

The public copy is visible in the device file manager under
`Downloads/AlphaX`. The private app-document copy remains the canonical copy
used by automated retrieval.

On iPhone, build/run the same target with the signed device configuration.
The report is stored in the app's `Documents` container and can be retrieved
through the normal Xcode device-container workflow after the phone is
reachable over Wi-Fi. The app also prints the report path and JSON markers to
the device run output.

## Phase 1D Apple contract runner

The shared `alphax_test` conformance suite for the Apple URLSession adapter is
in `integration_test/phase1d_apple_conformance_test.dart`. For a physical iOS
device, use the `flutter drive` path so the test driver owns the VM-service
lifecycle:

```sh
flutter drive --no-pub --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/phase1d_apple_conformance_test.dart \
  -d <physical-iphone> \
  --dart-define=ALPHAX_PHASE1D_CONFORMANCE_URL=http://<host-ip>:18080
```

Run the deterministic server first. The command must report `All tests
passed.` and exit successfully. This runner executes the shared transport
contract only; it is separate from the Phase 0 mobile performance gate and
does not add a production Flutter package.

## Phase 1C Android correctness harness

`lib/phase1c_main.dart` is separate from the historical Phase 0 gate above.
It does not collect benchmark samples or compare transports. It runs the
Android Cronet adapter against the deterministic H1 fixture and performs fixed
H2/H3 negotiation probes, plus methods, headers, bounded pause/resume,
redirects, cancellation, client reuse, progress, and native file-transfer
hash checks.

Build and install a profile APK on a physical Android device:

```sh
flutter build apk --profile --target lib/phase1c_main.dart \
  --dart-define=ALPHAX_PHASE1C_H1_BASE_URL=http://127.0.0.1:18080/ \
  --dart-define=ALPHAX_DEVICE_MODEL=<model> \
  --dart-define=ALPHAX_DEVICE_ARCH=arm64-v8a \
  --dart-define=ALPHAX_FLUTTER_VERSION=<version> \
  --dart-define=ALPHAX_GIT_COMMIT=<commit>
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

For the local fixture, expose the host server through ADB before launching:

```sh
adb reverse tcp:18080 tcp:18080
```

The disposable validation app permits cleartext only for this local H1 path;
the Android transport keeps platform TLS verification enabled. After the app
finishes, retrieve the complete result without relying on logcat line limits:

```sh
adb shell run-as com.auvana.ventures.alphax_mobile_gate \
  cat code_cache/alphax-phase1c-result.json
```

The H2 and H3 probes default to external TLS endpoints and can be overridden
with `ALPHAX_PHASE1C_H2_URL` and `ALPHAX_PHASE1C_H3_URL`. The app prints JSON
between `ALPHAX_PHASE1C_RESULT_BEGIN` and
`ALPHAX_PHASE1C_RESULT_END`. A request preferring H3 is counted as H3 only when
Cronet reports `http3` as the negotiated protocol; H1/H2 fallback is retained
in the output.
