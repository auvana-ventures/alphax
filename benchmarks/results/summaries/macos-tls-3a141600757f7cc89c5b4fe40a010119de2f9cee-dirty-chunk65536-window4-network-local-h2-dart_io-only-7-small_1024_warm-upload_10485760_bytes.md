# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| dart_io | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dart_io | small_1024_warm | 30 | 0.966 | 1.562 | 2.067 | 2.272 | 2.413 | 0.372 | 1.299 | 0.660 |
| dart_io | concurrency_100 | 30 | 35.191 | 38.773 | 45.203 | 46.017 | 46.951 | 3.330 | unavailable | 2.481 |
| dart_io | concurrency_250 | 30 | 72.493 | 91.788 | 97.581 | 110.397 | 110.467 | 8.506 | unavailable | 2.667 |
| dart_io | connection_reuse_sequential | 30 | 64.305 | 73.439 | 262.436 | 378.938 | 790.443 | 142.610 | unavailable | 1.110 |
| dart_io | download_10485760_bytes | 30 | 686.614 | 695.409 | 780.598 | 1009.283 | 1561.092 | 165.774 | 1.613 | 13.729 |
| dart_io | upload_10485760_bytes | 30 | 1206.753 | 1219.341 | 1238.579 | 1265.565 | 1286.486 | 16.475 | 1219.274 | 8.160 |
| dart_io | stream_2097152_bytes | 30 | 138.230 | 139.143 | 184.647 | 185.576 | 187.004 | 15.774 | 1.395 | 13.880 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
- `download_10485760_bytes`: only one candidate has measured samples.
- `upload_10485760_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes`: only one candidate has measured samples.
