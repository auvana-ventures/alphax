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
