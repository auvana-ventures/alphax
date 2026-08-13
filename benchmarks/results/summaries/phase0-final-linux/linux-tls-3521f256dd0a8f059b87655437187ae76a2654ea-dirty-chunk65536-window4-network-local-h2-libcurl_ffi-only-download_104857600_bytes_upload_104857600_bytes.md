# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | download_104857600_bytes | 3 | 7837.017 | 7893.677 | 8410.431 | 8410.431 | 8410.431 | 257.994 | 13.092 | 12.439 |
| libcurl_ffi | upload_104857600_bytes | 3 | 13502.022 | 14030.534 | 14740.424 | 14740.424 | 14740.424 | 507.380 | 14028.136 | 7.106 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: only one candidate has measured samples.
- `upload_104857600_bytes`: only one candidate has measured samples.
