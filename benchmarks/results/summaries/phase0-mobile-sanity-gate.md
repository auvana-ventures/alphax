# AlphaX Phase 0 mobile sanity gate

Status: historical experiment complete; maintainer review required. No
production transport was selected, ADR 0004 was not created, and Phase 1 was
not started.

## 1. Devices and method

| Item | Android | iPhone |
| --- | --- | --- |
| Physical device | M2003J6A1G | iPhone XR (runner metadata reports generic `iPhone`) |
| OS | Android 15, `PHK110_15.0.0.700(CN01)` | iOS 18.7.9, build `22H355` |
| Architecture | arm64-v8a | arm64/arm64e |
| Flutter / Dart | 3.47.0 / 3.13.0 | 3.47.0 / 3.13.0 |
| Native versions | libcurl 8.7.1; Rust 1.97.1, reqwest 0.12.28, hyper 1.11.0 | Same |
| Build | Flutter Profile; optimized native artifacts | Flutter Profile; optimized native artifacts |
| Protocol | Plain HTTP/1.1 | Plain HTTP/1.1 |

The server was the existing deterministic local benchmark server. No TLS,
HTTP/2, HTTP/3, network shaping, or additional scenarios were added. Each
candidate used three warmups and ten measured runs for: warm 1 KiB GET, 64
concurrent 1 KiB GETs, 32 MiB download, 8 MiB upload, and the fixed mixed
workload of 16 parallel 1 KiB GETs, one 2 MiB stream, and one 8 MiB upload.
Timing started immediately before the transport operation and ended after
response/file completion. Differences below 5% were treated as practically
equivalent unless correctness or resource behavior differed materially.

Raw data:

- [Android corrected raw result](../raw/mobile-sanity-gate/android-m2003j6a1g-android15-arm64-ad4b7b1-rust-flush.json)
- [iPhone raw result](../raw/mobile-sanity-gate/iphone-ios18.7.9-arm64-ad4b7b1.json)

The Android result was built from base commit `ad4b7b1` with the documented
uncommitted Rust file-flush correction. The iPhone device was disconnected
after its clean capture; its raw result predates that correction and is
preserved unchanged.

## 2. Correctness

All three candidates initialized on both devices. Every measured sample passed
status, byte-count, deterministic FNV-1a64 hash, and completion validation:

| Device | Dart IO | libcurl FFI | Rust FFI | Protocols observed |
| --- | ---: | ---: | ---: | --- |
| Android | 50/50 | 50/50 | 50/50 | HTTP/1.1 only |
| iPhone | 50/50 | 50/50 | 50/50 | HTTP/1.1 only |

The rejected Android pre-fix run is not used as result data. It had one Rust
32 MiB direct-download sample where the native count and later hash were
complete but the immediate Dart file length was 3,520 bytes short. Tokio's
file contract permits a dropped file with in-flight operations to defer the
OS close. The success path now explicitly flushes the file before notifying
completion. The focused Rust FFI test passed, and all ten corrected Android
Rust downloads reported exactly 33,554,432 bytes and the expected hash.

## 3. Wall-time results

Values are milliseconds, shown as `p50 / mean` over ten measured runs.

### Android

| Scenario | Dart IO | libcurl FFI | Rust FFI |
| --- | ---: | ---: | ---: |
| Warm small GET | 2.85 / 2.77 | 3.46 / 3.51 | 6.71 / 6.76 |
| 64 concurrent small GETs | 37.59 / 38.94 | 30.30 / 32.48 | 49.70 / 52.19 |
| 32 MiB download | 2002.30 / 2008.73 | 2004.10 / 2011.26 | 2002.24 / 2012.41 |
| 8 MiB upload | 884.17 / 886.31 | 901.81 / 909.60 | 962.20 / 945.05 |
| Mixed workload | 981.37 / 1003.80 | 1034.92 / 1058.45 | 996.47 / 970.89 |

### iPhone

| Scenario | Dart IO | libcurl FFI | Rust FFI |
| --- | ---: | ---: | ---: |
| Warm small GET | 3.05 / 3.91 | 4.60 / 4.75 | 5.96 / 5.98 |
| 64 concurrent small GETs | 19.89 / 20.29 | 19.10 / 19.43 | 20.11 / 20.04 |
| 32 MiB download | 1661.97 / 1662.97 | 1667.33 / 1664.78 | 1645.58 / 1652.29 |
| 8 MiB upload | 431.49 / 432.78 | 431.43 / 432.44 | 443.66 / 445.70 |
| Mixed workload | 554.08 / 553.54 | 553.55 / 558.91 | 560.10 / 565.16 |

