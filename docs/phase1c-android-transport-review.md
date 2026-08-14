# Phase 1C Android transport review

Status: Android physical correctness validation and focused H3 capability
verification are complete. A physical Android device negotiated HTTP/3 through
the selected Google Play Services Cronet provider; Phase 1C is complete for
maintainer review.

Phase 1C adds an Android-only adapter in `alphax_native`. It does not change
the pure-Dart `alphax` API, select a production transport for Apple platforms,
or claim full AlphaX H1/H2/H3 support before URLSession validation.

## 1. Provider policy

The adapter creates one reusable Cronet engine per attached Flutter engine.
Provider selection is asynchronous and completes before `AndroidCronetTransport`
is returned:

1. Google Play Services Cronet is preferred when the `18.0.1` provider and
   installer are available.
2. An enabled non-fallback provider discovered by `CronetProvider` may be used,
   including the platform provider available on supported Android releases.
3. Embedded Cronet is not bundled by AlphaX 1.0. This avoids making the Android
   package carry another Chromium runtime and its independent update burden.
4. A Java/fallback provider may be selected only when the host application
   supplies it; the AlphaX package does not add that runtime. Its H2 and H3
   capabilities are reported unsupported.
5. AlphaX does not silently switch this adapter to Dart IO. Applications can
   explicitly select `DartIoTransport` when the Android provider is unavailable.

The selected provider name and version are returned in capability metadata.
H2/H3 capability means the selected configured provider can attempt those
protocols; it is not evidence that a particular request negotiated them.

