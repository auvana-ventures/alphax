# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | stream_2097152_bytes | 10 | 151.326 | 170.652 | 182.052 | 195.229 | 195.229 | 13.971 | 6.087 | 11.821 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 10 | 159.593 | 166.706 | 188.145 | 200.502 | 200.502 | 12.185 | 6.237 | 11.676 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 10 | 682.908 | 686.241 | 691.530 | 692.854 | 692.854 | 2.820 | 7.692 | 2.910 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
