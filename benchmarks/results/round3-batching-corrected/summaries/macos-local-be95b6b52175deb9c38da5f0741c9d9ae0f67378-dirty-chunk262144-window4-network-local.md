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
| dart_io | stream_2097152_bytes | 30 | 93.325 | 107.999 | 118.298 | 120.362 | 142.320 | 9.559 | 41.688 | 18.636 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 227.272 | 261.997 | 320.743 | 332.268 | 341.874 | 30.725 | 76.442 | 7.469 |
| libcurl_ffi | stream_2097152_bytes | 30 | 100.481 | 130.667 | 163.390 | 166.957 | 168.962 | 19.683 | 70.112 | 15.354 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 97.373 | 131.182 | 174.614 | 190.479 | 204.322 | 24.477 | 63.923 | 14.945 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 95.885 | 139.196 | 163.132 | 184.048 | 189.240 | 21.139 | 79.992 | 14.433 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 98.510 | 141.120 | 179.204 | 188.190 | 189.660 | 23.685 | 67.994 | 14.120 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
