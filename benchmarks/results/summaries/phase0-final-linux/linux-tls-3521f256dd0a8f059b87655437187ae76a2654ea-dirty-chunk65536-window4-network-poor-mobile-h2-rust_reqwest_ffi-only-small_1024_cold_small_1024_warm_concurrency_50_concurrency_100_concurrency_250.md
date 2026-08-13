# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | small_1024_cold | 30 | 912.051 | 917.619 | 1292.967 | 1301.797 | 1519.859 | 152.224 | 914.636 | 0.001 |
| rust_reqwest_ffi | small_1024_warm | 30 | 304.541 | 305.780 | 309.576 | 693.823 | 845.084 | 117.230 | 303.910 | 0.003 |
| rust_reqwest_ffi | concurrency_50 | 30 | 961.084 | 1261.935 | 1932.218 | 2368.510 | 2450.481 | 376.856 | unavailable | 0.035 |
| rust_reqwest_ffi | concurrency_100 | 30 | 1270.762 | 2155.653 | 3919.936 | 4396.169 | 5053.730 | 919.843 | unavailable | 0.044 |
| rust_reqwest_ffi | concurrency_250 | 30 | 1905.937 | 4303.099 | 6500.994 | 6911.665 | 7426.670 | 1358.641 | unavailable | 0.061 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
