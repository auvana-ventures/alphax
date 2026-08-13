# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | small_1024_cold | 30 | 96.571 | 101.673 | 104.023 | 104.177 | 105.834 | 2.171 | 100.608 | 0.010 |
| libcurl_ffi | small_1024_warm | 30 | 31.949 | 32.552 | 33.500 | 33.756 | 33.938 | 0.537 | 31.891 | 0.030 |
| libcurl_ffi | concurrency_50 | 30 | 51.815 | 61.463 | 66.479 | 68.274 | 70.866 | 4.993 | unavailable | 0.803 |
| libcurl_ffi | concurrency_100 | 30 | 68.797 | 74.592 | 86.115 | 90.301 | 90.401 | 5.802 | unavailable | 1.281 |
| libcurl_ffi | concurrency_250 | 30 | 122.043 | 137.518 | 150.873 | 156.964 | 167.049 | 9.752 | unavailable | 1.761 |
| libcurl_ffi | connection_reuse_sequential | 30 | 3225.044 | 3308.474 | 3338.971 | 3366.814 | 3399.591 | 35.455 | unavailable | 0.030 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
