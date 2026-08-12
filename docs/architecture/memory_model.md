# Memory and Copy Model

Phase 0 uses precise copy accounting rather than “zero-copy” marketing language.

## Small response

```text
socket
  → native transport buffer
  → Dart byte list
  → UTF-8 decode
  → application model
```

The native-to-Dart bridge is at least one observable application-level copy unless
an implementation proves otherwise. Copies inside the kernel, TLS stack, or
transport library are not ignored; they are simply recorded at their layer.

## Stream response

```text
socket
  → bounded native buffer
  → owned Dart chunk
  → consumer
```

In the Round 3 FFI prototypes, libcurl and Rust allocate a native chunk, invoke a
listener callback, and Dart copies the callback memory into an owned `List<int>`
before releasing the native allocation. Dart acknowledges the chunk only after
the stream consumer resumes. A per-request native credit window bounds the
number of FFI-delivered chunks that may remain unacknowledged. The experimental
default is four 64 KiB chunks; the actual chunk target, window, maximum in-flight
bytes, notification count, pauses, acknowledgements, and cancellation behavior
are recorded with each result. These are minimal-copy, bounded-flow experiments,
not zero-copy claims or production defaults.

There are two distinct memory quantities: native in-flight callback allocations
and Dart `StreamController` pending bytes. The native credit window bounds the
producer’s unacknowledged delivery, while the Dart bridge reports pending bytes
separately. A terminal native result can legitimately show outstanding in-flight
credits because Dart may still be draining already-delivered events; the native
handle is nevertheless cleaned up only after its terminal callback returns.

## Native file download

```text
socket → native buffer → file descriptor → disk
```

This is a minimal-copy target, not automatically zero-copy. The benchmark must
report the actual implementation and avoid claiming zero-copy when buffers cross an
FFI or operating-system boundary.

The current native paths write response chunks directly from the native callback
layer to a native file handle (`FILE*` for libcurl and Tokio file writes for Rust),
so Dart does not receive the file body. The current Dart baseline writes response
chunks to a Dart `IOSink`. These paths are not equivalent copy architectures and are
reported separately.

## Candidate copy accounting

| Candidate | Buffered response | Streaming response | Upload | Download |
| --- | --- | --- | --- | --- |
| `dart:io` | response chunks → Dart list | response chunks → owned Dart chunks | Dart file stream → request | response chunks → Dart sink |
| libcurl/FFI | libcurl callback → native allocation → Dart list | bounded native batch/credit window → Dart list per chunk | native `FILE*` read callback | native callback → native `FILE*` |
| Rust/FFI | reqwest bytes → native vector → Dart list | bounded native vector/credit window → Dart list per chunk | Tokio `ReaderStream` → reqwest body | reqwest stream → Tokio file |

## Required measurements

- Dart heap peak.
- Native allocation/process memory peak where available.
- Chunk size, callback frequency, native credit depth, observed Dart queue depth,
  maximum buffered bytes, and pause/resume behavior.
- Bytes transferred through Dart for streamed and direct-file paths.
- Binary-size delta for each native dependency.
