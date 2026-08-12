# Benchmark Client Contract

`alphax_benchmark_client` is a private, benchmark-only package. It deliberately
does not extend or replace the public `alphax` API.

Every candidate implements `BenchmarkTransport` with equivalent operations:

- buffered GET bytes;
- GET streaming events;
- byte POST;
- file upload;
- file download;
- cancellation/timeout options;
- close/dispose.

Candidate clients should accept the shared `--url`, `--requests`, and
`--concurrency` flags and emit one JSON document containing client identity,
scenario URL, status counts, bytes, elapsed samples or summary, and environment
metadata. Keep transport time separate from JSON/model parsing time.
