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
| dart_io | stream_2097152_bytes | 5 | 210.137 | 210.468 | 210.926 | 210.926 | 210.926 | 0.275 | 34.399 | 9.502 |
| dart_io | stream_2097152_bytes_slow_consumer | 5 | 907.379 | 913.677 | 926.303 | 926.303 | 926.303 | 6.865 | 35.273 | 2.186 |
| dart_io | stream_2097152_bytes_paused_consumer | 5 | 6159.551 | 6186.295 | 6207.995 | 6207.995 | 6207.995 | 15.899 | 43.015 | 0.323 |
| libcurl_ffi | stream_2097152_bytes | 5 | 210.503 | 267.585 | 376.302 | 376.302 | 376.302 | 60.323 | 35.593 | 7.784 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 5 | 213.673 | 216.335 | 220.500 | 220.500 | 220.500 | 2.465 | 34.518 | 9.244 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 5 | 719.911 | 723.672 | 731.453 | 731.453 | 731.453 | 3.935 | 35.689 | 2.762 |
| rust_reqwest_ffi | stream_2097152_bytes | 5 | 209.730 | 210.971 | 212.332 | 212.332 | 212.332 | 0.966 | 33.681 | 9.473 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 5 | 213.238 | 213.726 | 214.893 | 214.893 | 214.893 | 0.685 | 33.201 | 9.345 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 5 | 713.849 | 715.639 | 719.024 | 719.024 | 719.024 | 1.729 | 34.121 | 2.794 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_slow_consumer`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_paused_consumer`: approximately equivalent: p50 values differ by at most 5%.
