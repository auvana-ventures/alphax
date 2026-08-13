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
| dart_io | download_104857600_bytes | 5 | 2921.980 | 3108.721 | 3667.263 | 3667.263 | 3667.263 | 254.975 | 4.331 | 31.281 |
| dart_io | upload_104857600_bytes | 5 | 1863.910 | 1959.244 | 2493.911 | 2493.911 | 2493.911 | 235.647 | 1959.000 | 48.456 |
| libcurl_ffi | download_104857600_bytes | 5 | 2932.808 | 2978.072 | 3666.018 | 3666.018 | 3666.018 | 279.931 | 9.068 | 32.355 |
| libcurl_ffi | upload_104857600_bytes | 5 | 2424.243 | 2534.719 | 2719.889 | 2719.889 | 2719.889 | 108.786 | 2534.078 | 39.081 |
| rust_reqwest_ffi | download_104857600_bytes | 5 | 2970.807 | 3114.415 | 3317.643 | 3317.643 | 3317.643 | 135.426 | 3.218 | 32.041 |
| rust_reqwest_ffi | upload_104857600_bytes | 5 | 2854.153 | 3115.628 | 3371.304 | 3371.304 | 3371.304 | 189.120 | 3115.087 | 32.499 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `upload_104857600_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
