# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | small_1024_cold | 30 | 5.530 | 7.108 | 9.377 | 10.886 | 24.962 | 3.401 | 6.379 | 0.131 |
| libcurl_ffi | small_1024_warm | 30 | 1.123 | 2.011 | 2.970 | 3.426 | 5.723 | 0.871 | 1.509 | 0.495 |
| libcurl_ffi | concurrency_50 | 30 | 21.438 | 27.143 | 35.941 | 37.715 | 45.045 | 5.257 | unavailable | 1.733 |
| libcurl_ffi | concurrency_100 | 30 | 35.150 | 41.161 | 51.902 | 55.295 | 79.623 | 8.648 | unavailable | 2.289 |
| libcurl_ffi | concurrency_250 | 30 | 93.530 | 120.313 | 147.096 | 164.488 | 218.041 | 24.583 | unavailable | 2.011 |
| libcurl_ffi | connection_reuse_sequential | 30 | 70.566 | 103.340 | 133.136 | 149.416 | 170.924 | 24.637 | unavailable | 0.995 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
