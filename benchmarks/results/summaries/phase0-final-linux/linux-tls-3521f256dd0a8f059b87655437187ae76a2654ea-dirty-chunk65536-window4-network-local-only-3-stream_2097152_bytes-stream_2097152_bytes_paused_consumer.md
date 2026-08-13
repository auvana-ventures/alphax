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
| dart_io | stream_2097152_bytes | 10 | 84.537 | 95.651 | 99.832 | 101.624 | 101.624 | 5.630 | 3.316 | 21.242 |
| dart_io | stream_2097152_bytes_slow_consumer | 10 | 942.602 | 979.488 | 1011.248 | 1024.533 | 1024.533 | 26.868 | 4.190 | 2.042 |
| dart_io | stream_2097152_bytes_paused_consumer | 10 | 6191.810 | 6220.990 | 6241.835 | 6248.223 | 6248.223 | 18.022 | 6.423 | 0.321 |
| libcurl_ffi | stream_2097152_bytes | 10 | 81.324 | 85.988 | 108.206 | 131.610 | 131.610 | 14.796 | 2.451 | 21.409 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 10 | 107.579 | 110.472 | 118.373 | 130.484 | 130.484 | 6.741 | 2.400 | 17.759 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 10 | 687.239 | 692.499 | 701.701 | 731.824 | 731.824 | 12.107 | 3.248 | 2.869 |
| rust_reqwest_ffi | stream_2097152_bytes | 10 | 74.512 | 77.513 | 87.997 | 90.502 | 90.502 | 5.100 | 2.287 | 25.149 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 10 | 106.185 | 111.010 | 114.174 | 114.751 | 114.751 | 2.765 | 2.541 | 18.020 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 10 | 684.349 | 688.890 | 693.350 | 697.093 | 697.093 | 3.976 | 3.298 | 2.900 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: likely difference: rust_reqwest_ffi is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes_slow_consumer`: approximately equivalent: p50 values differ by at most 5%.
- `stream_2097152_bytes_paused_consumer`: approximately equivalent: p50 values differ by at most 5%.
