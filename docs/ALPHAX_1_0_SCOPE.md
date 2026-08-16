# AlphaX 1.0 Scope

Review state: Accepted for 1.0.0-rc.1 review

This document is the source of truth for AlphaX 1.0 scope. It supersedes
conflicting capability status language in older PRDs, README tables, and
`docs/roadmap.md`; those documents remain historical context unless updated to
point here.

The associated architecture decision is [ADR-0004: Platform-Native Mobile
Transports](decisions/0004-platform-native-mobile-transports.md), which remains
`Accepted`; implementation remains bounded by the Phase 1 roadmap below.

AlphaX 1.0 keeps `alphax` pure Dart and transport-independent. The required
mobile and Apple transport strategy is:

- Android: platform-native Cronet/HttpEngine-backed transport.
- iOS/macOS: platform-native URLSession-backed transport.
- Windows/Linux: Dart IO initially; no H2/H3 guarantee is made there by this
  scope.
- Dart IO: fallback/baseline on every target where it is available.
- No AlphaX-owned C++ engine and no production Rust transport for 1.0.

Protocol support means that the selected platform transport can negotiate the
protocol. A server, proxy, or network may cause a correct fallback. Every
response must expose the actual negotiated protocol and, when applicable, the
fallback reason. AlphaX must never label an H2/H1 fallback as H3. For the
`1.0.0-rc.1` review, representative provider/device evidence establishes the
implementation boundary; it does not promise H3 on every network.

## Classification rules

Every capability in this document has exactly one classification:

| Classification | Meaning |
|---|---|
| `REQUIRED FOR 1.0` | Must be implemented, tested, documented, and complete before the 1.0 release gate can pass. |
| `OPTIONAL FOR 1.0` | May ship in 1.0 only if it does not delay or weaken required behavior; absence must be explicit in capability reporting. |
| `POST-1.0` | Excluded from the 1.0 release gate and may be considered after 1.0 under a separate scope decision. |
| `EXPLICIT NON-GOAL` | Not an AlphaX 1.0 responsibility; do not add it to the 1.0 architecture or release criteria. |

## Capability classification matrix

### Protocols

| Capability | Classification | 1.0 boundary |
|---|---|---|
| HTTP/1.1 | `REQUIRED FOR 1.0` | Supported on Android, iOS, macOS, Windows, and Linux through the selected transport or Dart IO fallback. |
| HTTP/2 | `REQUIRED FOR 1.0` | Supported and verified on Android, iOS, and macOS; Windows/Linux may report unavailable when using Dart IO. |
| HTTP/3 | `REQUIRED FOR 1.0` | Supported and verified on Android, iOS, and macOS through Cronet/HttpEngine or URLSession when the selected provider and path negotiate it; H3 remains opportunistic and no Windows/Linux H3 guarantee is made. |
| Negotiated protocol reporting | `REQUIRED FOR 1.0` | Every completed response exposes the actual protocol as a transport-neutral enum when the provider reports it. |
| Fallback reporting | `REQUIRED FOR 1.0` | H3→H2/H1 and H2→H1 fallback is explicit, with a normalized reason when available. |

### Transports

| Capability | Classification | 1.0 boundary |
|---|---|---|
| Android Cronet/HttpEngine transport | `REQUIRED FOR 1.0` | One shared engine per AlphaX client/process policy; provider and protocol capabilities are discoverable. |
| iOS URLSession transport | `REQUIRED FOR 1.0` | One shared URLSession-backed adapter with data, stream, upload, and download behavior mapped to the public contract. |
| macOS URLSession transport | `REQUIRED FOR 1.0` | The Apple adapter supports the same required contract and protocol reporting on supported macOS deployment targets. |
| Dart IO fallback | `REQUIRED FOR 1.0` | Provides the common fallback/baseline surface; its unavailable H2/H3 capabilities are reported rather than implied. |
| Transport capability discovery | `REQUIRED FOR 1.0` | Applications can inspect protocol, streaming, file, proxy, TLS, and metric capabilities without seeing native types. |
| Client/session reuse | `REQUIRED FOR 1.0` | A client owns reusable transport state; sequential and concurrent requests do not create a new session by default. |

### Core HTTP

| Capability | Classification | 1.0 boundary |
|---|---|---|
| GET | `REQUIRED FOR 1.0` | Standard GET request and response behavior through every supported adapter. |
| POST | `REQUIRED FOR 1.0` | Standard POST with byte, text, JSON, streamed, and multipart bodies where selected. |
| PUT | `REQUIRED FOR 1.0` | Standard PUT with deterministic body and cancellation semantics. |
| PATCH | `REQUIRED FOR 1.0` | Standard PATCH without automatic unsafe retries. |
| DELETE | `REQUIRED FOR 1.0` | Standard DELETE with response/error normalization. |
| HEAD | `REQUIRED FOR 1.0` | Headers/status are returned without requiring a response body. |
| OPTIONS | `REQUIRED FOR 1.0` | Standard OPTIONS request, including empty-body responses. |
| Headers | `REQUIRED FOR 1.0` | Immutable, case-insensitive, multi-value request and response headers. |
| Query parameters | `REQUIRED FOR 1.0` | URI/query construction preserves repeated keys, encoding, and existing query values. |
| Byte body | `REQUIRED FOR 1.0` | Exact byte request and response behavior without implicit text conversion. |
| Text body | `REQUIRED FOR 1.0` | Explicit UTF-8 text convenience behavior with declared content type. |
| JSON helpers | `REQUIRED FOR 1.0` | `dart:convert`-compatible UTF-8 JSON request/response helpers; no model generator. |
| Streamed request body | `REQUIRED FOR 1.0` | `Stream<List<int>>` or equivalent body source with bounded consumption and cancellation. |
| Streamed response body | `REQUIRED FOR 1.0` | Response chunks are delivered as a bounded Dart stream with pause/resume semantics. |
| Redirects | `REQUIRED FOR 1.0` | Configurable redirect policy, maximum count, method handling, and sensitive-header policy. |
| `multipart/form-data` | `REQUIRED FOR 1.0` | Transport-neutral multipart fields and file parts; no dependency on Dio `FormData` types. |

