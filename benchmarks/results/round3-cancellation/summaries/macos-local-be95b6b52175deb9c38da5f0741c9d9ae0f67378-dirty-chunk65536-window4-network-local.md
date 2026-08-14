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
| dart_io | cancellation_waiting | 30 | 0.136 | 0.288 | 0.494 | 0.553 | 0.614 | 0.115 | unavailable | 0.000 |
| dart_io | cancellation_streaming | 30 | 11.184 | 69.913 | 125.016 | 133.893 | 164.127 | 42.507 | unavailable | 0.000 |
| dart_io | cancellation_download | 30 | 0.054 | 0.167 | 0.308 | 0.543 | 3.209 | 0.554 | unavailable | 0.000 |
| dart_io | cancellation_upload | 30 | 0.122 | 0.228 | 0.378 | 1.702 | 7.881 | 1.391 | unavailable | 0.000 |
| libcurl_ffi | cancellation_waiting | 30 | 0.053 | 0.104 | 0.284 | 1.366 | 1.708 | 0.363 | unavailable | 0.000 |
| libcurl_ffi | cancellation_streaming | 30 | 3.783 | 87.293 | 132.145 | 144.960 | 184.308 | 48.806 | unavailable | 0.000 |
| libcurl_ffi | cancellation_download | 30 | 5.529 | 19.565 | 32.420 | 37.639 | 39.781 | 9.367 | unavailable | 0.000 |
| libcurl_ffi | cancellation_upload | 30 | 2.007 | 10.516 | 24.496 | 47.200 | 56.111 | 12.269 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_waiting | 30 | 0.050 | 0.080 | 0.111 | 0.181 | 0.182 | 0.032 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_streaming | 30 | 5.381 | 57.073 | 114.359 | 137.982 | 168.190 | 39.914 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_download | 30 | 4.538 | 27.728 | 101.848 | 135.794 | 138.351 | 37.315 | unavailable | 0.000 |
| rust_reqwest_ffi | cancellation_upload | 30 | 0.837 | 28.219 | 58.332 | 89.129 | 101.449 | 24.701 | unavailable | 0.000 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `cancellation_waiting`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_streaming`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_download`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `cancellation_upload`: inconclusive: the observed separation is not stable enough for a stronger claim.
