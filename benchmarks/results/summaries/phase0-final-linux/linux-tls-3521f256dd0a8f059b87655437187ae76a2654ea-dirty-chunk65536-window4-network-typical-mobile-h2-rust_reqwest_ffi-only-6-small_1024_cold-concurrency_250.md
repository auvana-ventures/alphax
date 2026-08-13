# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | small_1024_cold | 30 | 310.670 | 315.823 | 317.693 | 317.781 | 322.652 | 2.326 | 314.585 | 0.003 |
| rust_reqwest_ffi | small_1024_warm | 30 | 103.673 | 105.060 | 107.607 | 108.725 | 237.837 | 23.811 | 103.784 | 0.009 |
| rust_reqwest_ffi | concurrency_50 | 30 | 323.870 | 417.380 | 432.318 | 511.305 | 519.404 | 54.211 | unavailable | 0.126 |
| rust_reqwest_ffi | concurrency_100 | 30 | 447.765 | 546.199 | 643.317 | 646.766 | 732.866 | 65.469 | unavailable | 0.171 |
| rust_reqwest_ffi | concurrency_250 | 30 | 779.449 | 985.518 | 1381.603 | 1479.835 | 1643.304 | 219.554 | unavailable | 0.232 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 10434.491 | 10903.996 | 11478.894 | 11811.377 | 12236.769 | 421.056 | unavailable | 0.009 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
