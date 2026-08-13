# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | small_102400_warm | 10 | 9.521 | 9.835 | 11.234 | 12.418 | 12.418 | 0.888 | 5.411 | 9.481 |
| libcurl_ffi | concurrency_10 | 10 | 6.284 | 7.007 | 7.593 | 7.632 | 7.632 | 0.444 | unavailable | 1.385 |
| libcurl_ffi | concurrency_50 | 10 | 25.188 | 26.195 | 28.883 | 30.487 | 30.487 | 1.641 | unavailable | 1.825 |
| libcurl_ffi | concurrency_100 | 10 | 48.502 | 50.184 | 54.485 | 64.022 | 64.022 | 4.266 | unavailable | 1.887 |
| libcurl_ffi | concurrency_250 | 10 | 118.127 | 132.834 | 151.606 | 188.148 | 188.148 | 18.112 | unavailable | 1.766 |
| libcurl_ffi | connection_reuse_sequential | 10 | 78.799 | 82.880 | 86.225 | 86.339 | 86.339 | 2.344 | unavailable | 1.177 |
| libcurl_ffi | download_10485760_bytes | 10 | 751.303 | 772.873 | 803.583 | 824.413 | 824.413 | 19.878 | 6.509 | 12.829 |
| libcurl_ffi | download_104857600_bytes | 10 | 7580.691 | 7724.220 | 8110.860 | 8353.835 | 8353.835 | 234.814 | 15.216 | 12.828 |
| libcurl_ffi | upload_10485760_bytes | 10 | 1262.255 | 1287.127 | 1300.189 | 1414.232 | 1414.232 | 40.709 | 1287.021 | 7.715 |
| libcurl_ffi | upload_104857600_bytes | 10 | 12545.285 | 12869.978 | 12948.437 | 13114.305 | 13114.305 | 161.462 | 12869.867 | 7.799 |
| libcurl_ffi | stream_2097152_bytes | 10 | 153.951 | 155.077 | 159.963 | 159.965 | 159.965 | 2.072 | 5.855 | 12.820 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_102400_warm`: only one candidate has measured samples.
- `concurrency_10`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
- `download_10485760_bytes`: only one candidate has measured samples.
- `download_104857600_bytes`: only one candidate has measured samples.
- `upload_10485760_bytes`: only one candidate has measured samples.
- `upload_104857600_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes`: only one candidate has measured samples.
