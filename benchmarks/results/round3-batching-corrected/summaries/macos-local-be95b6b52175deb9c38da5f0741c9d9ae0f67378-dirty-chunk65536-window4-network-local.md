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
| dart_io | stream_2097152_bytes | 30 | 86.314 | 104.884 | 119.704 | 125.157 | 125.182 | 10.667 | 60.661 | 18.996 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 208.455 | 223.703 | 246.249 | 250.346 | 257.489 | 12.689 | 62.325 | 8.828 |
| libcurl_ffi | stream_2097152_bytes | 30 | 107.640 | 129.126 | 149.477 | 157.015 | 161.817 | 14.015 | 39.761 | 15.399 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 174.383 | 194.144 | 253.018 | 279.560 | 285.181 | 31.387 | 36.715 | 9.914 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 93.242 | 122.969 | 148.687 | 173.666 | 196.470 | 22.756 | 57.680 | 16.295 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 164.337 | 192.156 | 214.952 | 215.117 | 232.851 | 16.373 | 55.437 | 10.367 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: approximately equivalent: p50 values differ by at most 5%.
