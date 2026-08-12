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
| dart_io | stream_2097152_bytes | 30 | 93.969 | 116.878 | 131.582 | 156.682 | 162.732 | 15.378 | 77.934 | 17.115 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 215.907 | 249.455 | 270.648 | 277.759 | 287.367 | 16.132 | unavailable | 8.021 |
| libcurl_ffi | stream_2097152_bytes | 30 | 95.891 | 113.073 | 130.611 | 132.690 | 147.710 | 12.493 | 60.685 | 17.620 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 100.840 | 131.502 | 159.070 | 185.521 | 204.338 | 23.594 | unavailable | 15.208 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 108.214 | 140.470 | 182.243 | 190.693 | 194.046 | 22.245 | 68.633 | 13.889 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 217.323 | 240.001 | 281.214 | 290.834 | 298.534 | 23.340 | unavailable | 8.113 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_slow_consumer`: likely difference: libcurl_ffi is faster, but variance or overlap limits confidence.
