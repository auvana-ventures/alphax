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
| dart_io | connection_reuse_sequential | 30 | 43.773 | 65.755 | 89.747 | 97.592 | 110.149 | 16.143 | unavailable | 1.485 |
| libcurl_ffi | connection_reuse_sequential | 30 | 101.220 | 156.537 | 206.866 | 216.203 | 216.734 | 32.054 | unavailable | 0.625 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 67.746 | 140.203 | 191.899 | 237.388 | 293.231 | 46.265 | unavailable | 0.723 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `connection_reuse_sequential`: inconclusive: the observed separation is not stable enough for a stronger claim.