### Lifecycle

| Capability | Classification | 1.0 boundary |
|---|---|---|
| Cancellation | `REQUIRED FOR 1.0` | Cancellation is prompt, idempotent, observable, and releases request resources. |
| Connect/request/read/overall timeout semantics | `REQUIRED FOR 1.0` | Overall timeout is mandatory; connect/request/read timeouts are exposed only where the provider can implement them and are capability-reported otherwise. |
| Deterministic client close | `REQUIRED FOR 1.0` | `close()` completes after owned sessions, callbacks, streams, and native resources are quiescent. |
| Request cleanup | `REQUIRED FOR 1.0` | Every terminal path cleans handles, streams, timers, files, callbacks, and ownership records exactly once. |
| Error normalization | `REQUIRED FOR 1.0` | Transport, timeout, cancellation, protocol, TLS, proxy, and HTTP status failures map to stable AlphaX errors with safe diagnostics. |

### Streaming and files

| Capability | Classification | 1.0 boundary |
|---|---|---|
| Bounded backpressure | `REQUIRED FOR 1.0` | Native producers cannot grow memory without bound when a Dart consumer pauses; queue limits are observable in diagnostics/tests. |
| Upload progress | `REQUIRED FOR 1.0` | Optional-length progress events report bytes sent and completion without changing body semantics. |
| Download progress | `REQUIRED FOR 1.0` | Optional-length progress events report bytes received and completion without requiring body buffering. |
| File upload | `REQUIRED FOR 1.0` | A transport-neutral file source supports exact byte count, hash/correctness checks, cancellation, and progress. |
| File download | `REQUIRED FOR 1.0` | A transport-neutral file target supports exact byte count, hash/correctness checks, cancellation, and progress. |
| Native file-backed transfer where supported | `REQUIRED FOR 1.0` | Android/Apple adapters use native file paths/tasks where the platform supports them; capability metadata identifies the path used. |
| Cancellation during upload/download | `REQUIRED FOR 1.0` | Cancellation during active file transfer stops network and file work and releases both sides deterministically. |

### Security and network controls

| Capability | Classification | 1.0 boundary |
|---|---|---|
| TLS verification by default | `REQUIRED FOR 1.0` | Certificate verification is enabled by default; insecure bypass requires an explicit, difficult-to-miss test-only/configuration path. |
| Certificate configuration where platform permits | `REQUIRED FOR 1.0` | Custom trust roots, server-auth configuration, and verification limitations are exposed through transport-neutral policy/capabilities. |
| Certificate pinning where platform permits | `OPTIONAL FOR 1.0` | No universal pinning promise; supported adapters may expose a documented capability without making unsupported platforms appear equivalent. |
| Client certificates/mTLS where practical | `OPTIONAL FOR 1.0` | Provider/platform support may be exposed, but mTLS is not a 1.0 release gate. |
| Proxy behavior and capability reporting | `REQUIRED FOR 1.0` | System/explicit proxy behavior is documented per platform; unsupported proxy modes are reported and never silently treated as direct. |

### Architecture

| Capability | Classification | 1.0 boundary |
|---|---|---|
| Transport-independent public API | `REQUIRED FOR 1.0` | `alphax` owns requests, responses, policies, streams, errors, capabilities, and metrics without selecting a native library. |
| No native transport-specific public types | `REQUIRED FOR 1.0` | No public `Curl*`, `Reqwest*`, `Cronet*`, `URLSession*`, Rust, or FFI handle types. |
| Capability model | `REQUIRED FOR 1.0` | A stable model describes supported protocols and optional behavior such as native files, proxy, TLS, and timeout granularity. |
| Protocol enum | `REQUIRED FOR 1.0` | A transport-neutral enum represents HTTP/1.1, HTTP/2, HTTP/3, unknown, and unavailable/unsupported states as appropriate. |
| Transport-neutral metrics | `REQUIRED FOR 1.0` | Nullable metrics cover protocol, connect/TLS/TTFB/transfer/total timing, byte counts, reuse, and fallback; unavailable data is absent, not invented. |
| Middleware/interceptor foundation | `REQUIRED FOR 1.0` | Request/response hooks can add metadata, logging, and policy without embedding cache, retry, auth, or vendor SDK behavior. |
| Testing/fake transport support | `REQUIRED FOR 1.0` | `alphax_test` supplies deterministic fakes, streams, cancellation, timeout, protocol, and error scenarios for public contract tests. |

### Developer experience

