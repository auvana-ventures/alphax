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
| dart_io | stream_2097152_bytes | 30 | 77.472 | 102.920 | 122.382 | 126.899 | 132.861 | 12.801 | 64.673 | 19.560 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 220.362 | 252.500 | 287.411 | 324.706 | 329.922 | 26.052 | unavailable | 7.777 |
| libcurl_ffi | stream_2097152_bytes | 30 | 100.894 | 134.329 | 162.203 | 170.704 | 178.058 | 18.602 | 51.012 | 14.962 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 126.303 | 148.286 | 185.830 | 192.848 | 194.282 | 19.378 | unavailable | 13.216 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 113.121 | 142.477 | 158.201 | 171.938 | 177.078 | 14.861 | 68.395 | 14.302 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 202.929 | 246.205 | 285.882 | 297.035 | 330.444 | 27.344 | unavailable | 8.003 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: likely difference: libcurl_ffi is faster, but variance or overlap limits confidence.
