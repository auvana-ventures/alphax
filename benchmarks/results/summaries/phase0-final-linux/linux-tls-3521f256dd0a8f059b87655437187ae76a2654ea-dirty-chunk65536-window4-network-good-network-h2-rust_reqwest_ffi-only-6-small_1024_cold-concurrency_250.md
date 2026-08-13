# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | small_1024_cold | 30 | 97.510 | 100.283 | 104.141 | 108.819 | 114.403 | 3.608 | 99.284 | 0.010 |
| rust_reqwest_ffi | small_1024_warm | 30 | 32.584 | 34.272 | 36.977 | 37.141 | 39.347 | 1.595 | 33.396 | 0.028 |
| rust_reqwest_ffi | concurrency_50 | 30 | 47.940 | 65.940 | 80.278 | 98.363 | 111.494 | 15.903 | unavailable | 0.783 |
| rust_reqwest_ffi | concurrency_100 | 30 | 66.972 | 73.914 | 97.973 | 133.040 | 157.596 | 19.713 | unavailable | 1.227 |
| rust_reqwest_ffi | concurrency_250 | 30 | 133.532 | 153.993 | 190.476 | 221.252 | 262.776 | 27.028 | unavailable | 1.522 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 3284.231 | 3362.857 | 3539.955 | 3803.010 | 4006.928 | 150.418 | unavailable | 0.029 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
