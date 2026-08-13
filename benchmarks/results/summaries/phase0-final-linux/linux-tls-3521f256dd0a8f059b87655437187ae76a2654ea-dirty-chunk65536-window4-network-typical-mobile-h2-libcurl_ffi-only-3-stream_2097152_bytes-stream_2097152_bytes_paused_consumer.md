# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | stream_2097152_bytes | 3 | 6352.566 | 6852.030 | 6978.931 | 6978.931 | 6978.931 | 270.370 | 120.932 | 0.298 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 3 | 2008.627 | 2307.320 | 4589.968 | 4589.968 | 4589.968 | 1152.920 | 120.560 | 0.766 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 3 | 2001.850 | 2818.679 | 6835.165 | 6835.165 | 6835.165 | 2112.405 | 121.277 | 0.667 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
