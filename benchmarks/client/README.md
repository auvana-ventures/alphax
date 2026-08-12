# Benchmark Client Conventions

Candidate clients should accept the shared `--url`, `--requests`, and
`--concurrency` flags and emit one JSON document containing client identity,
scenario URL, status counts, bytes, elapsed samples or summary, and environment
metadata. Keep transport time separate from JSON/model parsing time.
