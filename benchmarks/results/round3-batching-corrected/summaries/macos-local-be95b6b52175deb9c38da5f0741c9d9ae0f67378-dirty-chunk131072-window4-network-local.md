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
| dart_io | stream_2097152_bytes | 30 | 76.581 | 100.563 | 123.625 | 130.942 | 153.588 | 16.284 | 56.174 | 19.798 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 200.298 | 241.376 | 264.665 | 272.286 | 279.994 | 17.700 | 66.716 | 8.300 |
| libcurl_ffi | stream_2097152_bytes | 30 | 102.598 | 124.688 | 159.096 | 166.929 | 178.371 | 18.753 | 48.288 | 15.754 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 105.950 | 136.969 | 157.228 | 163.196 | 167.006 | 14.364 | 42.496 | 14.684 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 89.325 | 111.590 | 135.138 | 138.962 | 146.455 | 13.736 | 58.088 | 17.704 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 136.348 | 165.869 | 206.427 | 207.427 | 232.317 | 24.754 | 70.631 | 11.831 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: likely difference: libcurl_ffi is faster, but variance or overlap limits confidence.