| Capability | Classification | 1.0 boundary |
|---|---|---|
| Clear README examples | `REQUIRED FOR 1.0` | Examples cover client creation, methods, headers/query, JSON, streams, files, cancellation, capabilities, and protocol reporting. |
| Consistent errors | `REQUIRED FOR 1.0` | Error categories, retry safety, cancellation identity, and diagnostic redaction are documented and stable. |
| Immutable request/response models where appropriate | `REQUIRED FOR 1.0` | Request/response metadata and headers are immutable; stream/file handles remain explicitly lifecycle-controlled. |
| Package documentation | `REQUIRED FOR 1.0` | Each shipped package documents purpose, platform support, setup, limitations, security, and examples. |
| Migration guidance from Dio/`package:http` where applicable | `REQUIRED FOR 1.0` | Documentation maps common request, interceptor, cancellation, stream, file, and error patterns without promising full adapter compatibility. |

## Required-item completion contracts

Every row marked `REQUIRED FOR 1.0` must satisfy all fields below. The compact
contracts are grouped by domain, but each named capability has its own row and
its own completion criterion. Where one `Item` cell names several capabilities,
the contract applies independently to every named capability.

### Protocol and transport contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| HTTP/1.1 | Ordinary HTTP requests work when H1 is negotiated. | `NegotiatedProtocol.http11` is public and transport-neutral. | All adapters support H1 and expose the observed version. | Android, iOS, macOS, Windows, Linux. | Dart IO handles unsupported native-provider cases. | H1 TLS/HTTP conformance for every adapter. | Platform/protocol support matrix and negotiation examples. | All required adapters pass H1 correctness and reporting tests. |
| HTTP/2 | Multiplexed H2 requests work where the server/path supports H2. | Same request API; no H2-specific public type. | Cronet/HttpEngine and URLSession must enable and verify H2 through ALPN. | Android, iOS, macOS. | Correct H2→H1 fallback is reported; Windows/Linux may report unavailable under Dart IO. | ALPN, concurrent requests, reuse, stream, cancellation, and fallback tests. | State provider/OS prerequisites and fallback semantics. | H2 is observed and correctly reported on every required platform. |
| HTTP/3 | QUIC/H3 can be attempted through the native platform provider. | Protocol preference/requirement and `NegotiatedProtocol.http3`; no QUIC type. | Cronet/HttpEngine or URLSession H3 path, verified rather than inferred. | Android, iOS, macOS. | H3→H2/H1 fallback includes actual protocol and reason; no H3 claim on Dart IO. | Real-device/Apple-platform protocol tests, server support, fallback, cancellation, and reconnect cases. | H3 prerequisites, fallback, unsupported-provider behavior, and limitations. | H3 capability and actual negotiation are verified on all three required platform families. |
| Negotiated protocol reporting | Developers can inspect the protocol actually used for each response. | Immutable response `protocol` plus nullable protocol diagnostics. | Each adapter maps provider version data without guessing. | All supported adapters. | `unknown`/unavailable is explicit when the provider cannot report. | Per-provider version capture and mismatch tests. | Response/metrics reference and examples. | No report labels a run/request with a protocol the provider did not observe. |
| Fallback reporting | Developers can distinguish intended H3 from H2/H1 fallback. | Immutable fallback metadata/reason code and capability result. | Adapters preserve provider/network failure or fallback information where exposed. | Android, iOS, macOS; Dart IO reports no H3 capability. | Unsupported requirement returns normalized capability error; auto mode returns a successful response with fallback metadata. | H3 unavailable, server-no-H3, proxy, timeout, and network-blocked-QUIC fixtures. | Fallback truth table and troubleshooting guidance. | Every fallback path is correct, observable, and covered by contract tests. |
| Android Cronet/HttpEngine transport | Android apps use the same AlphaX client API with native H1/H2/H3 capability. | Provider-neutral configuration and capability objects only. | Shared engine, async callbacks, bounded delivery, cancellation, native file paths, TLS/proxy policy. | Android supported release/device matrix. | Provider unavailable: explicit capability result; Dart IO may serve only capabilities it supports. | Instrumented device tests for protocols, lifecycle, files, streams, provider selection, and cleanup. | Installation/provider policy, permissions, limitations, and examples. | Release/profile Android build passes all required contract tests without C++ AlphaX code. |
| iOS URLSession transport | iOS apps use the same API with native Apple networking. | No URLSession types escape the adapter. | Shared URLSession, delegate/async bytes, upload/download tasks, cancellation, ATS/TLS, protocol metrics. | Supported iOS deployment targets and physical devices. | Dart IO fallback is explicit and reports its protocol ceiling. | Device tests for H1/H2/H3 negotiation, fallback, files, cancellation, and resource release. | Signing/build setup, ATS, OS requirements, and limitations. | Release/profile iOS adapter passes all required contract tests and reports protocol truthfully. |
| macOS URLSession transport | macOS apps use the Apple adapter with the same public API. | Same platform-neutral models as iOS. | URLSession session reuse, streaming/files, TLS/proxy, protocol observation. | Supported macOS deployment targets. | Dart IO fallback with capability reporting. | macOS H1/H2/H3, stream/file, timeout, cancellation, and close tests. | macOS entitlements, deployment target, setup, and support matrix. | Release/profile macOS adapter passes required contract and protocol tests. |
| Dart IO fallback | Applications can make supported requests when native adapters are unavailable. | Public adapter selection remains hidden behind the transport contract. | Async `HttpClient`, streams, files, TLS, proxy, timeout, cancellation, and H1 reporting. | Windows, Linux, Android/iOS/macOS fallback where allowed. | H2/H3 unavailable states are returned; no unsupported protocol is silently claimed. | Pure Dart contract, H1 correctness, stream/backpressure, files, cancellation, timeout, and close tests. | Fallback limits, proxy/TLS behavior, and selection guidance. | Dart IO passes the core contract suite and never misreports H2/H3. |
| Transport capability discovery | Developers can choose behavior based on supported capabilities. | Immutable `AlphaXCapabilities` and nested feature flags. | Each adapter reports protocols, fallback, files, proxy, TLS, timeout granularity, and metrics. | All adapters. | Unknown values are nullable/explicitly unavailable. | Snapshot/contract tests for each adapter and provider. | Capability reference and example feature gating. | Capability output is stable, truthful, and independent of native types. |
| Client/session reuse | One client efficiently reuses transport state across requests. | Client owns session lifecycle; no per-request native session API. | Shared Cronet engine/URLSession/HttpClient and bounded pool settings. | All supported adapters. | Fallback client reuses Dart IO `HttpClient`. | Sequential reuse, concurrent reuse, close/reopen, and connection-observation tests. | Client lifetime and reuse guidance. | Reuse and shutdown behavior are deterministic under contract tests. |

