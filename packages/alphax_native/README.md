# alphax_native

Platform transport integration boundary for AlphaX.

This package remains a skeleton during Phase 1A. It must not leak Cronet,
URLSession, FFI, C++, libcurl, or Rust types into `alphax`; platform adapter work
starts only after the reviewed Phase 1A contract.
