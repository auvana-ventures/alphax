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

In the current FFI prototypes, libcurl and Rust allocate a native chunk, invoke a
listener callback, and Dart copies the callback memory into an owned `List<int>`
before releasing the native allocation. The benchmark runner records process RSS
observations, bytes, throughput, and cancellation/resource-probe outcomes, but it
does not yet provide a reliable Dart heap peak or bounded queue-depth measurement.
Chunk size, queue depth, pause behavior, and peak native/Dart memory remain evidence
to collect before production use.

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
| libcurl/FFI | libcurl callback → native allocation → Dart list | native callback allocation → Dart list per chunk | native `FILE*` read callback | native callback → native `FILE*` |
| Rust/FFI | reqwest bytes → native vector → Dart list | native vector → Dart list per chunk | Tokio `ReaderStream` → reqwest body | reqwest stream → Tokio file |

## Required measurements

- Dart heap peak.
- Native allocation/process memory peak where available.
- Chunk size and queue depth.
- Bytes transferred through Dart for streamed and direct-file paths.
- Binary-size delta for each native dependency.
