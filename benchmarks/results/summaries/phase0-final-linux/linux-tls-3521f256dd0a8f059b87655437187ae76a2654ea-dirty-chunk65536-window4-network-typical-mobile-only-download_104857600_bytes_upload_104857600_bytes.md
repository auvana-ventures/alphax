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
| dart_io | download_104857600_bytes | 2 | 296779.299 | 296779.299 | 330099.294 | 330099.294 | 330099.294 | 16659.998 | 107.341 | 0.320 |
| dart_io | upload_104857600_bytes | 2 | 279357.682 | 279357.682 | 309575.674 | 309575.674 | 309575.674 | 15108.996 | 279356.536 | 0.340 |
| libcurl_ffi | download_104857600_bytes | 2 | 283682.966 | 283682.966 | 327874.197 | 327874.197 | 327874.197 | 22095.615 | 104.869 | 0.329 |
| libcurl_ffi | upload_104857600_bytes | 2 | 319749.499 | 319749.499 | 335048.617 | 335048.617 | 335048.617 | 7649.559 | 319738.692 | 0.306 |
| rust_reqwest_ffi | download_104857600_bytes | 2 | 338330.747 | 338330.747 | 342929.020 | 342929.020 | 342929.020 | 2299.137 | 105.385 | 0.294 |
| rust_reqwest_ffi | upload_104857600_bytes | 2 | 308859.415 | 308859.415 | 316801.216 | 316801.216 | 316801.216 | 3970.901 | 308850.748 | 0.320 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `upload_104857600_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
