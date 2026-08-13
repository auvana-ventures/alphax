# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | stream_2097152_bytes | 3 | 6165.402 | 6182.394 | 6523.194 | 6523.194 | 6523.194 | 164.806 | 103.593 | 0.318 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 3 | 4524.453 | 5400.334 | 7884.161 | 7884.161 | 7884.161 | 1422.994 | 109.300 | 0.355 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 3 | 5226.835 | 6573.701 | 7956.224 | 7956.224 | 7956.224 | 1114.300 | 113.193 | 0.313 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