### Core HTTP contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| GET, POST, PUT, PATCH, DELETE | Standard methods work with status, headers, body, cancellation, and errors. | `AlphaXRequest.method` accepts normalized standard tokens; convenience methods may delegate to it. | Adapters preserve method, body, headers, redirects, and timeout semantics. | All supported adapters; H2/H3 required on Android/iOS/macOS. | Dart IO handles all methods with its supported protocol capabilities. | Method matrix, empty/non-empty bodies, status, headers, redirects, cancellation, and unsafe retry absence. | One example per method family and mutation-safety note. | Every method passes the shared contract suite on every supported adapter. |
| HEAD, OPTIONS | HEAD returns metadata without requiring body consumption; OPTIONS returns server response semantics. | Same `AlphaXRequest` API and immutable response. | Adapters do not invent bodies or discard required headers. | All supported adapters. | Dart IO equivalent. | Empty-body/status/header and redirect tests. | Method reference and examples. | Correct body/header semantics pass on every adapter. |
| Headers | Multi-value and case-insensitive headers behave consistently. | Immutable `AlphaXHeaders` request/response model. | Native conversions preserve repeated values and redaction rules. | All supported adapters. | Dart IO conversion. | Case, duplicate, empty, forbidden, and sensitive-header tests. | Header behavior and security redaction. | Round-trip and normalization tests pass without data loss. |
| Query parameters | Repeated keys and encoding are preserved. | URI/query helper or documented `Uri` construction; no native URI type. | Adapters receive the final exact URI. | All supported adapters. | Dart IO exact URI. | Unicode, reserved characters, repeated keys, empty values, fragments, and existing query tests. | URI/query examples. | Generated request targets match the contract fixtures exactly. |
| Byte body | Exact bytes can be sent/received. | `AlphaXBytesBody`/byte response access with immutable ownership semantics. | Native bridges copy or transfer ownership safely and report sizes. | All supported adapters. | Dart-managed bytes through Dart IO. | Binary fixtures, hashes, content lengths, and cancellation. | Byte-body and ownership guidance. | Byte hashes and lengths match on all adapters. |
| Text body | UTF-8 text convenience behavior is predictable. | `AlphaXTextBody` and explicit encoding/content-type policy. | Adapters send exact encoded bytes. | All supported adapters. | Dart IO exact encoding. | Unicode, empty, invalid/declared encoding, and response conversion tests. | Text/encoding examples. | Encoded bytes and decoded text are deterministic. |
| JSON helpers | Common JSON requests/responses require minimal boilerplate. | JSON helpers use `dart:convert`; model conversion stays caller-owned. | No transport-specific JSON parser is required. | All supported adapters. | Dart IO. | UTF-8, malformed JSON, content type, large-body opt-in, and error tests. | JSON examples and parsing boundary. | Helpers are documented, tested, and do not hide transport timing. |
| Streamed request body | Large or generated request bodies can stream without full buffering. | Body source accepts `Stream<List<int>>` plus length when known. | Native upload callbacks honor bounded demand, pause, cancellation, and content length. | All supported adapters. | Dart IO request sink/backpressure. | Slow producer/consumer, unknown length, cancellation, retry absence, and hash tests. | Streaming upload guide and limits. | No adapter requires whole-body buffering for the streamed contract. |
| Streamed response body | Large responses can be consumed incrementally. | Response exposes `Stream<List<int>>`/events with lifecycle ownership. | Native delivery is bounded and pause/resume-aware. | All supported adapters. | Dart IO response stream. | Completeness, pause/resume, slow consumer, cancellation, RSS bound, and close tests. | Streaming guide and ownership rules. | All adapters pass bounded stream correctness and cleanup tests. |
| Redirects | Redirect behavior is explicit and bounded. | `RedirectPolicy`, maximum count, and sensitive-header policy. | Native redirect callbacks are normalized; method/body rules are documented. | All supported adapters. | Dart IO policy. | Count, loop, relative/absolute, cross-origin header, method, and cancellation tests. | Redirect security and policy examples. | Redirect behavior is identical at the public-contract level. |
| `multipart/form-data` | Fields and file parts can be uploaded without depending on Dio. | Transport-neutral multipart body/part models and progress hooks. | Adapters stream boundaries and file parts with exact lengths when available. | All supported adapters. | Dart IO multipart stream. | Boundary, repeated fields, Unicode, file hash, cancellation, and content-length tests. | Multipart/file examples and memory limits. | Multipart fixtures pass without whole-request buffering requirement. |

