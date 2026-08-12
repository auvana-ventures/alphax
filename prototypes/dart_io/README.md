# Dart `dart:io` Prototype

The Dart baseline uses a sensibly configured `dart:io` `HttpClient`. It is a real
baseline, not a strawman, and establishes what a native candidate must improve or
justify with memory, streaming, protocol, or platform evidence.

Run it with:

```text
dart run prototypes/dart_io/bin/benchmark.dart \
  --url http://127.0.0.1:8080/bytes/1024 \
  --requests 10 \
  --concurrency 4
```
