# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | small_1024_warm | 30 | 0.966 | 1.203 | 1.433 | 1.483 | 1.715 | 0.169 | 0.973 | 0.821 |
| libcurl_ffi | concurrency_100 | 30 | 44.599 | 51.675 | 58.066 | 64.383 | 68.407 | 5.028 | unavailable | 1.875 |
| libcurl_ffi | concurrency_250 | 30 | 124.910 | 136.584 | 149.716 | 159.007 | 165.678 | 9.754 | unavailable | 1.775 |
| libcurl_ffi | connection_reuse_sequential | 30 | 75.135 | 77.868 | 98.523 | 103.217 | 107.355 | 9.173 | unavailable | 1.190 |
| libcurl_ffi | download_10485760_bytes | 30 | 742.024 | 750.775 | 784.011 | 785.416 | 796.955 | 14.237 | 6.202 | 13.259 |
| libcurl_ffi | upload_10485760_bytes | 30 | 1247.398 | 1282.631 | 1377.588 | 1414.331 | 1433.856 | 48.281 | 1282.475 | 7.713 |
| libcurl_ffi | stream_2097152_bytes | 30 | 147.698 | 152.956 | 160.225 | 163.891 | 171.519 | 4.665 | 5.830 | 12.953 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
- `download_10485760_bytes`: only one candidate has measured samples.
- `upload_10485760_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes`: only one candidate has measured samples.
