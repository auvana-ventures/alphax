# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | download_104857600_bytes | 2 | 305866.471 | 305866.471 | 311385.509 | 311385.509 | 311385.509 | 2759.519 | 212.806 | 0.324 |
| libcurl_ffi | upload_104857600_bytes | 2 | 378132.019 | 378132.019 | 440396.840 | 440396.840 | 440396.840 | 31132.411 | 378129.707 | 0.246 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: only one candidate has measured samples.
- `upload_104857600_bytes`: only one candidate has measured samples.
