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

The queue must have a configured upper bound. A paused Dart subscription must either
propagate a pause to the native producer or apply a documented bounded policy; it
must never create unbounded native memory growth. Chunk ownership ends after the
consumer has received an owned Dart value or the native queue has reclaimed it.

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

## Threading

Each prototype must record its runtime/event-loop owner, callback thread, Dart isolate
interaction, shutdown behavior, and whether concurrent requests share a pool.