### Lifecycle contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| Cancellation | A canceled request stops work and completes with a distinct cancellation error. | `AlphaXCancellationToken`/signal and idempotent cancellation result. | Native cancel APIs, callback suppression, stream closure, and file cleanup. | All supported adapters. | Dart IO abort/close. | Waiting, headers, streaming, upload, download, paused, repeated-cancel, and race tests. | Cancellation lifecycle and race guarantees. | No post-cancel body delivery or leaked resource is observed. |
| Connect/request/read/overall timeouts | Timeouts fail predictably at the stage represented by the provider. | Immutable `AlphaXTimeouts` plus capability flags for granular support. | Native timers/URLSession/Cronet policies; no blocking sleep or coarse poll. | All supported adapters. | Dart IO maps available timers and reports unsupported granularity. | Stage-specific fixtures, boundary timing, cancellation, and cleanup tests. | Timeout definitions, precedence, and unavailable-stage behavior. | Overall timeout is universal; every granular promise is either tested or reported unavailable. |
| Deterministic client close | Closing a client prevents new work and drains/cancels owned work according to policy. | `Future<void> close()` and closed-state error. | Engine/session/HttpClient invalidation and callback quiescence. | All supported adapters. | Dart IO close. | Close idle, active, paused, failed, and repeated-close scenarios. | Client lifecycle guide. | Close is idempotent and leaves no owned operation active. |
| Request cleanup | Every request terminal state releases memory, callbacks, files, timers, and handles. | No new native type; diagnostic IDs remain opaque. | Exactly-once cleanup on success/error/cancel/timeout/close. | All supported adapters. | Dart IO stream/request cleanup. | Fault injection and leak/resource-release tests. | Lifecycle ownership table. | Repeated stress/contract tests show no retained operation state. |
| Error normalization | Errors are catchable by stable category and retain safe context. | Immutable `AlphaXException` hierarchy with stage/protocol/status metadata. | Map provider/TLS/proxy/HTTP/timeout/cancel errors without raw handles. | All supported adapters. | Dart IO mapping. | Error matrix, redaction, equality/category, and cancellation distinction. | Error reference and handling examples. | Public errors are stable, documented, and secret-safe. |

### Streaming/file contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| Bounded backpressure | A paused consumer cannot cause unbounded native buffering. | Stream semantics plus bounded-buffer diagnostics/capabilities. | Cronet/URLSession/native adapters stop or limit production; no arbitrary queue growth. | Android, iOS, macOS native; Dart IO fallback. | Dart subscription pause controls reads; limits are reported. | Fast/moderate/slow/paused consumers, max queue/RSS, pause latency, resume, cancel. | Backpressure contract and examples. | Configured bounds are enforced and verified for every native adapter. |
| Upload/download progress | Applications can display progress when lengths are known. | `AlphaXProgress` event/callback with optional total and direction. | Native callbacks must not change body semantics or create unbounded event queues. | All supported adapters. | Dart IO counts stream/file bytes. | Known/unknown lengths, throttling, cancellation, and final-byte tests. | Progress semantics and unknown-total behavior. | Progress is monotonic, bounded, and documented. |
| File upload/download | Applications can transfer files with correctness and lifecycle control. | Transport-neutral file source/target; no `File`, URLSession, Cronet, or native handle in `alphax`. | Native adapters may open platform-valid paths; stream fallback remains correct. | All supported adapters; native optimization on Android/iOS/macOS. | Dart IO file stream/sink. | Exact bytes, deterministic hash, progress, cancel, partial-file cleanup, and permissions. | File-transfer examples and path/security guidance. | All required file fixtures pass with matching hashes and cleanup. |
| Native file-backed transfer where supported | Large native transfers can avoid routing the whole body through Dart. | Capability/metrics identify direct native-file path; result remains transport-neutral. | URLSession download/upload tasks and Android native file I/O where Cronet integration permits. | Android, iOS, macOS. | Dart IO path is valid but reports `nativeFileTransfer=false`. | Compare route correctness, event counts, memory bound, cancellation, and cleanup. | Explain minimal-copy/direct-file terminology; no zero-copy claim. | Native path is correct and optional; fallback remains contract-equivalent. |
| Cancellation during upload/download | File transfer cancellation stops both network and local file work. | Same cancellation token and normalized error. | Native task/provider/file cancellation and exactly-once cleanup. | All supported adapters. | Dart IO stream/file cancellation. | Cancel before open, during connect, active transfer, paused transfer, and completion race. | Cancellation examples and partial-file policy. | No file descriptor, task, callback, or temporary file is leaked. |

