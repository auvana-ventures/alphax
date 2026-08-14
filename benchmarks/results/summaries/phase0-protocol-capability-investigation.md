# AlphaX Phase 0 Protocol Capability Investigation

Status: architecture review only; no transport selected or implemented

Date: 2026-08-14

## Decision boundary

The historical Phase 0 benchmark reports remain unchanged. Their
`RECOMMEND DART IO` result is valid for the measured HTTP/1.1 workloads only.
This report answers a different question: which architecture can provide
HTTP/1.1, HTTP/2, and HTTP/3 for AlphaX 1.0 on Android and iOS with acceptable
correctness, maturity, maintenance, and distribution cost.

No benchmark matrix was rerun. HTTP/3 support means that a candidate can be
configured to negotiate HTTP/3; a server or network may still cause a correctly
verified fallback to HTTP/2 or HTTP/1.1. A future AlphaX adapter must expose the
negotiated protocol and must not label a fallback as HTTP/3.

The public `alphax` package remains pure Dart and transport-independent. No C++
engine, production transport, ADR 0004, or Phase 1 work is introduced here.

## Capability comparison

### 1. Platform-native strategy: Cronet/HttpEngine on Android and URLSession on Apple platforms

| Capability | Assessment |
|---|---|
| HTTP/1.1, HTTP/2, HTTP/3 | **Yes / yes / yes**, when the real provider and server support them. Cronet natively supports HTTP, HTTP/2, and HTTP/3 over QUIC. URLSession documents support for all three and requires ALPN for HTTP/2. [`Cronet`](https://developer.android.com/media/media3/exoplayer/network-stacks), [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) |
| Android | **Strong.** Use one shared Cronet/HttpEngine instance. Android recommends HttpEngine from API 34/S extension 7 where available; Google Play Services Cronet is small but provider/version controlled externally, while embedded Cronet is approximately 8 MB. The fallback provider does not provide a dependable H2/H3 contract. [`Android network stacks`](https://developer.android.com/media/media3/exoplayer/network-stacks) |
| iOS | **Strong.** URLSession is the system networking API and includes data, upload, and download task models. HTTP/3 can fall back when the server or path does not support it. [`HTTP/3 in your app`](https://developer.apple.com/documentation/technotes/tn3102-http3-in-your-app) |
| Desktop | **macOS: strong** through URLSession. **Windows/Linux: no equivalent in this option**; they need a separate native backend or Dart fallback. |
| Streaming | Cronet callback/read flow control and URLSession async bytes/delegate delivery. URLSession also has native download tasks. Both need an adapter to map callbacks to AlphaX streams. [`Cronet callback`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/UrlRequest.Callback), [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) |
| Cancellation | Cronet `UrlRequest.cancel()` and URLSession task cancellation are explicit. [`Cronet request`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/UrlRequest), [`URLSessionTask`](https://developer.apple.com/documentation/foundation/urlsessiontask) |
| Direct file I/O | URLSession has file-backed download tasks and file uploads. Cronet supplies upload providers and response callbacks; AlphaX would write/read files on the Android side of the adapter rather than copy the complete body through Dart. [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession), [`Cronet upload provider`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/UploadDataProvider) |
| Proxy support | URLSession has transparent system proxy/SOCKS support and explicit proxy configuration. Cronet follows the Android/engine network configuration, but its proxy surface is less uniform than libcurl’s explicit proxy API. [`URLSessionConfiguration`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration), [`Cronet status`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/UrlRequest.Status) |
| TLS control | OS/Chromium-managed trust and TLS policy, with platform configuration, authentication handling, and Cronet pinning controls. Less arbitrary than owning the complete TLS stack. [`Cronet builder`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/CronetEngine.Builder), [`URLSession`](https://developer.apple.com/documentation/foundation/urlsession) |
| Connection migration | **Android Cronet: explicit QUIC migration options**, subject to server support. **URLSession: OS-managed/opaque**; no portable application-level migration control is counted. [`Cronet connection migration`](https://developer.android.com/develop/connectivity/cronet/reference/org/chromium/net/ConnectionMigrationOptions) |
| Binary/distribution | Best mobile cost when system/provider networking is available. Play Services Cronet is documented as having a small APK impact (under 100 KB) but requires Play Services and receives provider updates. Embedded Cronet provides version control at roughly 8 MB. URLSession adds no separate HTTP runtime. [`Android network stacks`](https://developer.android.com/media/media3/exoplayer/network-stacks) |
| FFI/platform-channel complexity | Two platform adapters and lifecycle mappings, but no AlphaX-owned C/C++ engine. Use asynchronous platform APIs and keep one shared engine/session per process. Cronet’s Chromium implementation is an external dependency, not an AlphaX C++ engine. |
| Build/CI complexity | Android provider/min-SDK/device matrix plus Kotlin/Java integration; iOS/macOS Swift/Objective-C and Xcode matrix. Lower third-party native dependency work than bundling QUIC stacks. |
| Maintenance/security | Protocol and TLS fixes are largely supplied by Android provider/OS updates and Apple OS updates. AlphaX still owns adapter compatibility, minimum OS/provider policy, and protocol-observation tests. |
| Outside Dart isolate | **Yes for the transport core:** socket/event-loop work, TLS, HTTP framing, QUIC, and native file transfer remain in the platform stack. Response callbacks and any body delivered to Dart still cross the plugin boundary. |
| Underlying maturity | **Highest for the required mobile target.** Cronet is the Chromium networking stack exposed as a library; URLSession is Apple’s system URL loading API. This is the strongest H1/H2/H3 capability-to-maintenance ratio for Android/iOS. |

This is a platform strategy, not a workload-based hybrid: Android selects the
Android adapter and Apple platforms select the Apple adapter. AlphaX does not
select a different transport because one benchmark category happened to win.

### 2. libcurl-based cross-platform native transport

| Capability | Assessment |
|---|---|
| HTTP/1.1, HTTP/2, HTTP/3 | **Yes / yes / conditional yes.** H1 is core libcurl; H2 requires an HTTP/2-enabled build; H3 requires libcurl built with ngtcp2, nghttp3, and a QUIC-capable TLS library. curl documents the ngtcp2 backend as the non-experimental H3 backend, but the AlphaX bridge currently has no H3 integration. [`curl HTTP/3`](https://curl.se/docs/http3.html), [`curl dependencies`](https://curl.se/docs/libs.html) |
| Android | Buildable through an Android native library, but every required ABI must ship a compatible libcurl/TLS/HTTP2/QUIC stack. No system-lib assumption is safe. |
| iOS | Buildable as an XCFramework/static or dynamic native dependency, but Apple trust integration, bitcode/deployment policy, QUIC TLS, and per-architecture packaging become AlphaX responsibilities. |
| Desktop | **Strongest cross-platform coverage** in principle: macOS, Linux, and Windows can use the same C ABI, subject to each platform’s TLS/QUIC build and packaging. |
| Streaming | Mature callbacks, multi interface, and explicit pause/resume. Pausing a multiplexed H2/H3 stream can still require libcurl buffering for the shared connection, so bounded AlphaX buffering does not automatically mean zero native buffering. [`curl pause`](https://curl.se/libcurl/c/curl_easy_pause.html) |
| Cancellation | Easy handles can be removed/aborted from the multi engine; the AlphaX worker must preserve deterministic wakeup and cleanup. |
| Direct file I/O | Mature callback-based read/write paths and multi transfers support direct native-to-file and file-to-network paths. [`libcurl FAQ`](https://curl.se/docs/faq.html) |
| Proxy support | Broad HTTP, HTTPS, SOCKS, and proxy protocol controls. HTTP/3 proxy support exists only for an H3-enabled build and is documented as experimental. [`CURLOPT_PROXY`](https://curl.se/libcurl/c/CURLOPT_PROXY.html) |
| TLS control | Broad backend, CA, client-certificate, cipher, and proxy-TLS control. H3/QUIC constrains the build: libcurl cannot combine HTTP/3 with MultiSSL and must use one TLS library for QUIC and other TLS protocols. [`curl install`](https://curl.se/docs/install.html), [`TLS options`](https://curl.se/libcurl/c/tls-options.html) |
| Connection migration | **Not counted as a portable libcurl capability.** The QUIC backend may have implementation behavior, but the AlphaX/libcurl API does not provide a stable cross-platform migration contract comparable to Cronet’s documented option. |
| Binary/distribution | The small C bridge is not the deployable cost. A complete H3 artifact must account for libcurl, TLS, ngtcp2, nghttp3, HTTP/2, compression, and transitive libraries per ABI. The earlier tiny dynamically linked bridge measurements therefore cannot represent a bundled mobile H3 artifact. |
| FFI/platform-channel complexity | One C ABI across targets is attractive, but ownership, callbacks, multi-handle lifecycle, thread affinity, native pause buffering, and per-platform ABI packaging are AlphaX responsibilities. |
| Build/CI complexity | **High.** Reproducibly build and test the exact TLS/QUIC/H2 combination for Android, iOS, macOS, Linux, and Windows; track several native security-update streams. |
| Maintenance/security | AlphaX owns the integration plus updates for curl, TLS, ngtcp2, nghttp3, and their build policy. This is materially more responsibility than URLSession/Cronet. |
| Outside Dart isolate | **Yes:** libcurl’s sockets, TLS, HTTP framing, QUIC, callbacks, and direct file I/O can remain native. Stream chunks, metadata, middleware, parsing, and application state still reach Dart. |
| Underlying maturity | **High for H1/H2 and the general client; conditional for H3.** The H3 path is real, but its dependency/build surface is materially larger than the current AlphaX prototype. |

### 3. Rust reqwest/hyper through the existing C ABI

| Capability | Assessment |
|---|---|
| HTTP/1.1, HTTP/2, HTTP/3 | **Yes / yes / not production-ready for this decision.** The existing prototype enables only `http2`, `rustls-tls`, and `stream`; it has no H3 feature or QUIC setup. reqwest documents H3 behind the `http3` feature and `reqwest_unstable`, and describes it as unstable/experimental. The underlying `h3` crate also says it is very experimental. [`existing Cargo.toml`](../../../prototypes/rust_http/Cargo.toml), [`reqwest features`](https://docs.rs/reqwest/latest/reqwest/index.html), [`h3 status`](https://github.com/hyperium/h3) |
| Android | Cross-compilable through Rust/NDK and a C ABI, but each ABI carries the Rust runtime/dependencies and H3 stack selected by the build. |
| iOS | Cross-compilable as static libraries/frameworks through Rust targets and Xcode integration, with the same per-ABI TLS/QUIC packaging responsibility. |
| Desktop | Strong H1/H2 coverage on macOS/Linux/Windows in the existing ecosystem; H3 would require the unstable reqwest/h3/quinn path and additional validation. Hyper itself advertises H1/H2, not H3. [`hyper`](https://github.com/hyperium/hyper) |
| Streaming | Async response streams and request-body streams are available; the AlphaX prototype adds bounded FFI delivery and direct-file paths. H3 flow-control behavior is not validated in the existing bridge. |
| Cancellation | Tokio task/operation cancellation can be mapped through the C ABI, but the bridge owns the cancellation and runtime-lifecycle correctness. |
| Direct file I/O | Tokio file/request-body paths can keep file I/O native, as the prototype already demonstrates for its benchmark paths. |
| Proxy support | reqwest provides explicit HTTP/HTTPS proxy configuration and optional SOCKS support; system-proxy behavior depends on enabled features and target configuration. [`reqwest`](https://docs.rs/reqwest/latest/reqwest/index.html) |
| TLS control | rustls or native-tls choices, roots, certificates, and client identity can be configured. H3 adds QUIC/TLS configuration and dependency coupling. |
| Connection migration | **Not counted as a reqwest/AlphaX contract.** An underlying QUIC implementation may expose controls, but the existing high-level client and C ABI do not provide a validated portable migration guarantee. |
| Binary/distribution | Static Rust plus Tokio, reqwest, rustls, and an H3/QUIC stack creates a per-ABI native payload. Feature stripping and LTO may reduce it, but no H3-enabled AlphaX artifact has been produced in this investigation. |
| FFI/platform-channel complexity | One Rust C ABI can span targets, but unsafe ownership, async runtime startup/shutdown, callbacks, thread handoff, panic/error boundaries, and per-target link settings remain AlphaX-owned. |
| Build/CI complexity | **High.** Rust/NDK/Xcode target toolchains, C ABI headers, linker settings, TLS roots, and unstable H3 feature combinations must be tested together. |
| Maintenance/security | AlphaX would own reqwest, hyper, h3, QUIC, Tokio, TLS, and the FFI integration. H3 API/behavior churn is a direct production risk. |
| Outside Dart isolate | **Yes:** Tokio, sockets, TLS, HTTP framing, QUIC, and native file I/O can run outside Dart. FFI response delivery, middleware, parsing, and application state remain Dart-side. |
| Underlying maturity | **High for H1/H2; insufficient for AlphaX 1.0 H3 selection today.** The explicit unstable/experimental status is disqualifying for the current architecture gate, independent of the prior performance results. |

### 4. Dart IO (`HttpClient`) fallback/baseline

| Capability | Assessment |
|---|---|
| HTTP/1.1, HTTP/2, HTTP/3 | **H1 baseline; no documented H2/H3 capability in the current `HttpClient` API.** It cannot be the AlphaX 1.0 H3 solution. [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html) |
| Android / iOS / desktop | Available to non-web Flutter mobile and desktop targets, with no additional AlphaX native networking runtime. [`dart:io`](https://api.dart.dev/dart-io/) |
| Streaming / cancellation | Response streams, file streams, request abort, and client shutdown are available. |
| Direct file I/O | Dart-managed file read/write paths are available, but they cross Dart stream and application code rather than keeping the complete transfer in a platform transport. |
| Proxy support | Environment/PAC-style `findProxy` and proxy credentials are available; mobile system proxy/VPN behavior is less comprehensive than platform-native clients. [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html) |
| TLS control | `SecurityContext`, trusted certificates, client certificates, and certificate callbacks are available. |
| Connection migration | Not an exposed H3/QUIC capability. Persistent H1 connections can be reused. |
| Binary/distribution | Lowest incremental native size and simplest packaging. |
| FFI/platform-channel complexity | None for the transport itself; pure Dart API and runtime behavior. |
| Build/CI complexity | Lowest. Dart/Flutter SDK and platform runtime validation remain. |
| Maintenance/security | Mostly Dart SDK/platform runtime responsibility; AlphaX avoids bundling a separate curl or Rust security-update graph. |
| Outside Dart isolate | Socket and asynchronous I/O are implemented behind Dart’s async API, but request callbacks, stream handling, buffering, middleware, decoding, and application work execute as Dart events. It is not equivalent to a separately owned native protocol engine. |
| Underlying maturity | **High for H1 fallback/baseline; does not meet the required H3 capability.** |

## Heavy Flutter UI: what actually reaches Dart

`await` and `Future` do not make a synchronous network wait on the Flutter UI
isolate. Dart documents `dart:io` as predominantly asynchronous, and Flutter’s
main isolate processes Dart events and frame work through its event loop.
Therefore, Dart IO alone is not evidence that socket waiting blocks rendering.
[`dart:io`](https://dart.dev/libraries/dart-io),
[`Dart async`](https://api.dart.dev/dart-async/),
[`Flutter isolates`](https://docs.flutter.dev/perf/isolates)

With Dart IO, the following work still runs as Dart events on whichever isolate
owns the client, normally the Flutter main isolate:

- request construction, callback dispatch, stream subscription, and chunk
  buffering/copying;
- middleware, retries if later added, decompression/decoding exposed to Dart,
  UTF-8/JSON parsing, model conversion, and application state changes;
- UI notifications and widget rebuilds;
- synchronous file operations or large synchronous transformations, if the app
  performs them.

The network wait itself is asynchronous. UI jank is therefore a workload and
event-volume problem, not an automatic consequence of using Dart IO. Flutter
recommends helper isolates for genuinely large computations such as large JSON
decoding; isolate messaging has its own memory and transfer cost.

A native transport can keep the following outside Dart:

- socket readiness and the native event loop;
- TLS handshakes and record processing;
- HTTP/2 framing/multiplexing;
- QUIC and HTTP/3;
- large-file reads/writes for direct native-file operations;
- native buffering and transport-level flow control.

The following still reaches Dart when the AlphaX API returns a Dart response or
stream:

- response metadata and completion/error notifications;
- response bytes delivered through FFI or platform-channel callbacks;
- middleware, parsing/serialization, model conversion, application state, and
  UI updates.

Native transport therefore reduces Dart-side protocol and large-file work, but
it does not eliminate Dart event processing. Platform-channel handlers can be
scheduled on platform background task queues where supported, while callbacks
and messages still need an explicit lifecycle and backpressure design.
[`Flutter platform channels`](https://docs.flutter.dev/platform-integration/platform-channels)

The prior performance evidence does not measure frame timing or UI jank. No
transport recommendation in this report relies on hypothetical UI-load gains.

## Recommendation

**RECOMMEND PLATFORM-NATIVE MOBILE TRANSPORTS**

Use a transport-neutral AlphaX contract with:

1. Android: one shared Cronet/HttpEngine-backed adapter, with an explicit
   provider policy. A provider that cannot offer the H2/H3 capability must be
   reported as such; do not silently call the fallback provider an H3
   implementation. Cronet’s connection-migration controls are an additional
   mobile benefit when QUIC and the server support them.
2. iOS and macOS: one shared URLSession-backed adapter using data/bytes,
   upload, and download task forms as appropriate. Protocol negotiation must be
   observed because URLSession may correctly fall back from H3.
3. Dart IO: retain as the pure-Dart fallback and baseline. It remains valuable
   for unsupported targets and environments, but it is not the H3 path.

This is the smallest architecture for the stated Android/iOS H1/H2/H3 goal
because it uses mature protocol stacks already integrated with each mobile OS
family, keeps QUIC/TLS/framing and direct file work outside Dart, and avoids
shipping a complete QUIC/TLS dependency graph into every mobile ABI. It also
avoids selecting Rust’s currently experimental H3 path or making AlphaX own
libcurl’s multi-library H3 update and packaging graph.

The tradeoff is platform-specific adapter code and behavioral differences in
proxy, TLS, background-transfer, and migration policy. Windows/Linux do not
receive a matching platform-native H3 implementation from this recommendation;
they remain Dart IO fallback targets until a separately approved desktop H3
backend is validated. libcurl is the credible future desktop H3 candidate, but
its complete bundled stack must be built and verified before it is promoted.

This report does not create or accept ADR 0004. Maintainer approval is required
before implementing the platform adapters or formalizing the architecture.
