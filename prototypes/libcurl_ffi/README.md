# libcurl FFI Prototype

This candidate uses libcurl's multi interface behind a small C ABI bridge. The C
layer is not a commitment to a C++ AlphaX engine; it is the thinnest practical
boundary for evaluating libcurl from Dart FFI. It exposes request timings and
experimental direct download/upload entry points.

Build and test:

```text
make -C prototypes/libcurl_ffi test
cd prototypes/libcurl_ffi && \
  ALPHAX_CURL_LIBRARY="$PWD/libalphax_curl.dylib" dart test
```

Run the Dart FFI smoke benchmark after building the shared library:

```text
ALPHAX_CURL_LIBRARY=prototypes/libcurl_ffi/libalphax_curl.dylib \
  dart run prototypes/libcurl_ffi/bin/benchmark.dart \
  --url http://127.0.0.1:8080/bytes/1024
```

Use `libalphax_curl.so` on Linux. The build requires `curl-config` and libcurl
development headers.
