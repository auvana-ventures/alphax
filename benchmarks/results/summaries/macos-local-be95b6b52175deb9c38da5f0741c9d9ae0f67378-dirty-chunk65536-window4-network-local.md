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
| dart_io | stream_2097152_bytes | 30 | 86.881 | 105.509 | 120.439 | 124.846 | 128.744 | 10.631 | 69.103 | 18.853 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 224.537 | 255.608 | 279.057 | 279.391 | 283.617 | 16.598 | unavailable | 7.863 |
| libcurl_ffi | stream_2097152_bytes | 30 | 106.514 | 145.804 | 169.193 | 179.267 | 196.829 | 21.710 | 45.392 | 14.002 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 193.477 | 232.324 | 263.201 | 274.836 | 288.911 | 22.706 | unavailable | 8.715 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 110.175 | 133.832 | 157.681 | 162.114 | 162.499 | 15.757 | 59.202 | 14.951 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 223.648 | 249.796 | 279.340 | 287.894 | 290.297 | 20.545 | unavailable | 7.996 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
