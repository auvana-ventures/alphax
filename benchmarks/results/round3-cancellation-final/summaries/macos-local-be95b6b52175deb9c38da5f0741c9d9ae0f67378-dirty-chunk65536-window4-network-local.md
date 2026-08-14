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
| dart_io | cancellation_waiting | 30 | 0.155 | 0.364 | 0.756 | 1.663 | 3.540 | 0.633 | unavailable | 0.000 |
| dart_io | cancellation_streaming | 30 | 9.344 | 63.819 | 110.438 | 112.419 | 164.072 | 38.281 | unavailable | 0.000 |
| dart_io | cancellation_streaming_paused | 30 | 61.510 | 93.658 | 187.314 | 188.769 | 204.755 | 48.518 | unavailable | 0.000 |
| dart_io | cancellation_download | 30 | 0.040 | 0.095 | 0.238 | 1.052 | 1.677 | 0.328 | unavailable | 0.000 |
| dart_io | cancellation_upload | 30 | 0.125 | 0.193 | 0.334 | 0.353 | 0.368 | 0.067 | unavailable | 0.000 |
| libcurl_ffi | cancellation_waiting | 30 | 0.063 | 0.082 | 0.130 | 0.257 | 0.560 | 0.092 | unavailable | 0.000 |
| libcurl_ffi | cancellation_streaming | 30 | 4.519 | 81.943 | 145.892 | 150.965 | 212.479 | 52.032 | unavailable | 0.000 |
| libcurl_ffi | cancellation_streaming_paused | 30 | 82.766 | 97.511 | 230.364 | 300.289 | 337.148 | 67.354 | unavailable | 0.000 |
| libcurl_ffi | cancellation_download | 30 | 1.134 | 6.043 | 15.092 | 19.064 | 38.583 | 7.424 | unavailable | 0.000 |
| libcurl_ffi | cancellation_upload | 30 | 1.872 | 16.188 | 43.054 | 57.503 | 59.503 | 16.603 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_waiting | 30 | 0.065 | 0.106 | 0.206 | 0.412 | 2.024 | 0.348 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_streaming | 30 | 5.038 | 72.036 | 125.868 | 131.270 | 181.976 | 43.340 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_streaming_paused | 30 | 76.713 | 104.746 | 266.529 | 345.781 | 412.761 | 86.926 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_download | 30 | 0.884 | 3.873 | 16.300 | 21.729 | 37.472 | 7.943 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_upload | 30 | 1.856 | 14.258 | 55.105 | 67.843 | 103.159 | 25.566 | unavailable | 0.000 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `cancellation_waiting`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_streaming`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_streaming_paused`: approximately equivalent: p50 values differ by at most 5%.
- `cancellation_download`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_upload`: inconclusive: the observed separation is not stable enough for a stronger claim.
