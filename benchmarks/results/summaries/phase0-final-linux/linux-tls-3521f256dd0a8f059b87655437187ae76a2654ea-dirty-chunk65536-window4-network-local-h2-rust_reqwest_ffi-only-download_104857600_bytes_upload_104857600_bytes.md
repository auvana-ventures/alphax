# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| rust_reqwest_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| rust_reqwest_ffi | download_104857600_bytes | 3 | 7564.902 | 7596.582 | 7675.801 | 7675.801 | 7675.801 | 46.640 | 4.147 | 13.137 |
| rust_reqwest_ffi | upload_104857600_bytes | 3 | 13256.945 | 13500.006 | 13645.744 | 13645.744 | 13645.744 | 160.376 | 13497.287 | 7.426 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: only one candidate has measured samples.
- `upload_104857600_bytes`: only one candidate has measured samples.
