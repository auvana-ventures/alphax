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
| dart_io | stream_2097152_bytes | 30 | 83.692 | 104.958 | 120.904 | 139.629 | 153.473 | 14.319 | 67.933 | 18.658 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 230.042 | 256.446 | 300.810 | 318.808 | 331.278 | 25.277 | unavailable | 7.631 |
| libcurl_ffi | stream_2097152_bytes | 30 | 117.160 | 143.873 | 168.434 | 178.366 | 201.157 | 17.352 | 29.262 | 13.867 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 330.194 | 369.671 | 413.660 | 421.584 | 431.712 | 28.331 | unavailable | 5.367 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 113.560 | 135.576 | 153.661 | 191.274 | 199.576 | 18.325 | 60.689 | 14.371 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 358.180 | 396.966 | 448.223 | 456.082 | 465.198 | 26.751 | unavailable | 4.956 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: clear difference: dart_io is faster with stable, non-overlapping samples.