### Security/control contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| TLS verification by default | HTTPS validates the peer without opt-out defaults. | `AlphaXTlsPolicy` defaults to verified system trust. | Cronet/URLSession/Dart IO preserve secure defaults; no global bypass. | All supported adapters. | Dart IO verified trust. | Valid, expired, hostname, untrusted, and local test-CA cases. | Secure defaults and test-only bypass warning. | Invalid certificates fail consistently and are never silently accepted. |
| Certificate configuration where platform permits | Applications can supply supported trust/client-auth configuration explicitly. | Transport-neutral certificate/trust policy and capability result. | Map platform-supported roots/credential configuration without claiming parity. | Android, iOS, macOS; Dart IO where supported. | Unsupported configuration returns capability/error state. | Custom CA, trust reset, credential lifecycle, and invalid config tests. | Platform capability table and secure storage guidance. | Supported configurations pass; unsupported ones are explicit and safe. |
| Proxy behavior and capability reporting | Applications can use configured system/explicit proxies where supported and know limitations. | `AlphaXProxyPolicy` plus proxy capability metadata. | Preserve system proxy, explicit proxy, auth, CONNECT, and protocol limitations. | All supported adapters, with platform-specific modes. | Dart IO environment/configured proxy behavior is reported. | Direct/system/explicit/auth/HTTPS/unsupported-mode tests. | Proxy setup, security, and platform matrix. | No proxy mode is silently treated as direct or falsely reported. |

### Architecture contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| Transport-independent public API | The same request code works across selected transports. | `alphax` contains only stable Dart models/contracts. | Adapters implement interfaces without leaking implementation details. | All supported adapters. | Dart IO is a first-class contract implementation. | Compile/API tests with every adapter and fake. | Architecture overview and portability examples. | No public API import or type depends on native transport. |
| No native transport-specific public types | Applications do not manage native handles or provider objects. | Opaque IDs/diagnostics only; no Curl/Reqwest/Cronet/URLSession types. | Native ownership stays inside adapter package. | All supported adapters. | Same API through Dart IO. | Public export audit and compile-failure boundary tests. | API boundary rules. | Export audit finds no forbidden native type. |
| Capability model | Applications can feature-gate without guessing. | Immutable `AlphaXCapabilities` and nested feature values. | Each adapter populates known values; unknown remains explicit. | All supported adapters. | Dart IO reports its smaller capability set. | Matrix snapshots and unsupported-feature behavior. | Capability reference. | Capability values match observed provider behavior. |
| Protocol enum | Protocol policy and results are comparable. | Stable `AlphaXProtocol` enum and preference/requirement model. | Map H1/H2/H3/unknown without string parsing. | All supported adapters. | Unknown/unavailable states remain explicit. | Serialization, negotiation, fallback, and unknown-version tests. | Enum reference and examples. | Enum is stable and exhaustively documented. |
| Transport-neutral metrics | Developers can inspect useful timings and byte counts without provider types. | Immutable nullable metrics on response/diagnostics. | Adapters report only reliable measurements and connection reuse where observable. | All supported adapters. | Missing metrics are null/unsupported. | Timing boundary, bytes, protocol, reuse, fallback, and redaction tests. | Metrics reference and limitations. | No metric is invented or mislabeled. |
| Middleware/interceptor foundation | Applications can add request/response policy without changing transports. | Ordered request/response interceptor interface with async support. | Interceptors surround the transport and preserve cancellation/stream lifecycle. | All supported adapters. | Works identically with Dart IO/fakes. | Order, mutation, errors, streaming, cancellation, and reentrancy tests. | Middleware examples and safety rules. | Foundation is stable without embedding cache/retry/auth vendors. |
| Testing/fake transport support | Applications and AlphaX can test behavior deterministically without native devices. | `alphax_test` fake transport/server/stream helpers. | Fakes implement the public transport contract and injectable failures. | Pure Dart. | N/A; fakes are the fallback for tests. | Contract suite, timing, errors, streams, files, and cancellation. | Testing guide and fixture examples. | Required behavior can be tested without native libraries. |

### Developer-experience contracts

| Item | User-facing behavior | Public API impact | Transport requirements | Supported platforms | Fallback behavior | Tests | Documentation | Completion criteria |
|---|---|---|---|---|---|---|---|---|
| Clear README examples | A new user can perform common requests and understand protocol/fallback output. | Examples use only public AlphaX types. | Examples work with Dart IO and document native setup separately. | Dart/Flutter mobile, Apple, Windows/Linux examples as applicable. | Dart IO examples are runnable where `dart:io` exists. | Example compile/analyze checks and smoke tests. | README and package example directories. | Examples are reproducible and make no unsupported performance claim. |
| Consistent errors | Users can handle errors without provider-specific branches. | Stable error categories and safe diagnostic fields. | Native error mapping preserves stage and retry safety. | All supported adapters. | Dart IO/fake mappings match categories. | Cross-adapter error contract tests. | Error/migration reference. | Error handling examples compile and categories are documented. |
| Immutable request/response models where appropriate | Shared data cannot be mutated unexpectedly after dispatch. | Final/immutable models, headers, metrics, and policy values. | Adapters snapshot inputs and own mutable native state privately. | All supported adapters. | Dart IO same ownership rules. | Mutation attempts, concurrent reads, and lifecycle tests. | Immutability and ownership guide. | Public model audit and tests pass. |
| Package documentation | Each package explains exactly what it ships and supports. | Package READMEs/API docs are part of release gate. | Native packages document provider/deployment/build requirements. | Each claimed platform only. | Fallback limitations documented. | Documentation link/command and example checks. | Package README, API docs, security, changelog. | Docs match capability output and release artifacts. |
| Migration guidance from Dio/`package:http` where applicable | Existing users can map common calls without expecting full compatibility. | No dependency on Dio types in `alphax`; adapter remains separate. | Mapping covers interceptors, cancellation, streams, files, errors, and protocol data. | Dart/Flutter users. | No adapter required to use core API. | Documentation examples and representative migration tests. | Migration guide and explicit unsupported mappings. | Guide is accurate and complete for the supported 1.0 surface. |

