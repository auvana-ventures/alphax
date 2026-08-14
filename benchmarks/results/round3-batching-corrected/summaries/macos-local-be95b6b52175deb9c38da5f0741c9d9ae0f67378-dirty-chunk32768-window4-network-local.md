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
| dart_io | stream_2097152_bytes | 30 | 90.348 | 125.022 | 139.424 | 165.116 | 180.413 | 20.551 | 78.328 | 16.493 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 219.715 | 263.696 | 312.727 | 318.707 | 372.715 | 31.526 | 76.717 | 7.414 |
| libcurl_ffi | stream_2097152_bytes | 30 | 114.120 | 128.934 | 148.821 | 156.317 | 157.176 | 11.110 | 26.243 | 15.399 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 281.440 | 324.445 | 349.900 | 354.186 | 356.866 | 21.170 | 29.519 | 6.202 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 104.687 | 136.513 | 165.945 | 180.003 | 202.298 | 21.985 | 52.605 | 14.844 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 302.176 | 322.012 | 371.314 | 418.078 | 458.656 | 33.628 | 62.140 | 6.017 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_slow_consumer`: likely difference: dart_io is faster, but variance or overlap limits confidence.