References: [Cronet setup](https://developer.android.com/develop/connectivity/cronet/start),
[provider discovery](https://developer.android.com/develop/connectivity/cronet/reference/kotlin/org/chromium/net/CronetProvider),
and [Cronet protocol configuration](https://developer.android.com/develop/connectivity/cronet/reference/kotlin/org/chromium/net/CronetEngine.Builder).

## 2. Supported Android versions and providers

The plugin declares Android `minSdk 24` and uses the Play Services Cronet
artifact. The platform-provider path is only usable where Android exposes an
enabled compatible provider; otherwise capability discovery reports the
fallback state. The final supported-version matrix remains subject to the
physical-device and release-app checks below.

| Provider | H1 | H2 | H3 | Behavior |
| --- | --- | --- | --- | --- |
| Play Services Cronet | yes | yes | attempt | report actual protocol |
| Platform provider | yes | varies | varies | report actual protocol |
| Java/fallback | yes | no | no | no silent downgrade claim |
| No enabled provider | no | no | no | initialization fails |

Physical validation used one Android device:

| Field | Value |
| --- | --- |
| Device | `M2003J6A1G` |
| Android | 15, API 35 (`PHK110_15.0.0.700(CN01)`) |
| ABI | `arm64-v8a` |
| Dart | 3.13.0 |
| Flutter | 3.47.0 |
| Build | profile APK, no debug transport comparison |
| Runtime provider | Google Play Services Cronet, `151.0.7922.29`, aarch64 |
| Harness HEAD | `2eaabe295c549bc43eaf2c678639feef8e0c750a` |
| Worktree | Phase 1C changes were uncommitted during the run |

The deterministic H1 fixture ran on the development host and was reached by
the device through `adb reverse tcp:18080 tcp:18080`. The validation APK is a
disposable harness; its manifest permits cleartext only so this local H1
fixture can run. The Android transport itself retains platform TLS defaults.

## 3. Protocol and H3 evidence

The native callback reads `UrlResponseInfo.getNegotiatedProtocol()` and maps
the value to the AlphaX protocol enum. The requested preference is carried
separately. A request preferring H3 that negotiates H2 therefore reports:

```text
requested: http3
negotiated: http2
fallback: present
```

The fixed Phase 1C device harness is
`benchmarks/mobile_gate/lib/phase1c_main.dart`. It runs H1 correctness checks,
then explicit H2 and H3 protocol checks. H2 uses
`https://nghttp2.org/httpbin/get` by default and H3 uses
`https://cloudflare-quic.com/` by default; both are external protocol
validation endpoints, not performance data. A run is not marked H3-successful
unless the response reports `http3`.

Current evidence:

- The profile APK compiles the plugin successfully in the host Flutter Android
  project; the final APK was approximately 73.7 MB. This is an application
  artifact, not an AlphaX incremental-size claim.
- All seven required methods returned status 200 and reported `http11` on the
  cleartext H1 fixture.
- The bounded stream delivered 524,288 bytes (8 × 65,536) across 10–11
  chunks, including one consumer pause/resume.
- Redirect handling completed one hop. The server observed pooled requests on
  the shared engine; the captured pair had connection request counts `9` and
  `1`, so this is evidence of reuse during the run, not a guarantee of one
  physical connection for every sequential request.
- Native direct download and upload each validated a 1 MiB deterministic body
  with FNV-1a64 hash `4c568eccaeaf6c44`.
- Cancellation during a delayed request completed as
  `AlphaXCancellationException`; the final logcat had no transport crash,
  upload-provider failure, or orphaned stream error.
- The explicit H2 probe negotiated `http2` with status 200. The initial H3
  probe received an `Alt-Svc: h3=":443"` advertisement but negotiated `http2`
  after requesting H3, and the fallback was reported accurately.
- The final focused Cloudflare probe, with a temporary diagnostic QUIC hint,
  negotiated `http3`; the result is recorded in section 16.
- A second targeted probe against `https://http3.is/` negotiated `http2` and
  reported the H3 fallback accurately. This does not invalidate the successful
  Cloudflare H3 negotiation.

## 4. Conformance result

The adapter is written against the same `AlphaXTransport` contract as
`DartIoTransport`. The device harness covers the transport-neutral behaviors
that require a running Android plugin: all required methods, headers, response
streaming, pause/resume, redirects, cancellation, file transfers, progress,
reuse, and actual protocol reporting.

The package-level shared `package:test` conformance definitions remain
transport-neutral and are not changed to contain Android assumptions. Running
that test runner inside a physical Flutter application is not a valid device
test mechanism; the device harness is the Android execution of those same
contract behaviors. The final emitted JSON result was retrieved from the
profile application sandbox with `run-as` and is summarized above. The final
focused probe also verifies the actual H3 path; the adapter continues to report
fallback whenever a request negotiates H2 instead.

## 5. Streaming and bounded backpressure

Response delivery uses a four-credit native read window. Each credit permits
one 64 KiB Cronet read, so the native adapter has at most 256 KiB of outstanding
read credit before Dart consumption grants more. Dart stream pause stops new
credit grants; resume replenishes the window. Native direct-file download uses
the same 64 KiB read buffer but writes directly to the target file rather than
queueing chunks in Dart.

The request-body bridge also has one outstanding Dart demand at a time. File
uploads use a native `UploadDataProvider` and do not require the complete file
to cross the Dart channel. Progress is emitted per completed native read/upload
chunk and remains monotonic.

The harness pauses after the first stream chunk, resumes after a bounded delay,
and verifies complete delivery. It also records cancellation while a delayed
request is active. The final run passed these checks with a four-credit,
64-KiB window and no uncontrolled callback accumulation in the device log.

## 6. File-transfer behavior

`AlphaXLocalFileSource` and `AlphaXLocalFileTarget` are transport-neutral
file-path conveniences; they expose no descriptor or Cronet type.

- Download: Android native response reads write to `FileOutputStream`.
- Upload: Android native `FileUploadProvider` reads the source incrementally.
- Other `AlphaXFileSource` implementations use the Dart request-body bridge.
- Other `AlphaXFileTarget` implementations use the inherited Dart streaming
  path.

The harness validates a deterministic 1 MiB payload, exact byte count, and
FNV-1a content hash for both native-capable paths. Both paths passed on the
physical device; the native download reported `http11` after completion.

## 7. Cancellation

Cancellation is mapped to Cronet `UrlRequest.cancel()` and then normalized to
`AlphaXCancellationException`. It is handled before start, during response wait,
while the response is paused/streaming, during file operations, and during
transport close. Local Dart completion is deterministic even if the native
completion callback races with the cancellation request. Repeated transport
close calls are harmless.

## 8. Timeout mapping

The adapter emulates the Phase 1A timeout categories with a scheduled native
timer:

| AlphaX timeout | Android mapping |
| --- | --- |
| `connect` | Stops at headers; emulates the connect phase. |
| `request` | Stops at headers; includes body dispatch. |
| `read` | Covers an outstanding read; pause has no active read. |
| `overall` | Covers request start through completion. |

Timer expiry cancels the native request and produces
`AlphaXTimeoutException`. The distinction between connect and request timing is
therefore an AlphaX lifecycle emulation, not a Cronet-provided phase metric.

## 9. Error mapping

Native failures are reduced to transport-neutral categories: DNS, connection,
TLS, timeout, cancellation, protocol, redirect, request body, response body,
unsupported capability, and transport/internal. Native exception class names
are retained only in event diagnostics. Secure platform certificate
verification remains enabled; no trust-all or certificate-bypass path is used.

## 10. Capability output

The Android adapter reports H1/H2/H3, streaming upload/download, native file
upload/download, upload/download progress, and negotiated-protocol reporting
according to the selected provider state. It reports proxy configuration,
certificate pinning, mTLS, and background transfer unsupported. Connection
migration is reported unknown because no provider-specific experimental
migration control is configured or guaranteed by AlphaX 1.0.

The final capability output reported H1, H2, H3, bounded streaming, native
file upload/download, progress, and negotiated-protocol reporting as
supported by the selected provider. This means the provider can be configured
to attempt those features. It does not override the per-request negotiated
protocol: the H3 request reported H2 fallback in the same result.

## 11. Lifecycle and reuse

`CronetTransportEngine` owns one engine, one bounded request executor, one timer
executor, and all active operations. It does not create an engine or worker per
request. Closing the Flutter plugin cancels active operations, shuts down the
engine, clears channels, and releases executors. The H1 harness records server
connection identifiers and per-connection request counts after sequential
responses are drained.

## 12. Binary impact

The current profile mobile-gate APK containing the plugin builds successfully
at approximately 73.2 MB on the development machine. This is an application
artifact, not an AlphaX incremental-size claim. The Phase 1C provider policy
does not bundle embedded Chromium; the distributable impact of the selected
Play Services dependency must be measured from the final release app and
reported separately from the Dart bridge. No platform-wide size conclusion is
made from this development APK.

## 13. Phase 1A contract issues discovered

No transport-neutral Phase 1A breaking change was required. The Android
adapter uses the existing protocol preference/actual protocol split, capability
model, body replay rules, file abstractions, progress callbacks, cancellation
token, timeout categories, and middleware-compatible `AlphaXTransport` surface.

The implementation corrections were transport-local: Cronet fixed-length
upload providers must not mark a read as a chunked final chunk; late credit
notifications after native completion are benign; and a completion error is
held until a response listener exists so cancellation during setup cannot
create an orphaned stream error. These changes do not alter the public
contract.

## 14. Boundary before URLSession implementation

No Phase 1C blocker remains. The focused device evidence below establishes an
actual H3 negotiation through the selected Android provider and preserves the
H3-to-H2 fallback behavior on a second endpoint. No iPhone or Apple transport
work was started.

Phase 1E must repeat protocol validation with the release application/provider
combination and retain one QUIC-permissive device/network result before AlphaX
1.0 makes a broad Android HTTP/3 support claim. This is release validation,
not an open Phase 1C adapter defect.

## 15. Initial focused HTTP/3 capability investigation (pre-hint)

This subsection preserves the first single-protocol probe before the
diagnostic QUIC hint. No benchmark matrix or Dart IO/libcurl/Rust comparison
was run.

### Provider and device

The Android package depends on `com.google.android.gms:play-services-cronet`
`18.0.1` and calls `CronetProviderInstaller.installProvider` before provider
discovery. The physical device reported:

| Field | Value |
| --- | --- |
| Device | `M2003J6A1G` |
| Android/API | Android 15 / API 35 |
| Android extension level | 13 (`R`, `S`, `T`, `U`, `V`) |
| Build incremental | `T.1cfb11b_39e2-2` |
| ABI | `arm64-v8a` |
| Google Play Services | `26.29.32` |
| Selected provider | `Google-Play-Services-Cronet-Provider` |
| Cronet version | `151.0.7922.29` |
| Provider class | non-fallback native provider |

The focused probe reported the provider as
`Android Cronet (Google-Play-Services-Cronet-Provider)` and reported HTTP/2,
HTTP/3, and negotiated-protocol reporting as provider capabilities. The
provider is therefore not the Java fallback provider.

### Cronet configuration

The engine builder explicitly calls `enableHttp2(true)` and
`enableQuic(true)`. No H2-only setting, experimental option, proxy, trust-all
override, or connection-migration option is configured. The request protocol
preference is retained for AlphaX reporting; Cronet still determines the
actual protocol through normal origin negotiation. No cache policy is
explicitly configured by this prototype.

### Initial endpoint and network observations

The single endpoint used for this investigation was
`https://cloudflare-quic.com/`. From the development host it resolved to
Cloudflare IPv4/IPv6 addresses, returned HTTP 200 over TLS, and advertised:

```text
Alt-Svc: h3=":443"; ma=86400
```

The host's installed curl negotiated HTTP/2 and does not include HTTP/3
support, so it could not independently complete a QUIC handshake. A UDP
socket check is not treated as proof of QUIC reachability. The endpoint is
retained as a protocol-validation endpoint only; it is not benchmark data.

### Initial focused device result

The probe performed one normal prewarm request, waited for the Alt-Svc cache
to settle, and then performed one request preferring HTTP/3. Platform TLS
verification remained enabled.

| Observation | Result |
| --- | --- |
| Prewarm status/body | `200` / `125959` bytes |
| Prewarm negotiated protocol | `http2` |
| H3-preferred status/body | `200` / `125959` bytes |
| Requested protocol | `http3` |
| Actual negotiated protocol | `http2` |
| Fallback | `http3` → `http2`, reason `unknown` |
| H3 result | **UNVERIFIED** |

The adapter received and preserved Cronet's actual negotiated result; it did
not relabel the H2 response as H3. The focused regression tests cover the
corresponding mapping: H3 remains H3 when the native result is H3, H3→H2
produces explicit fallback metadata, and a fallback provider cannot advertise
H3.

### Initial finding

The selected provider is H3-capable and QUIC is enabled. The endpoint
advertises H3, but this device/network path still negotiates H2. The evidence
most strongly points to UDP/QUIC reachability or path policy on the current
network; because an independent QUIC client is unavailable on the host, the
exact network-versus-endpoint cause cannot be proven here. The classification
is therefore **probable network/UDP limitation; residual cause unknown**.

H3 was **UNVERIFIED in this pre-hint run**. H3 fallback behavior remained
correct: when H3 was requested and H2 was negotiated, AlphaX reported H2 plus
fallback metadata.

## 16. Final focused HTTP/3 verification

The final attempt was limited to the requested capability probe. It added
`addQuicHint("cloudflare-quic.com", 443, 443)` temporarily to the active
Cronet builder, ran one probe against Cloudflare, ran one probe against a
second known H3 endpoint, and then removed the hint from the adapter source.
The hint is diagnostic evidence only and is not part of the AlphaX public API
or general provider policy.

### Provider, device, and network

| Field | Value |
| --- | --- |
| Device | `M2003J6A1G` |
| Android/API | Android 15 / API 35 |
| ABI | `arm64-v8a` |
| Network type | validated Wi-Fi |
| Provider | `Google-Play-Services-Cronet-Provider` |
| Cronet version | `151.0.7922.29` |
| Google Play Services | `26.29.32` |
| QUIC | enabled |
| HTTP/2 | enabled |
| TLS | platform certificate verification; no trust-all override |
| Build | profile APK; focused protocol probe |

An alternate network path was not attempted after the first successful H3
negotiation, because the user-defined stop condition had been met. No network
settings were changed.

### Probe evidence

| Endpoint | Alt-Svc | Requested | Actual | AlphaX | Result |
| --- | --- | --- | --- | --- | --- |
| [`cloudflare-quic.com`](https://cloudflare-quic.com/) | `h3=":443"; ma=86400` | `http3` | `http3` | `http3` | HTTP 200, **verified** |
| [`http3.is`](https://http3.is/) | `h3=":443";ma=86400,h3-29=":443";ma=86400,h3-27=":443";ma=86400` | `http3` | `http2` | `http2` | HTTP 200, fallback `http3` → `http2` |

The successful Cloudflare probe had a 200 response and 125,959 response body
bytes. Its prewarm request also negotiated `http3`. The `http3.is` probe had a
200 response and 1,180 response body bytes; its fallback metadata was retained.
The adapter therefore distinguishes provider capability, requested protocol,
and actual negotiated protocol in both directions.

The captured machine-readable evidence is committed as
`benchmarks/mobile_gate/fixtures/phase1c_h3_cloudflare_verified.json`. The
focused runner remains available at
`benchmarks/mobile_gate/lib/phase1c_h3_main.dart`.

### Final classification

**HTTP/3 VERIFIED on the tested Android 15 / Google Play Services Cronet
configuration and Wi-Fi path.**

Phase 1C is complete for maintainer review. This does not claim that every
Android provider, network, or release configuration will negotiate H3; an H3
request must continue to report H2/H1 accurately when fallback occurs. Phase
1E carries the release-validation requirement to demonstrate the same actual
negotiation on the supported release configuration before AlphaX 1.0 claims
Android HTTP/3 support broadly.