## Explicit 1.0 boundaries for additional capabilities

| Capability | Classification | 1.0 decision and boundary |
|---|---|---|
| Dio adapter | `OPTIONAL FOR 1.0` | `alphax_dio` provides a focused Dio 5.x `HttpClientAdapter` over an injected `AlphaXClient`; it is optional to the native transport gate, must not expand `alphax`’s API, and does not promise full Dio compatibility. |
| Cache | `POST-1.0` | No HTTP cache, stale policy, eviction, or cache metrics in the 1.0 transport/client release. |
| Retry/resilience | `POST-1.0` | No automatic retry policy; errors expose safe retry context, and unsafe mutations are never silently retried. |
| Circuit breaker | `POST-1.0` | No circuit state, failure budgets, or breaker middleware in 1.0. |
| Offline queue | `POST-1.0` | No durable queue, replay, resumable metadata, or offline mutation storage in 1.0. |
| OpenTelemetry | `POST-1.0` | No exporter or OpenTelemetry dependency; transport-neutral metrics remain available for later integration. |
| Sentry/Firebase Performance | `EXPLICIT NON-GOAL` | Vendor telemetry SDK integration is outside AlphaX 1.0; applications may integrate from public errors/metrics. |
| DevTools extension | `POST-1.0` | No dedicated extension or inspector protocol in 1.0. |
| GraphQL | `EXPLICIT NON-GOAL` | AlphaX provides HTTP primitives only; GraphQL schema/client behavior is not an AlphaX 1.0 responsibility. |
| REST generator | `EXPLICIT NON-GOAL` | No code generator, schema compiler, or generated API surface in 1.0. |
| WebSocket | `POST-1.0` | No WebSocket abstraction in the 1.0 HTTP client contract. |
| SSE | `POST-1.0` | No SSE-specific reconnect/event parser in 1.0; raw streaming remains available. |
| Browser/web transport | `POST-1.0` | No browser Fetch/web implementation or web protocol parity claim in 1.0. |
| Cookie jar | `OPTIONAL FOR 1.0` | A provider may expose cookie behavior, but a cross-platform persistent cookie store is not a release gate. |
| Authentication framework | `EXPLICIT NON-GOAL` | No token refresh, credential store, or auth orchestration; headers and middleware are the boundary. |
| Request priorities | `OPTIONAL FOR 1.0` | Provider priority may be reported or exposed only where semantics are stable; it is not required for release. |

## Package changes required by this scope

| Package/area | Required 1.0 change |
|---|---|
| `packages/alphax` | Stabilize immutable request/response/body/header models, method/URI/query behavior, cancellation, timeout policy, errors, protocol enum, capabilities, metrics, middleware foundation, and transport interfaces. Keep the SDK constraint `>=3.8.0 <4.0.0` and no Flutter SDK constraint. |
| `packages/alphax_native` | Become the platform integration boundary for Cronet/HttpEngine and URLSession adapters, provider diagnostics, lifecycle bridging, and native file paths. It must not export native provider types. Its Flutter/platform dependencies are introduced only when the implementation is approved. |
| `packages/alphax_test` | Add deterministic fake transports, protocol/fallback fixtures, bounded streams, file fixtures, cancellation/timeouts, and shared contract tests. |
| `packages/alphax_dio` | Publish the isolated focused Dio 5.x adapter for the RC when its lifecycle, stream, cancellation, error, progress, and protocol metadata tests pass. Keep transport/TLS/proxy policy in the injected AlphaX client and do not expand `alphax`’s API. |
| `alphax_flutter` | No package is required by this scope. Create one only if a concrete Flutter-only lifecycle/platform integration cannot remain isolated in `alphax_native`, with a separate package-boundary review. |
| Android/iOS/macOS build areas | Add platform build files, provider setup, signing/device test configuration, and release artifacts only during the corresponding Phase 1 transport phases. No native source is added by this scope document. |
| Documentation/CI | Replace conflicting capability status tables with links to this document, add protocol/provider matrices, device/platform validation, security/build instructions, examples, and release checks. |

## Implementation roadmap

The roadmap is sequenced; a later phase cannot declare completion while an
earlier phase’s exit criteria remain open. This roadmap does not authorize work
by itself; implementation begins only after maintainer review and ADR 0004
acceptance.

### Phase 1A — Stabilize transport-independent core API

Deliverables:

- Immutable request, response, header, body, method, URI/query, error,
  cancellation, timeout, protocol, capability, metric, middleware, and transport
  contracts in `alphax`.
- Transport-neutral file source/target and progress models.
- Public API documentation and compatibility rules.

Dependencies:

- This scope document, ADR 0003, existing contract review, and `alphax_test`.

Tests:

- Pure Dart unit/API tests, immutability tests, serialization/headers tests,
  cancellation/timeout/error tests, and fake transport contract tests.

Exit criteria:

- `alphax` has no Flutter/native dependency; all required core contracts are
  reviewed and tested; no native-specific public type is exported.

### Phase 1B — Dart IO fallback transport

Deliverables:

