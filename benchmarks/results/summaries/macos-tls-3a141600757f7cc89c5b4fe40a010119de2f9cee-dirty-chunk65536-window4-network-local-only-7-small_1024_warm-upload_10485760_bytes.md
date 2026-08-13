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
| dart_io | small_1024_warm | 30 | 0.893 | 1.011 | 1.268 | 1.479 | 2.769 | 0.333 | 0.864 | 0.923 |
| dart_io | concurrency_100 | 30 | 19.227 | 23.591 | 31.525 | 33.529 | 35.010 | 4.443 | unavailable | 4.107 |
| dart_io | concurrency_250 | 30 | 36.548 | 38.716 | 43.433 | 46.310 | 46.354 | 2.720 | unavailable | 6.180 |
| dart_io | connection_reuse_sequential | 30 | 26.635 | 28.794 | 30.986 | 33.788 | 36.287 | 2.066 | unavailable | 3.371 |
| dart_io | download_10485760_bytes | 30 | 140.525 | 147.227 | 180.496 | 190.180 | 213.880 | 16.736 | 1.123 | 65.964 |
| dart_io | upload_10485760_bytes | 30 | 75.741 | 77.570 | 83.367 | 84.185 | 85.717 | 2.955 | 77.519 | 126.424 |
| dart_io | stream_2097152_bytes | 30 | 36.474 | 37.877 | 40.065 | 40.470 | 42.417 | 1.408 | 1.461 | 52.387 |
| libcurl_ffi | small_1024_warm | 30 | 0.563 | 0.727 | 1.067 | 1.146 | 1.175 | 0.176 | 0.490 | 1.268 |
| libcurl_ffi | concurrency_100 | 30 | 11.813 | 14.829 | 21.533 | 24.236 | 24.577 | 3.357 | unavailable | 6.378 |
| libcurl_ffi | concurrency_250 | 30 | 27.917 | 70.387 | 77.044 | 77.916 | 88.096 | 10.491 | unavailable | 3.727 |
| libcurl_ffi | connection_reuse_sequential | 30 | 24.970 | 26.070 | 27.878 | 29.048 | 29.131 | 1.083 | unavailable | 3.687 |
| libcurl_ffi | download_10485760_bytes | 30 | 144.148 | 149.591 | 171.437 | 178.684 | 178.869 | 9.801 | 1.317 | 65.235 |
| libcurl_ffi | upload_10485760_bytes | 30 | 87.304 | 91.880 | 98.585 | 105.714 | 110.842 | 5.042 | 91.800 | 107.167 |
| libcurl_ffi | stream_2097152_bytes | 30 | 41.489 | 44.216 | 48.470 | 49.070 | 49.451 | 2.048 | 1.253 | 44.624 |
| rust_reqwest_ffi | small_1024_warm | 30 | 0.453 | 0.603 | 0.755 | 0.851 | 0.888 | 0.116 | 0.378 | 1.643 |
| rust_reqwest_ffi | concurrency_100 | 30 | 12.282 | 14.913 | 19.309 | 19.388 | 21.204 | 2.383 | unavailable | 6.541 |
| rust_reqwest_ffi | concurrency_250 | 30 | 28.104 | 33.264 | 40.114 | 50.604 | 57.122 | 5.971 | unavailable | 7.165 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 24.994 | 26.348 | 28.268 | 28.600 | 31.853 | 1.272 | unavailable | 3.649 |
| rust_reqwest_ffi | download_10485760_bytes | 30 | 139.061 | 145.511 | 154.930 | 169.459 | 179.339 | 8.284 | 1.003 | 67.578 |
| rust_reqwest_ffi | upload_10485760_bytes | 30 | 83.198 | 92.295 | 124.441 | 137.839 | 144.418 | 16.729 | 92.204 | 103.647 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 33.717 | 42.992 | 47.083 | 49.865 | 57.979 | 5.046 | 1.339 | 47.692 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_warm`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_100`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_250`: likely difference: rust_reqwest_ffi is faster, but variance or overlap limits confidence.
- `connection_reuse_sequential`: approximately equivalent: p50 values differ by at most 5%.
- `download_10485760_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `upload_10485760_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
