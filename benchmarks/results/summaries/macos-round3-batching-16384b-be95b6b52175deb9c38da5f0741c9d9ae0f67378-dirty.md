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
| dart_io | stream_2097152_bytes | 30 | 77.664 | 103.110 | 127.065 | 134.412 | 148.033 | 14.751 | 64.006 | 18.835 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 223.328 | 250.139 | 289.558 | 354.211 | 358.312 | 31.398 | unavailable | 7.794 |
| libcurl_ffi | stream_2097152_bytes | 30 | 91.351 | 107.663 | 132.115 | 134.629 | 144.748 | 14.615 | 28.719 | 18.163 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 580.475 | 622.941 | 692.220 | 743.946 | 763.299 | 44.788 | unavailable | 3.168 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 79.995 | 109.542 | 126.353 | 133.002 | 172.734 | 17.172 | 66.171 | 18.408 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 614.099 | 650.751 | 706.474 | 833.889 | 865.771 | 57.227 | unavailable | 2.999 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_slow_consumer`: likely difference: dart_io is faster, but variance or overlap limits confidence.
