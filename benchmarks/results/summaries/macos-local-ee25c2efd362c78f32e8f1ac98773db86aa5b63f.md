# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| dart_io | true | 10 |  |
| libcurl_ffi | true | 10 |  |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | p50 (ms) | p95 (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| dart_io | small_1024_cold | 10 | 1.118 | 1.609 | 0.898 | 0.839 |
| dart_io | small_1024_warm | 10 | 0.474 | 0.965 | 0.378 | 1.818 |
| dart_io | small_10240_cold | 10 | 0.832 | 0.949 | 0.663 | 11.467 |
| dart_io | small_10240_warm | 10 | 0.607 | 0.683 | 0.408 | 16.075 |
| dart_io | small_102400_cold | 10 | 3.755 | 8.383 | 2.224 | 23.547 |
| dart_io | small_102400_warm | 10 | 3.458 | 5.158 | 1.867 | 25.169 |
| dart_io | concurrency_10 | 10 | 3.093 | 3.418 | unavailable | 3.167 |
| dart_io | concurrency_50 | 10 | 11.195 | 13.141 | unavailable | 4.481 |
| dart_io | concurrency_100 | 10 | 13.889 | 17.781 | unavailable | 7.164 |
| dart_io | concurrency_250 | 10 | 24.080 | 28.193 | unavailable | 9.991 |
| dart_io | download_10485760_bytes | 10 | 121.747 | 145.229 | 69.651 | 81.998 |
| dart_io | download_104857600_bytes | 10 | 909.548 | 1013.883 | 471.594 | 106.891 |
| dart_io | upload_10485760_bytes | 10 | 8.666 | 12.689 | 8.632 | 1099.116 |
| dart_io | upload_104857600_bytes | 10 | 72.172 | 98.770 | 72.120 | 1334.796 |
| dart_io | stream_2097152_bytes | 10 | 45.023 | 46.091 | 29.582 | 44.328 |
| dart_io | stream_2097152_bytes_slow_consumer | 10 | 156.326 | 162.214 | unavailable | 12.783 |
| dart_io | json_100000_bytes_network | 10 | 4.444 | 6.215 | 2.932 | 19.563 |
| dart_io | cancellation_waiting | 10 | 0.033 | 0.171 | unavailable | 0.000 |
| dart_io | cancellation_streaming | 10 | 8.960 | 10.975 | unavailable | 0.000 |
| dart_io | cancellation_download | 10 | 0.033 | 0.175 | unavailable | 0.000 |
| dart_io | cancellation_upload | 10 | 0.109 | 0.220 | unavailable | 0.000 |
| libcurl_ffi | small_1024_cold | 10 | 1.051 | 1.471 | 0.709 | 0.928 |
| libcurl_ffi | small_1024_warm | 10 | 0.559 | 0.668 | 0.414 | 1.793 |
| libcurl_ffi | small_10240_cold | 10 | 0.847 | 1.132 | 0.642 | 11.218 |
| libcurl_ffi | small_10240_warm | 10 | 0.637 | 1.072 | 0.436 | 14.179 |
| libcurl_ffi | small_102400_cold | 10 | 5.796 | 7.171 | 2.302 | 17.610 |
| libcurl_ffi | small_102400_warm | 10 | 6.231 | 7.978 | 2.244 | 16.585 |
| libcurl_ffi | concurrency_10 | 10 | 3.823 | 7.937 | unavailable | 2.490 |
| libcurl_ffi | concurrency_50 | 10 | 15.006 | 19.759 | unavailable | 3.117 |
| libcurl_ffi | concurrency_100 | 10 | 21.658 | 34.916 | unavailable | 4.293 |
| libcurl_ffi | concurrency_250 | 10 | 51.644 | 59.223 | unavailable | 4.714 |
| libcurl_ffi | download_10485760_bytes | 10 | 104.182 | 120.749 | 103.001 | 93.388 |
| libcurl_ffi | download_104857600_bytes | 10 | 1322.794 | 1658.408 | 712.033 | 76.160 |
| libcurl_ffi | upload_10485760_bytes | 10 | 1011.413 | 1013.084 | 1011.380 | 9.887 |
| libcurl_ffi | upload_104857600_bytes | 10 | 1073.081 | 1195.407 | 1073.051 | 91.971 |
| libcurl_ffi | stream_2097152_bytes | 10 | 43.482 | 58.736 | 31.951 | 44.304 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 10 | 476.536 | 483.069 | unavailable | 4.199 |
| libcurl_ffi | json_100000_bytes_network | 10 | 5.782 | 8.062 | 3.164 | 15.753 |
| libcurl_ffi | cancellation_waiting | 10 | 0.074 | 0.255 | unavailable | 0.000 |
| libcurl_ffi | cancellation_streaming | 10 | 1.176 | 6.727 | unavailable | 0.000 |
| libcurl_ffi | cancellation_download | 10 | 2.484 | 4.700 | unavailable | 0.000 |
| libcurl_ffi | cancellation_upload | 10 | 2.930 | 7.044 | unavailable | 0.000 |
| rust_reqwest_ffi | small_1024_cold | 10 | 0.680 | 1.000 | 0.556 | 1.285 |
| rust_reqwest_ffi | small_1024_warm | 10 | 0.491 | 0.587 | 0.376 | 1.943 |
| rust_reqwest_ffi | small_10240_cold | 10 | 0.836 | 1.465 | 0.610 | 10.960 |
| rust_reqwest_ffi | small_10240_warm | 10 | 0.618 | 0.895 | 0.428 | 14.785 |
| rust_reqwest_ffi | small_102400_cold | 10 | 5.929 | 8.466 | 2.235 | 15.968 |
| rust_reqwest_ffi | small_102400_warm | 10 | 6.026 | 7.933 | 2.418 | 16.484 |
| rust_reqwest_ffi | concurrency_10 | 10 | 2.652 | 3.143 | unavailable | 3.639 |
| rust_reqwest_ffi | concurrency_50 | 10 | 9.876 | 11.427 | unavailable | 5.034 |
| rust_reqwest_ffi | concurrency_100 | 10 | 14.505 | 20.506 | unavailable | 6.455 |
| rust_reqwest_ffi | concurrency_250 | 10 | 24.245 | 32.547 | unavailable | 9.269 |
| rust_reqwest_ffi | download_10485760_bytes | 10 | 94.422 | 97.887 | 94.382 | 105.764 |
| rust_reqwest_ffi | download_104857600_bytes | 10 | 768.988 | 1027.700 | 758.344 | 124.475 |
| rust_reqwest_ffi | upload_10485760_bytes | 10 | 46.981 | 53.951 | 46.966 | 210.425 |
| rust_reqwest_ffi | upload_104857600_bytes | 10 | 519.875 | 650.133 | 519.854 | 190.585 |
| rust_reqwest_ffi | stream_2097152_bytes | 10 | 59.267 | 70.102 | 29.861 | 33.301 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 10 | 269.982 | 276.842 | unavailable | 7.391 |
| rust_reqwest_ffi | json_100000_bytes_network | 10 | 6.613 | 10.824 | 2.895 | 15.026 |
| rust_reqwest_ffi | cancellation_waiting | 10 | 0.038 | 0.301 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_streaming | 10 | 2.030 | 4.868 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_download | 10 | 1.453 | 8.904 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_upload | 10 | 7.493 | 10.402 | unavailable | 0.000 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: rust_reqwest_ffi has the lowest observed p50; this is scenario-local, not an overall score.
- `small_1024_warm`: approximately equivalent by p50 (within 5% of the fastest observed candidate).
- `small_10240_cold`: approximately equivalent by p50 (within 5% of the fastest observed candidate).
- `small_10240_warm`: approximately equivalent by p50 (within 5% of the fastest observed candidate).
- `small_102400_cold`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `small_102400_warm`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `concurrency_10`: rust_reqwest_ffi has the lowest observed p50; this is scenario-local, not an overall score.
- `concurrency_50`: rust_reqwest_ffi has the lowest observed p50; this is scenario-local, not an overall score.
- `concurrency_100`: approximately equivalent by p50 (within 5% of the fastest observed candidate).
- `concurrency_250`: approximately equivalent by p50 (within 5% of the fastest observed candidate).
- `download_10485760_bytes`: rust_reqwest_ffi has the lowest observed p50; this is scenario-local, not an overall score.
- `download_104857600_bytes`: rust_reqwest_ffi has the lowest observed p50; this is scenario-local, not an overall score.
- `upload_10485760_bytes`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `upload_104857600_bytes`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `stream_2097152_bytes`: approximately equivalent by p50 (within 5% of the fastest observed candidate).
- `stream_2097152_bytes_slow_consumer`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `json_100000_bytes_network`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `cancellation_waiting`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `cancellation_streaming`: libcurl_ffi has the lowest observed p50; this is scenario-local, not an overall score.
- `cancellation_download`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
- `cancellation_upload`: dart_io has the lowest observed p50; this is scenario-local, not an overall score.
