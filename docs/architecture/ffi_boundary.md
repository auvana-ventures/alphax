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
are copied into owned Dart chunks, but the prototype queue is not yet a measured
bounded backpressure implementation. A paused consumer therefore remains an
explicit production gap rather than an unsupported performance claim.

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

The Dart baseline runs on the Dart isolate and uses `HttpClient`. The libcurl
prototype performs each async request on a native worker thread with a per-request
multi/easy handle plus shared libcurl connection state. The Rust prototype owns a
long-lived multi-thread Tokio runtime and reqwest client per Dart transport
instance; each FFI request is driven through that runtime from a native worker
thread. Connection reuse is still not reported as a reliable numeric metric by
either FFI adapter and must remain unavailable in summaries until instrumented.
