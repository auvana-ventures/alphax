# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | stream_2097152_bytes | 2 | 26681.398 | 26681.398 | 29885.928 | 29885.928 | 29885.928 | 1602.265 | 1234.897 | 0.071 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 2 | 18282.190 | 18282.190 | 25465.850 | 25465.850 | 25465.850 | 3591.830 | 1235.461 | 0.094 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 2 | 5926.622 | 5926.622 | 22161.502 | 22161.502 | 22161.502 | 8117.440 | 339.926 | 0.214 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
