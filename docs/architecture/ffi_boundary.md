# FFI Boundary (Phase 0 Draft)

This document is a design constraint for prototypes, not an accepted production
ABI. The selected transport ADR must revise it with measured implementation details.

## Request lifecycle

1. Dart creates an immutable request description.
2. The native adapter allocates a request context and copies only metadata required
   by the native library.
3. The native operation starts on its owned runtime/event loop.
4. Dart may request cancellation while the context is active.
5. Completion, failure, or cancellation closes the native operation before the
   context is freed.

## Ownership rules

| Resource | Allocator | Owner | Release point |
| --- | --- | --- | --- |
| Request metadata | Native adapter | Request context | After terminal callback and Dart acknowledgement |
| Native receive buffer | Native transport | Native transport | After chunk delivery/consumption |
| Dart chunk | Dart/FFI bridge | Dart stream subscription | Consumer lifecycle |
| File descriptor | Native adapter or caller | Transfer operation | Transfer completion/cancellation |
| Callback handle | Dart runtime | Request context | Before context destruction |

The final ABI must use explicit integer handles or opaque pointers, define allocator
pairing, and prevent Dart from retaining borrowed native memory.

## Streaming and backpressure

```text
native producer → bounded queue → Dart consumer
```

The production queue must have a configured upper bound. The current benchmark
prototypes use `NativeCallable.listener` plus a Dart `StreamController`; callbacks
are copied into owned Dart chunks. Round 2 instrumentation measures producer and
consumer chunk counts, callback volume, and observed queued bytes. Round 3 adds a
configured native credit window: Dart acknowledges each copied chunk after the
downstream stream consumer resumes; native delivery emits no more than the
outstanding credit and waits when the window is exhausted. Cancellation
broadcasts to that wait and wakes the underlying event loop. This ABI is
benchmark-only and is not a production AlphaX API decision.

The experimental settings are per native-client instance. The current default
for reproducible experiments is a 64 KiB chunk target and four chunk credits,
while the Round 3 sweep also tests 16/32/64/128/256 KiB targets. The effective
capacity is reported with every stream result. Rust batches reqwest chunks to the
target; libcurl accumulates complete callback buffers in a bounded queue before
sending one FFI notification. libcurl never partially accepts a callback before
pausing because libcurl replays the complete callback buffer after
`CURL_WRITEFUNC_PAUSE`. Its effective queue floor is the bounded
`CURL_MAX_WRITE_SIZE` callback ingress when an intentionally tiny test window is
used; the normal 64 KiB × 4 configuration is larger than that floor. At most the
configured queue plus one bounded upstream callback buffer is resident, and this
is included in native accounting.

The Dart bridge copies native-owned callback buffers before returning them to the
native allocator. It reports Dart-side pending bytes separately from native
in-flight bytes. Native results include maximum in-flight chunks, maximum
buffered bytes, FFI notification count, credit exhaustion, pause/resume wait
latency, acknowledgements, and in-flight bytes at native completion. A slow
consumer therefore cannot create an arbitrarily growing native queue, although
the Dart stream controller remains an implementation detail rather than a
production queue contract.

## Cancellation and shutdown

Cancellation must interrupt the underlying operation, stop future callbacks, release
request resources, and resolve exactly once as success, failure, or
`AlphaXCancelledException`. Shutdown must wait for active native callbacks or make
their invalidation safe before unloading a dynamic library. Hot restart behavior
must be tested separately on Flutter platforms.

## File transfer

The preferred large-transfer paths are:

```text
download: socket → native transport → file descriptor → disk
upload:   disk → file descriptor → native transport → socket
```

Dart should receive progress and lifecycle events rather than full file contents.

The current libcurl and Rust benchmark adapters exercise native file paths: Dart
passes a file path, native code opens the file, and Dart receives transfer metadata.
The current Dart baseline writes response chunks through a Dart `IOSink` and reads
upload chunks through a Dart file stream. These are separate architectural paths and
remain labelled as such in result summaries.

## Threading

The Dart baseline runs on the Dart isolate and uses `HttpClient`. The Round 4
libcurl prototype owns one persistent worker and one client-owned `CURLM` multi
handle. Requests create concurrent easy handles on that worker and are added to
the same multi handle, allowing libcurl's connection pool to reuse sequential
connections. The worker uses `curl_multi_timeout` plus `curl_multi_poll` for
readiness, and `curl_multi_wakeup` for request creation, cancellation, and credit
acknowledgements; it does not use a fixed polling sleep or one worker thread per
request. The worker is joined before the client-owned multi/share state is
destroyed. The Rust prototype owns a
long-lived multi-thread Tokio runtime and reqwest client per Dart transport
instance; each FFI request is driven through that runtime from a native worker
thread. Round 2 adds server-side connection identifiers and request counts for
local observations; these are not protocol-level connection metrics where the
server cannot identify a client socket.
