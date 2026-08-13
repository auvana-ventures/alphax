# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | stream_2097152_bytes | 10 | 149.057 | 154.170 | 164.744 | 173.577 | 173.577 | 7.083 | 1.692 | 12.781 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 10 | 152.612 | 157.475 | 165.357 | 196.386 | 196.386 | 12.067 | 1.687 | 12.431 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 10 | 684.265 | 688.539 | 695.326 | 695.607 | 695.607 | 3.878 | 2.637 | 2.898 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
