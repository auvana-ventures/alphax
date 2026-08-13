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
| dart_io | stream_2097152_bytes | 2 | 33584.687 | 33584.687 | 35666.898 | 35666.898 | 35666.898 | 1041.105 | 327.648 | 0.058 |
| dart_io | stream_2097152_bytes_slow_consumer | 2 | 29186.120 | 29186.120 | 38835.622 | 38835.622 | 38835.622 | 4824.751 | 321.939 | 0.060 |
| dart_io | stream_2097152_bytes_paused_consumer | 2 | 29875.753 | 29875.753 | 31327.938 | 31327.938 | 31327.938 | 726.092 | 322.018 | 0.065 |
| libcurl_ffi | stream_2097152_bytes | 2 | 20657.791 | 20657.791 | 36993.646 | 36993.646 | 36993.646 | 8167.927 | 310.015 | 0.075 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 2 | 28291.858 | 28291.858 | 29518.312 | 29518.312 | 29518.312 | 613.227 | 325.995 | 0.069 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 2 | 21815.685 | 21815.685 | 30931.656 | 30931.656 | 30931.656 | 4557.985 | 313.038 | 0.078 |
| rust_reqwest_ffi | stream_2097152_bytes | 2 | 38604.791 | 38604.791 | 43324.015 | 43324.015 | 43324.015 | 2359.612 | 310.922 | 0.049 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 2 | 26064.955 | 26064.955 | 30231.536 | 30231.536 | 30231.536 | 2083.291 | 322.772 | 0.071 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 2 | 24389.058 | 24389.058 | 33008.074 | 33008.074 | 33008.074 | 4309.508 | 309.409 | 0.071 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_slow_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_paused_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
