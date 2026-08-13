# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | small_1024_cold | 30 | 3.334 | 4.162 | 5.224 | 6.478 | 9.683 | 1.187 | 3.766 | 0.229 |
| rust_reqwest_ffi | small_1024_warm | 30 | 0.849 | 1.142 | 1.455 | 1.615 | 1.637 | 0.204 | 0.855 | 0.850 |
| rust_reqwest_ffi | concurrency_50 | 30 | 20.030 | 23.898 | 29.823 | 34.446 | 37.085 | 4.090 | unavailable | 1.983 |
| rust_reqwest_ffi | concurrency_100 | 30 | 37.330 | 43.013 | 48.880 | 56.984 | 57.860 | 5.056 | unavailable | 2.227 |
| rust_reqwest_ffi | concurrency_250 | 30 | 107.454 | 124.121 | 152.411 | 162.575 | 164.967 | 15.828 | unavailable | 1.928 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 73.706 | 81.233 | 98.733 | 110.488 | 121.480 | 10.680 | unavailable | 1.161 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
