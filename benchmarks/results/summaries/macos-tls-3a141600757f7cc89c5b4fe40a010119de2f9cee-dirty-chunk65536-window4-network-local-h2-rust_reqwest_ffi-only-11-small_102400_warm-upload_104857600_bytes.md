# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | small_102400_warm | 10 | 9.368 | 10.151 | 10.646 | 12.413 | 12.413 | 0.830 | 1.109 | 9.575 |
| rust_reqwest_ffi | concurrency_10 | 10 | 5.853 | 6.172 | 6.947 | 8.017 | 8.017 | 0.639 | unavailable | 1.514 |
| rust_reqwest_ffi | concurrency_50 | 10 | 23.885 | 24.620 | 25.743 | 25.977 | 25.977 | 0.651 | unavailable | 1.967 |
| rust_reqwest_ffi | concurrency_100 | 10 | 49.125 | 60.295 | 66.456 | 67.994 | 67.994 | 5.130 | unavailable | 1.624 |
| rust_reqwest_ffi | concurrency_250 | 10 | 140.438 | 152.572 | 157.888 | 172.550 | 172.550 | 7.992 | unavailable | 1.593 |
| rust_reqwest_ffi | connection_reuse_sequential | 10 | 76.518 | 77.673 | 81.792 | 83.704 | 83.704 | 2.490 | unavailable | 1.236 |
| rust_reqwest_ffi | download_10485760_bytes | 10 | 761.851 | 771.835 | 795.235 | 809.551 | 809.551 | 14.047 | 1.505 | 12.832 |
| rust_reqwest_ffi | download_104857600_bytes | 10 | 7663.269 | 7703.530 | 7784.488 | 7812.945 | 7812.945 | 48.518 | 3.111 | 12.954 |
| rust_reqwest_ffi | upload_10485760_bytes | 10 | 1347.918 | 1365.627 | 1387.532 | 1390.590 | 1390.590 | 14.965 | 1365.475 | 7.292 |
| rust_reqwest_ffi | upload_104857600_bytes | 10 | 13385.540 | 13810.345 | 14008.720 | 14071.137 | 14071.137 | 196.783 | 13810.051 | 7.256 |
| rust_reqwest_ffi | stream_2097152_bytes | 10 | 153.985 | 155.532 | 157.962 | 158.212 | 158.212 | 1.501 | 1.423 | 12.802 |

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
