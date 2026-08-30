# Protobuf interoperability recipe

This is the bounded Task G validation. Protobuf remains a serialization format
owned by the application; AlphaX does not add a Protobuf runtime, transport,
generator, or `alphax_protobuf` package.

The maintained `protobuf`/`protoc_plugin` flow is:

```text
GeneratedMessage
  → writeToBuffer()
  → AlphaXBody.bytes
  → AlphaXClient

AlphaX response bytes
  → mergeFromBuffer()/fromBuffer()
  → GeneratedMessage
```

The fixture compiles a small `.proto` message with `protoc_plugin`, sends it as
an `application/x-protobuf` byte body, and decodes the response with the
generated message class. The same generic request/response hooks are available
to `alphax_generator`; no Protobuf-specific annotation is needed.

## Reproduce

Install `protoc` separately and make `protoc-gen-dart` available, or set its
path explicitly:

```sh
dart pub get
protoc --dart_out=lib proto/fixture.proto \
  --plugin=protoc-gen-dart=tool/protoc-gen-dart.sh
dart format lib/proto/fixture.pb.dart
dart analyze --fatal-infos
dart test
```

`protoc` and `protoc_plugin` 25.x are tooling; `protobuf` 6.x is the example's
runtime dependency because the generated message imports it. Neither enters
AlphaX's runtime packages.

## Protocol boundary

This validates Protobuf serialization only. It does not imply gRPC support.
gRPC is an RPC protocol/runtime with HTTP/2 framing, metadata, trailers,
streaming, and status semantics, and remains `POST_1_0`.
