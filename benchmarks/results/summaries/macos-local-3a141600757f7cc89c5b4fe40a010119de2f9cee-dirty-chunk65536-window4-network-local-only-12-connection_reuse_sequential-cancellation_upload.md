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
| dart_io | concurrency_100 | 30 | 14.196 | 18.885 | 25.387 | 27.800 | 30.146 | 3.884 | unavailable | 5.067 |
| dart_io | concurrency_250 | 30 | 27.882 | 30.720 | 35.174 | 37.292 | 40.219 | 2.768 | unavailable | 7.829 |
| dart_io | connection_reuse_sequential | 30 | 11.795 | 12.861 | 13.849 | 15.927 | 17.315 | 1.146 | unavailable | 7.405 |
| dart_io | download_104857600_bytes | 30 | 863.136 | 896.946 | 973.917 | 980.743 | 992.901 | 37.629 | 77.686 | 109.041 |
| dart_io | download_stream_to_dart_file_104857600_bytes | 30 | 2139.127 | 2163.181 | 2192.121 | 2197.810 | 2227.445 | 21.693 | 75.623 | 46.126 |
| dart_io | upload_104857600_bytes | 30 | 285.386 | 289.435 | 293.687 | 297.447 | 309.510 | 4.480 | 289.400 | 343.710 |
| dart_io | stream_2097152_bytes | 30 | 46.143 | 48.512 | 50.978 | 51.492 | 52.767 | 1.549 | 30.476 | 40.913 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 149.241 | 156.243 | 158.618 | 159.779 | 162.576 | 2.658 | 31.506 | 12.813 |
| dart_io | stream_2097152_bytes_paused_consumer | 30 | 724.344 | 735.484 | 743.122 | 746.918 | 748.324 | 5.546 | 30.083 | 2.718 |
| dart_io | cancellation_waiting | 30 | 0.026 | 0.034 | 0.058 | 0.066 | 0.412 | 0.068 | unavailable | 0.000 |
| dart_io | cancellation_streaming | 30 | 6.550 | 10.192 | 16.857 | 17.724 | 20.779 | 3.559 | unavailable | 0.000 |
| dart_io | cancellation_streaming_paused | 30 | 56.882 | 60.196 | 77.931 | 79.690 | 81.625 | 8.666 | unavailable | 0.000 |
| dart_io | cancellation_download | 30 | 0.011 | 0.035 | 0.061 | 0.076 | 0.164 | 0.028 | unavailable | 0.000 |
| dart_io | cancellation_upload | 30 | 0.069 | 0.099 | 0.139 | 0.157 | 0.243 | 0.032 | unavailable | 0.000 |
| libcurl_ffi | concurrency_100 | 30 | 16.912 | 21.170 | 26.752 | 31.053 | 37.486 | 4.357 | unavailable | 4.467 |
| libcurl_ffi | concurrency_250 | 30 | 32.214 | 37.729 | 42.483 | 45.545 | 47.328 | 3.594 | unavailable | 6.444 |
| libcurl_ffi | connection_reuse_sequential | 30 | 18.747 | 19.316 | 19.963 | 21.114 | 21.528 | 0.610 | unavailable | 5.016 |
| libcurl_ffi | download_104857600_bytes | 30 | 945.615 | 964.254 | 979.599 | 1023.910 | 1024.046 | 19.000 | 961.834 | 103.360 |
| libcurl_ffi | download_stream_to_dart_file_104857600_bytes | 30 | 2643.323 | 2689.117 | 2737.255 | 2748.176 | 2772.103 | 30.395 | 42.582 | 37.141 |
| libcurl_ffi | upload_104857600_bytes | 30 | 251.191 | 272.314 | 278.711 | 279.256 | 279.867 | 8.164 | 272.241 | 371.439 |
| libcurl_ffi | stream_2097152_bytes | 30 | 54.863 | 59.790 | 62.103 | 62.481 | 63.277 | 1.923 | 29.572 | 33.358 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 138.027 | 141.114 | 143.643 | 149.258 | 157.260 | 3.559 | 31.202 | 14.115 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 30 | 714.194 | 722.448 | 726.252 | 727.434 | 727.601 | 3.811 | 30.920 | 2.771 |
| libcurl_ffi | cancellation_waiting | 30 | 0.010 | 0.012 | 0.024 | 0.027 | 0.148 | 0.024 | unavailable | 0.000 |
| libcurl_ffi | cancellation_streaming | 30 | 1.391 | 5.259 | 13.532 | 18.014 | 18.344 | 5.048 | unavailable | 0.000 |
| libcurl_ffi | cancellation_streaming_paused | 30 | 61.161 | 63.511 | 86.465 | 87.622 | 88.640 | 10.775 | unavailable | 0.000 |
| libcurl_ffi | cancellation_download | 30 | 0.107 | 0.939 | 2.557 | 4.392 | 4.615 | 1.244 | unavailable | 0.000 |
| libcurl_ffi | cancellation_upload | 30 | 1.023 | 5.635 | 9.512 | 10.535 | 10.787 | 2.854 | unavailable | 0.000 |
| rust_reqwest_ffi | concurrency_100 | 30 | 15.899 | 20.128 | 27.216 | 30.071 | 36.319 | 4.614 | unavailable | 4.766 |
| rust_reqwest_ffi | concurrency_250 | 30 | 34.976 | 40.401 | 44.156 | 44.861 | 45.021 | 2.543 | unavailable | 6.052 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 19.932 | 20.964 | 22.108 | 22.270 | 23.019 | 0.730 | unavailable | 4.648 |
| rust_reqwest_ffi | download_104857600_bytes | 30 | 904.519 | 921.626 | 981.022 | 1006.017 | 1038.321 | 31.863 | 917.575 | 106.964 |
| rust_reqwest_ffi | download_stream_to_dart_file_104857600_bytes | 30 | 2595.690 | 2632.687 | 2689.916 | 2713.198 | 2718.601 | 30.281 | 24.838 | 37.850 |
| rust_reqwest_ffi | upload_104857600_bytes | 30 | 443.311 | 456.761 | 558.773 | 563.822 | 570.998 | 43.469 | 456.704 | 208.554 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 55.509 | 59.221 | 61.661 | 62.476 | 63.271 | 1.729 | 29.465 | 33.717 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 138.085 | 141.405 | 143.756 | 145.658 | 148.732 | 2.397 | 31.233 | 14.147 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 30 | 709.293 | 721.788 | 726.414 | 727.366 | 727.670 | 5.533 | 31.010 | 2.777 |
| rust_reqwest_ffi | cancellation_waiting | 30 | 0.011 | 0.013 | 0.027 | 0.031 | 0.162 | 0.027 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_streaming | 30 | 1.413 | 6.662 | 13.145 | 18.203 | 19.386 | 5.238 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_streaming_paused | 30 | 62.357 | 64.279 | 83.610 | 85.267 | 89.217 | 9.494 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_download | 30 | 0.115 | 0.896 | 4.432 | 7.177 | 7.719 | 1.915 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_upload | 30 | 6.810 | 11.481 | 15.193 | 16.684 | 22.185 | 3.352 | unavailable | 0.000 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `concurrency_100`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_250`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `connection_reuse_sequential`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `download_stream_to_dart_file_104857600_bytes`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `upload_104857600_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `stream_2097152_bytes_slow_consumer`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_paused_consumer`: approximately equivalent: p50 values differ by at most 5%.
- `cancellation_waiting`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_streaming`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_streaming_paused`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_download`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_upload`: inconclusive: the observed separation is not stable enough for a stronger claim.
