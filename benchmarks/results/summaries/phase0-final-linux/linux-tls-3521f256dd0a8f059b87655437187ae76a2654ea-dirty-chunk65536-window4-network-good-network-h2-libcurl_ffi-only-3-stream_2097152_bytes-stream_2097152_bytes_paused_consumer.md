# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | stream_2097152_bytes | 5 | 242.235 | 244.326 | 245.672 | 245.672 | 245.672 | 1.147 | 38.860 | 8.193 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 5 | 241.981 | 245.611 | 249.325 | 249.325 | 249.325 | 2.555 | 38.161 | 8.138 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 5 | 731.257 | 735.905 | 739.102 | 739.102 | 739.102 | 2.780 | 39.123 | 2.718 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
