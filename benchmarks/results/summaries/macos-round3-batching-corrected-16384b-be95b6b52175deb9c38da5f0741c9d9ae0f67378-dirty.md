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
| dart_io | stream_2097152_bytes | 30 | 93.454 | 127.691 | 173.651 | 189.831 | 194.173 | 28.603 | 83.865 | 15.639 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 221.733 | 255.730 | 306.078 | 310.240 | 331.886 | 29.901 | 71.735 | 7.749 |
| libcurl_ffi | stream_2097152_bytes | 30 | 87.549 | 121.212 | 149.742 | 153.668 | 154.367 | 18.198 | 31.345 | 16.488 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 531.386 | 642.409 | 735.873 | 756.684 | 759.581 | 60.924 | 28.924 | 3.109 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 77.400 | 117.696 | 137.138 | 143.551 | 193.548 | 21.077 | 71.023 | 17.380 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 553.301 | 644.569 | 785.138 | 822.341 | 887.169 | 80.697 | 72.280 | 3.044 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_slow_consumer`: likely difference: dart_io is faster, but variance or overlap limits confidence.