The Android libcurl concurrency p50 is lower, but the server observed a
median of 64 distinct connections for both Dart IO and libcurl in that
scenario; it is not evidence of superior connection reuse. Warm sequential
requests reused one observable connection for all candidates on both devices.
Large downloads were practically equivalent on both devices. No candidate
showed a consistent, practically meaningful advantage across the workloads.

## 4. Memory and CPU observations

CPU was unavailable: the runner has no reliable process CPU counter for these
physical-device runs. RSS is process-level sampled peak increment over the
runner's idle baseline, in MiB; it is not a Dart/native allocation split.

| Device / scenario | Dart IO | libcurl FFI | Rust FFI |
| --- | ---: | ---: | ---: |
| Android, 64 GETs | 85.76 | 63.11 | 61.86 |
| Android, 32 MiB download | 115.82 | 57.95 | 61.65 |
| Android, 8 MiB upload | 86.18 | 53.96 | 57.28 |
| Android, mixed | 64.95 | 52.79 | 59.33 |
| iPhone, 64 GETs | 25.51 | 84.96 | 92.47 |
| iPhone, 32 MiB download | 82.54 | 85.49 | 96.30 |
| iPhone, 8 MiB upload | 82.11 | 85.48 | 96.12 |
| iPhone, mixed | 84.41 | 88.53 | 91.14 |

These values are directional only: candidates ran sequentially in one app
process, so allocator/library state can persist between candidates. They do
not justify a native memory-efficiency claim across platforms.

## 5. Artifact observations

| Platform | Artifact | Size | Accounting note |
| --- | --- | ---: | --- |
| Android arm64 | Profile APK containing both native candidates | 35,473,308 B | Not an isolated per-candidate app delta |
| Android arm64 | Bundled libcurl bridge | 482,128 B | Gate `.so` artifact |
| Android arm64 | Bundled Rust bridge after flush fix | 6,078,192 B | Gate `.so` artifact including Rust HTTP/TLS payload |
| iOS arm64 | `libalphax_curl.a` | 710,312 B | Raw static archive, not deployable incremental size |
| iOS arm64 | `libalphax_rust_http.a` | 31,477,072 B | Raw static archive, not deployable incremental size |
| iOS arm64 | Profile `Runner` executable with both bridges | 5,614,992 B | Signed benchmark app executable |
| iOS arm64 | Profile `Runner.app` | 27,016 KiB | Contains both bridge paths and Flutter runtime |

The mobile gate did not build isolated Dart-only, libcurl-only, and Rust-only
applications. Therefore these are artifact observations, not final
distribution deltas. The Rust payload is materially larger in the measured
Android shared object and raw iOS archive; the iOS archive number must not be
compared directly with the deployable executable. System-library and final
per-ABI packaging accounting remains a production-build concern.

## 6. Platform conclusions

### Android

Dart IO was fastest for warm small requests, was close to both native candidates
for the 32 MiB download, and was faster than both for the 8 MiB upload. libcurl
won the 64-request p50, but with the same high connection count as Dart IO and
without a broad workload advantage. Rust was not consistently faster and was
slower for small requests and upload.

### iPhone

Dart IO was fastest for warm small requests. libcurl was approximately
equivalent on concurrency, upload, and mixed work; Rust was slightly faster on
the download but slower on small requests, upload, and mixed work. No native
candidate produced a consistent practical advantage. The clean iPhone data
predates the Rust flush correction because the device is no longer connected.

## 7. Final mobile sanity-gate verdict

The physical Android and iPhone evidence does not invalidate the desktop/Linux
Phase 0 recommendation. Native candidates provide viable experimental direct
file paths, but the mobile measurements do not show a clear, consistent,
user-visible benefit sufficient to justify their FFI, binary, build, and
maintenance cost. A hybrid is not justified by isolated scenario wins.

This is a Phase 0 recommendation for review only. Do not create ADR 0004 or
begin Phase 1 automatically.

RECOMMEND DART IO
