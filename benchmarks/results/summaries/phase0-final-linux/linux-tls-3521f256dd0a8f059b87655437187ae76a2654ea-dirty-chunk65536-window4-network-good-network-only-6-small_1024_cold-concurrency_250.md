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
| dart_io | small_1024_cold | 30 | 98.200 | 104.871 | 109.445 | 109.622 | 115.608 | 3.684 | 103.830 | 0.009 |
| dart_io | small_1024_warm | 30 | 32.982 | 35.747 | 37.344 | 38.495 | 41.289 | 1.651 | 34.970 | 0.027 |
| dart_io | concurrency_50 | 30 | 49.222 | 54.180 | 71.034 | 73.990 | 76.340 | 7.846 | unavailable | 0.863 |
| dart_io | concurrency_100 | 30 | 56.331 | 64.448 | 79.693 | 92.129 | 142.964 | 15.894 | unavailable | 1.448 |
| dart_io | concurrency_250 | 30 | 82.472 | 93.307 | 104.699 | 105.405 | 118.495 | 7.817 | unavailable | 2.576 |
| dart_io | connection_reuse_sequential | 30 | 3361.906 | 3426.877 | 3479.834 | 3506.297 | 3509.571 | 36.145 | unavailable | 0.028 |
| libcurl_ffi | small_1024_cold | 30 | 96.796 | 100.788 | 106.531 | 109.169 | 109.779 | 3.608 | 99.926 | 0.010 |
| libcurl_ffi | small_1024_warm | 30 | 32.574 | 34.167 | 35.440 | 35.763 | 37.083 | 1.032 | 33.162 | 0.029 |
| libcurl_ffi | concurrency_50 | 30 | 107.365 | 112.996 | 118.085 | 120.868 | 131.807 | 4.264 | unavailable | 0.429 |
| libcurl_ffi | concurrency_100 | 30 | 120.119 | 131.894 | 145.992 | 146.724 | 202.929 | 14.184 | unavailable | 0.730 |
| libcurl_ffi | concurrency_250 | 30 | 170.139 | 182.205 | 203.304 | 218.244 | 254.685 | 16.994 | unavailable | 1.317 |
| libcurl_ffi | connection_reuse_sequential | 30 | 3351.661 | 3411.659 | 3462.272 | 3471.770 | 3472.187 | 35.575 | unavailable | 0.029 |
| rust_reqwest_ffi | small_1024_cold | 30 | 97.218 | 103.760 | 107.172 | 109.433 | 111.001 | 3.123 | 102.783 | 0.009 |
| rust_reqwest_ffi | small_1024_warm | 30 | 32.152 | 35.009 | 37.478 | 38.536 | 39.638 | 1.723 | 34.326 | 0.028 |
| rust_reqwest_ffi | concurrency_50 | 30 | 40.816 | 46.445 | 58.216 | 68.640 | 71.660 | 7.973 | unavailable | 1.001 |
| rust_reqwest_ffi | concurrency_100 | 30 | 48.092 | 52.499 | 61.550 | 77.609 | 94.668 | 9.374 | unavailable | 1.785 |
| rust_reqwest_ffi | concurrency_250 | 30 | 73.718 | 81.725 | 96.672 | 117.437 | 119.319 | 10.914 | unavailable | 2.889 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 3298.491 | 3357.578 | 3449.750 | 3492.057 | 3814.498 | 91.922 | unavailable | 0.029 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: approximately equivalent: p50 values differ by at most 5%.
- `small_1024_warm`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_50`: likely difference: rust_reqwest_ffi is faster, but variance or overlap limits confidence.
- `concurrency_100`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_250`: likely difference: rust_reqwest_ffi is faster, but variance or overlap limits confidence.
- `connection_reuse_sequential`: approximately equivalent: p50 values differ by at most 5%.
