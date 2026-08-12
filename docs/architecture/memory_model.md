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

Chunk size, queue depth, pause behavior, and peak native/Dart memory must be recorded
by the benchmark harness.

## Native file download

```text
socket → native buffer → file descriptor → disk
```

This is a minimal-copy target, not automatically zero-copy. The benchmark must
report the actual implementation and avoid claiming zero-copy when buffers cross an
FFI or operating-system boundary.

## Required measurements

- Dart heap peak.
- Native allocation/process memory peak where available.
- Chunk size and queue depth.
- Bytes transferred through Dart for streamed and direct-file paths.
- Binary-size delta for each native dependency.
