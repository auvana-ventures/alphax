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
| dart_io | small_1024_warm | 30 | 0.439 | 0.768 | 1.511 | 1.757 | 2.209 | 0.470 | 0.525 | 1.289 |
| dart_io | concurrency_100 | 30 | 17.163 | 20.438 | 28.431 | 29.130 | 31.126 | 3.850 | unavailable | 4.567 |
| dart_io | concurrency_250 | 30 | 28.333 | 35.163 | 41.570 | 43.360 | 43.463 | 3.856 | unavailable | 6.849 |
| dart_io | download_104857600_bytes | 30 | 979.422 | 1144.790 | 1517.812 | 1630.089 | 1672.014 | 189.954 | 567.808 | 85.543 |
| dart_io | upload_10485760_bytes | 30 | 33.786 | 35.916 | 41.137 | 42.505 | 53.436 | 3.938 | 35.875 | 269.082 |
| dart_io | upload_104857600_bytes | 30 | 301.405 | 306.986 | 325.904 | 337.401 | 350.136 | 11.336 | 306.946 | 321.366 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 160.822 | 167.353 | 176.528 | 182.516 | 190.124 | 6.256 | unavailable | 11.778 |
| libcurl_ffi | small_1024_warm | 30 | 0.876 | 1.452 | 2.012 | 2.471 | 2.911 | 0.459 | 1.098 | 0.696 |
| libcurl_ffi | concurrency_100 | 30 | 35.927 | 56.782 | 83.404 | 87.835 | 97.002 | 15.626 | unavailable | 1.748 |
| libcurl_ffi | concurrency_250 | 30 | 77.267 | 125.501 | 190.286 | 221.344 | 237.208 | 38.693 | unavailable | 1.871 |
| libcurl_ffi | download_104857600_bytes | 30 | 1434.645 | 1978.979 | 2928.074 | 3251.808 | 4838.520 | 714.362 | 1433.341 | 49.986 |
| libcurl_ffi | upload_10485760_bytes | 30 | 41.139 | 55.498 | 101.798 | 123.315 | 203.402 | 32.441 | 55.421 | 168.495 |
| libcurl_ffi | upload_104857600_bytes | 30 | 509.814 | 594.811 | 741.149 | 1170.267 | 1295.451 | 173.057 | 594.701 | 161.547 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 626.055 | 829.731 | 1297.181 | 1355.407 | 1533.615 | 240.714 | unavailable | 2.260 |
| rust_reqwest_ffi | small_1024_warm | 30 | 1.274 | 3.123 | 9.646 | 12.041 | 41.619 | 7.314 | 2.598 | 0.347 |
| rust_reqwest_ffi | concurrency_100 | 30 | 26.551 | 37.114 | 52.824 | 61.812 | 62.040 | 9.792 | unavailable | 2.600 |
| rust_reqwest_ffi | concurrency_250 | 30 | 45.514 | 57.688 | 84.330 | 114.760 | 119.333 | 18.917 | unavailable | 4.006 |
| rust_reqwest_ffi | download_104857600_bytes | 30 | 1265.250 | 1493.052 | 1894.140 | 1959.329 | 2507.090 | 257.839 | 1440.143 | 65.914 |
| rust_reqwest_ffi | upload_10485760_bytes | 30 | 42.081 | 68.848 | 91.737 | 92.993 | 95.294 | 11.366 | 68.750 | 142.473 |
| rust_reqwest_ffi | upload_104857600_bytes | 30 | 643.029 | 770.110 | 1071.175 | 1222.057 | 1440.596 | 180.304 | 770.027 | 125.093 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 159.417 | 266.060 | 291.575 | 304.515 | 332.796 | 57.243 | unavailable | 9.097 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_warm`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_100`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_250`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `download_104857600_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `upload_10485760_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `upload_104857600_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_slow_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
