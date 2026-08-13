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
| dart_io | concurrency_100 | 10 | 19.538 | 25.275 | 31.718 | 32.918 | 32.918 | 4.145 | unavailable | 3.872 |
| dart_io | concurrency_250 | 10 | 32.102 | 40.334 | 45.743 | 46.308 | 46.308 | 4.766 | unavailable | 6.238 |
| dart_io | download_104857600_bytes | 10 | 906.600 | 945.734 | 974.520 | 976.370 | 976.370 | 24.312 | 78.986 | 105.847 |
| dart_io | download_stream_to_dart_file_104857600_bytes | 10 | 2153.004 | 2177.247 | 2210.649 | 2212.797 | 2212.797 | 20.563 | 79.286 | 45.838 |
| dart_io | upload_104857600_bytes | 10 | 290.936 | 292.929 | 302.406 | 304.040 | 304.040 | 4.383 | 292.863 | 339.036 |
| dart_io | stream_2097152_bytes_slow_consumer | 10 | 150.631 | 157.507 | 161.238 | 161.403 | 161.403 | 2.913 | 31.995 | 12.670 |
| dart_io | stream_2097152_bytes_paused_consumer | 10 | 737.086 | 739.272 | 742.039 | 744.234 | 744.234 | 2.012 | 31.792 | 2.704 |
| libcurl_ffi | concurrency_100 | 10 | 23.387 | 27.687 | 36.418 | 37.539 | 37.539 | 4.830 | unavailable | 3.436 |
| libcurl_ffi | concurrency_250 | 10 | 39.501 | 45.961 | 49.460 | 50.705 | 50.705 | 3.212 | unavailable | 5.346 |
| libcurl_ffi | download_104857600_bytes | 10 | 947.122 | 971.730 | 1002.734 | 1021.126 | 1021.126 | 22.847 | 816.079 | 102.339 |
| libcurl_ffi | download_stream_to_dart_file_104857600_bytes | 10 | 2590.298 | 2653.186 | 2740.044 | 2804.898 | 2804.898 | 67.648 | 25.438 | 37.360 |
| libcurl_ffi | upload_104857600_bytes | 10 | 265.398 | 272.133 | 278.801 | 280.487 | 280.487 | 4.704 | 272.028 | 366.886 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 10 | 138.310 | 141.235 | 142.438 | 145.361 | 145.361 | 1.885 | 30.154 | 14.158 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 10 | 717.904 | 721.398 | 722.480 | 723.506 | 723.506 | 1.783 | 30.123 | 2.774 |
| rust_reqwest_ffi | concurrency_100 | 10 | 22.395 | 25.371 | 34.632 | 36.548 | 36.548 | 4.813 | unavailable | 3.623 |
| rust_reqwest_ffi | concurrency_250 | 10 | 41.648 | 43.544 | 47.809 | 48.541 | 48.541 | 2.270 | unavailable | 5.482 |
| rust_reqwest_ffi | download_104857600_bytes | 10 | 916.687 | 921.602 | 978.319 | 1031.793 | 1031.793 | 35.979 | 920.564 | 106.830 |
| rust_reqwest_ffi | download_stream_to_dart_file_104857600_bytes | 10 | 2601.820 | 2625.912 | 2684.371 | 2691.985 | 2691.985 | 30.179 | 30.020 | 37.894 |
| rust_reqwest_ffi | upload_104857600_bytes | 10 | 468.405 | 503.826 | 566.569 | 568.581 | 568.581 | 37.935 | 503.760 | 197.221 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 10 | 135.972 | 138.767 | 141.238 | 142.157 | 142.157 | 1.650 | 30.118 | 14.361 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 10 | 718.692 | 721.962 | 722.918 | 726.487 | 726.487 | 1.842 | 30.127 | 2.770 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `concurrency_100`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_250`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `download_stream_to_dart_file_104857600_bytes`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `upload_104857600_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_slow_consumer`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_paused_consumer`: approximately equivalent: p50 values differ by at most 5%.
