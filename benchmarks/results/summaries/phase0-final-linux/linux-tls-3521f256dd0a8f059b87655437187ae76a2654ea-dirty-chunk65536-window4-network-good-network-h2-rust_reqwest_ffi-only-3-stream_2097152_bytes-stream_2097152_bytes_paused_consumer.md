# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | stream_2097152_bytes | 5 | 213.981 | 214.726 | 215.471 | 215.471 | 215.471 | 0.471 | 32.455 | 9.314 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 5 | 215.768 | 216.891 | 218.651 | 218.651 | 218.651 | 1.014 | 32.504 | 9.208 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 5 | 719.083 | 724.047 | 761.491 | 761.491 | 761.491 | 15.680 | 33.743 | 2.739 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
- `stream_2097152_bytes_paused_consumer`: only one candidate has measured samples.
