# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | small_1024_warm | 30 | 0.909 | 1.095 | 1.357 | 2.177 | 2.599 | 0.360 | 0.692 | 0.864 |
| rust_reqwest_ffi | concurrency_100 | 30 | 49.108 | 51.522 | 54.650 | 58.177 | 74.828 | 4.554 | unavailable | 1.872 |
| rust_reqwest_ffi | concurrency_250 | 30 | 145.365 | 152.836 | 176.486 | 195.581 | 207.379 | 15.068 | unavailable | 1.540 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 72.863 | 75.511 | 86.377 | 91.425 | 92.795 | 5.424 | unavailable | 1.266 |
| rust_reqwest_ffi | download_10485760_bytes | 30 | 740.545 | 751.003 | 759.332 | 767.279 | 774.543 | 7.710 | 1.509 | 13.302 |
| rust_reqwest_ffi | upload_10485760_bytes | 30 | 1320.961 | 1349.646 | 1379.515 | 1389.504 | 1452.236 | 25.756 | 1349.416 | 7.378 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 148.493 | 151.000 | 154.305 | 156.302 | 156.633 | 2.042 | 1.365 | 13.185 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
- `download_10485760_bytes`: only one candidate has measured samples.
- `upload_10485760_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes`: only one candidate has measured samples.
