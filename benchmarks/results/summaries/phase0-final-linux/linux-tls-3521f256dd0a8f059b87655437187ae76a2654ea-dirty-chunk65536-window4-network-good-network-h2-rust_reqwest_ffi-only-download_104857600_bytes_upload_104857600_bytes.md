# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | download_104857600_bytes | 2 | 8862.486 | 8862.486 | 8891.187 | 8891.187 | 8891.187 | 14.351 | 35.620 | 11.265 |
| rust_reqwest_ffi | upload_104857600_bytes | 2 | 71145.611 | 71145.611 | 71351.079 | 71351.079 | 71351.079 | 102.734 | 71143.611 | 1.404 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: only one candidate has measured samples.
- `upload_104857600_bytes`: only one candidate has measured samples.
