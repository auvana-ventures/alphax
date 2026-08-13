# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | small_1024_cold | 30 | 917.654 | 922.294 | 1224.654 | 2116.072 | 2341.003 | 360.945 | 920.857 | 0.001 |
| libcurl_ffi | small_1024_warm | 30 | 304.369 | 305.949 | 308.231 | 1172.012 | 1201.113 | 261.269 | 304.893 | 0.003 |
| libcurl_ffi | concurrency_50 | 30 | 1251.770 | 1838.236 | 2193.850 | 3053.908 | 3639.413 | 508.719 | unavailable | 0.028 |
| libcurl_ffi | concurrency_100 | 30 | 1316.688 | 1854.565 | 3389.139 | 4641.243 | 6864.927 | 1143.781 | unavailable | 0.048 |
| libcurl_ffi | concurrency_250 | 30 | 1437.028 | 3182.375 | 3845.594 | 5314.328 | 7448.972 | 1169.422 | unavailable | 0.085 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
