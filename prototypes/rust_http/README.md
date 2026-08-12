# Rust HTTP Prototype

This candidate evaluates a Rust HTTP stack through reqwest/hyper. It includes both
a command-line benchmark client and a small C ABI entry point that can be loaded
from Dart FFI. It is a prototype only; it is not the selected production engine.

Build and test:

```text
cargo test --manifest-path prototypes/rust_http/Cargo.toml
cargo build --release --manifest-path prototypes/rust_http/Cargo.toml
```

Run the direct Rust benchmark:

```text
cargo run --manifest-path prototypes/rust_http/Cargo.toml -- \
  --url http://127.0.0.1:8080/bytes/1024 \
  --requests 10 \
  --concurrency 4
```

The dynamic library is `target/release/libalphax_rust_http.dylib` on macOS and
`target/release/libalphax_rust_http.so` on Linux. The Dart FFI prototype uses the
`ALPHAX_RUST_LIBRARY` environment variable to locate it.
