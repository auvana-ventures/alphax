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
| dart_io | download_104857600_bytes | 3 | 8920.483 | 8921.228 | 8925.016 | 8925.016 | 8925.016 | 1.985 | 35.965 | 11.208 |
| dart_io | upload_104857600_bytes | 3 | 8928.385 | 8928.482 | 8928.995 | 8928.995 | 8928.995 | 0.268 | 8927.505 | 11.200 |
| libcurl_ffi | download_104857600_bytes | 3 | 8926.449 | 8927.959 | 8941.925 | 8941.925 | 8941.925 | 6.967 | 39.804 | 11.196 |
| libcurl_ffi | upload_104857600_bytes | 3 | 8847.510 | 8848.000 | 8852.272 | 8852.272 | 8852.272 | 2.139 | 8844.935 | 11.300 |
| rust_reqwest_ffi | download_104857600_bytes | 3 | 8923.996 | 8925.698 | 8927.386 | 8927.386 | 8927.386 | 1.384 | 36.445 | 11.204 |
| rust_reqwest_ffi | upload_104857600_bytes | 3 | 8877.731 | 8882.563 | 8904.758 | 8904.758 | 8904.758 | 11.768 | 8880.475 | 11.251 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `upload_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
