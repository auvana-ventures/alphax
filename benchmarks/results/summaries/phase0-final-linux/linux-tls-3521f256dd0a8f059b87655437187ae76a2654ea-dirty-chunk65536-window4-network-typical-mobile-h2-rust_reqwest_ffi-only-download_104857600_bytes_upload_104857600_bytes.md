# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | download_104857600_bytes | 2 | 316225.536 | 316225.536 | 330776.194 | 330776.194 | 330776.194 | 7275.329 | 104.988 | 0.309 |
| rust_reqwest_ffi | upload_104857600_bytes | 2 | 350290.560 | 350290.560 | 352605.660 | 352605.660 | 352605.660 | 1157.550 | 350258.312 | 0.285 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: only one candidate has measured samples.
- `upload_104857600_bytes`: only one candidate has measured samples.