- A supported Dart IO adapter implementing the stabilized contract, H1,
  streams, bounded Dart-side consumption, files, TLS defaults, proxy behavior,
  cancellation, timeouts, cleanup, and metrics.
- Capability output explicitly marks H2/H3 unavailable unless the runtime
  demonstrably supports them.

Dependencies:

- Phase 1A and the existing Dart IO prototype as implementation evidence.

Tests:

- H1 TLS correctness, all required methods/bodies, redirects, multipart,
  streams/backpressure, files/hashes, progress, timeouts, cancellation, close,
  proxy, error, and capability tests on Windows/Linux plus Dart-supported mobile
  fallback targets.

Exit criteria:

- Dart IO passes the common contract suite and is safe to use as fallback without
  misreporting H2/H3 or leaking resources.

### Phase 1C — Android Cronet/HttpEngine transport

Deliverables:

- Android platform adapter with shared engine/session lifecycle, provider policy,
  H1/H2/H3 negotiation reporting, fallback metadata, bounded streaming,
  cancellation, progress, native file-backed paths, TLS/proxy controls, and
  capability discovery.
- Release/profile packaging and provider/device documentation.

Dependencies:

- Phase 1A contract, Phase 1B fallback, approved `alphax_native` packaging,
  Android provider/min-API decision, signing, and device test access.

Tests:

- Physical-device/instrumented H1/H2/H3 negotiation, provider unavailable and
  fallback tests, streams/backpressure, concurrent reuse, upload/download
  hashes, cancellation/close, TLS/proxy, and native file tests.

Exit criteria:

- Android release/profile builds pass the required contract suite and every
  protocol result is observed and reported accurately on the supported provider
  matrix.

### Phase 1D — iOS/macOS URLSession transport

Deliverables:

- Shared Apple adapter for iOS/macOS URLSession data/stream/upload/download
  tasks, lifecycle, H1/H2/H3 reporting, fallback metadata, files, progress,
  cancellation, TLS/proxy capability, and cleanup.
- Deployment-target, ATS, entitlements, signing, and release documentation.

Dependencies:

- Phase 1A contract, Phase 1B fallback, approved platform package boundary,
  supported OS deployment targets, Xcode/signing configuration, and physical
  device access for iOS H3 validation.

Tests:

- iOS physical-device and macOS H1/H2/H3 negotiation, fallback, stream/file,
  progress, cancellation, timeout, TLS/proxy, session reuse, and close tests.

Exit criteria:

- iOS and macOS release/profile adapters pass the required contract suite and do
  not report H3 when URLSession negotiated H2/H1.

### Phase 1E — Protocol/capability validation and parity

Deliverables:

- Shared conformance matrix for H1/H2/H3, protocol fallback, capability output,
  lifecycle, streaming, and file transfer across Dart IO, Android, iOS, and
  macOS.
- Deterministic TLS/protocol fixtures and release/profile validation tooling.

Dependencies:

- Phases 1A–1D, stable fixture servers, device/desktop CI access, and provider
  version recording.

Tests:

- Cross-adapter correctness, negotiated-version truth, fallback reasons,
  bounded backpressure, hashes, progress, cancellation races, cleanup, proxy,
  TLS, error parity, and protocol capability discovery.

Exit criteria:

- Required behavior is contract-equivalent, unsupported behavior is explicit,
  and H1/H2/H3 are verified on Android/iOS/macOS without a broad performance
  benchmark round.

### Phase 1F — 1.0 API hardening, documentation, and release validation

Deliverables:

- Final API review, changelog/migration examples, package READMEs/API docs,
  security guidance, platform matrix, examples, and release artifacts.
- CI for public packages and supported platform adapters; package dry-run
  publication validation.

Dependencies:

- Phase 1E complete, ADR 0004 accepted, naming clearance, license/security
  review, and maintainer release approval.

Tests:

- Full required package validation, API compatibility checks, platform release
  builds, device smoke tests, protocol/fallback tests, resource cleanup, and
  documentation/example validation.

Exit criteria:

- Every `REQUIRED FOR 1.0` row is complete with evidence and documentation;
  unresolved platform limitations are either outside the stated support matrix
  or block the release. No package is published until naming clearance and
  release approval are complete.

## 1.0 release gate

AlphaX 1.0 cannot ship until:

- H1/H2/H3 capability is verified through the selected native Android, iOS,
  and macOS platform transports on representative provider/device paths; an
  individual request may fall back when the server, proxy, or network does not
  negotiate H3.
- Negotiated protocol and fallback are observable and truthful.
- Dart IO fallback is correct and explicitly reports its protocol ceiling.
- Core methods, bodies, redirects, multipart, lifecycle, errors, streaming,
  bounded backpressure, files, progress, TLS defaults, proxy behavior,
  capabilities, metrics, middleware, fakes, docs, and examples meet every
  required contract above.
- No native transport-specific type leaks into `alphax`.
- Release/profile builds, platform tests, package validation, security review,
  and documentation checks pass.

The historical Phase 0 reports remain evidence for measured HTTP/1.1 behavior;
they are not rewritten to imply H2/H3 performance conclusions.

## Remaining publication prerequisites

The architecture review found no new protocol contradiction. The
implementation/evidence prerequisites are complete for RC review; publication
still requires these final non-technical approvals:

- Naming clearance before publication.
- Maintainer approval of the frozen public API and RC review document.
- Publication approval after the package dry-runs and final validation pass.
