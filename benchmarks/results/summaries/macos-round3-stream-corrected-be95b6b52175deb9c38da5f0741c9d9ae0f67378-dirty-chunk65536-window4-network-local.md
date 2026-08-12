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
| dart_io | stream_2097152_bytes | 30 | 90.885 | 119.460 | 149.483 | 198.454 | 222.375 | 28.945 | 47.072 | 16.309 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 234.727 | 268.387 | 327.171 | 333.927 | 351.399 | 31.930 | 75.671 | 7.283 |
| libcurl_ffi | stream_2097152_bytes | 30 | 106.097 | 143.050 | 202.474 | 217.881 | 329.774 | 42.621 | 43.136 | 13.476 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 188.632 | 207.885 | 245.345 | 257.179 | 261.005 | 20.970 | 42.434 | 9.295 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 102.967 | 129.006 | 149.333 | 174.242 | 243.149 | 25.471 | 66.283 | 15.385 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 179.752 | 203.544 | 218.922 | 241.884 | 250.807 | 16.129 | 59.720 | 9.860 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_slow_consumer`: approximately equivalent: p50 values differ by at most 5%.
