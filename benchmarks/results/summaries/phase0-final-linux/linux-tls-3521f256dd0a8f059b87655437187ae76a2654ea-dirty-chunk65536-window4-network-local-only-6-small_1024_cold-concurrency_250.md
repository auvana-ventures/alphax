# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| dart_io | true | 10 |  |
| libcurl_ffi | true | 10 |  |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dart_io | small_1024_cold | 30 | 3.762 | 4.967 | 6.309 | 7.390 | 7.607 | 0.974 | 4.633 | 0.197 |
| dart_io | small_1024_warm | 30 | 1.206 | 1.718 | 2.205 | 2.673 | 3.041 | 0.417 | 1.469 | 0.568 |
| dart_io | concurrency_50 | 30 | 17.357 | 23.229 | 32.469 | 34.054 | 35.889 | 5.135 | unavailable | 2.068 |
| dart_io | concurrency_100 | 30 | 25.484 | 31.061 | 39.864 | 44.232 | 68.184 | 7.856 | unavailable | 3.003 |
| dart_io | concurrency_250 | 30 | 52.933 | 61.843 | 80.204 | 102.361 | 110.060 | 13.708 | unavailable | 3.802 |
| dart_io | connection_reuse_sequential | 30 | 75.372 | 86.804 | 119.981 | 179.240 | 184.101 | 27.189 | unavailable | 1.040 |
| libcurl_ffi | small_1024_cold | 30 | 3.001 | 3.448 | 4.048 | 4.253 | 5.668 | 0.515 | 3.085 | 0.279 |
| libcurl_ffi | small_1024_warm | 30 | 0.878 | 1.107 | 1.808 | 1.990 | 3.266 | 0.482 | 0.787 | 0.828 |
| libcurl_ffi | concurrency_50 | 30 | 10.094 | 19.773 | 26.674 | 30.923 | 36.033 | 5.826 | unavailable | 2.614 |
| libcurl_ffi | concurrency_100 | 30 | 22.247 | 52.699 | 73.613 | 84.646 | 90.117 | 16.799 | unavailable | 2.091 |
| libcurl_ffi | concurrency_250 | 30 | 110.507 | 134.947 | 171.543 | 237.479 | 241.088 | 31.562 | unavailable | 1.806 |
| libcurl_ffi | connection_reuse_sequential | 30 | 58.031 | 66.201 | 129.514 | 196.063 | 263.278 | 46.002 | unavailable | 1.277 |
| rust_reqwest_ffi | small_1024_cold | 30 | 2.628 | 3.135 | 3.527 | 3.909 | 7.783 | 0.901 | 2.756 | 0.312 |
| rust_reqwest_ffi | small_1024_warm | 30 | 0.844 | 1.071 | 1.388 | 1.495 | 1.627 | 0.193 | 0.800 | 0.911 |
| rust_reqwest_ffi | concurrency_50 | 30 | 10.290 | 13.211 | 22.724 | 25.620 | 30.725 | 5.205 | unavailable | 3.279 |
| rust_reqwest_ffi | concurrency_100 | 30 | 18.311 | 22.095 | 27.523 | 31.520 | 31.766 | 3.614 | unavailable | 4.332 |
| rust_reqwest_ffi | concurrency_250 | 30 | 40.741 | 49.567 | 68.147 | 84.459 | 100.049 | 13.377 | unavailable | 4.669 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 69.596 | 76.853 | 92.282 | 122.778 | 145.839 | 15.965 | unavailable | 1.228 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `small_1024_warm`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_50`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_100`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_250`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `connection_reuse_sequential`: inconclusive: the observed separation is not stable enough for a stronger claim.
