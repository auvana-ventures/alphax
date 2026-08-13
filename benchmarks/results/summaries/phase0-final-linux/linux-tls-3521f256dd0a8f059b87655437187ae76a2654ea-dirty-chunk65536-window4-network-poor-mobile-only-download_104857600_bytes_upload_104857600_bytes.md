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
| dart_io | download_104857600_bytes | 2 | 1639719.848 | 1639719.848 | 1658819.430 | 1658819.430 | 1658819.430 | 9549.791 | 311.108 | 0.061 |
| dart_io | upload_104857600_bytes | 2 | 1664625.764 | 1664625.764 | 1681064.487 | 1681064.487 | 1681064.487 | 8219.362 | 1664621.573 | 0.060 |
| libcurl_ffi | download_104857600_bytes | 2 | 1594653.553 | 1594653.553 | 1647038.912 | 1647038.912 | 1647038.912 | 26192.679 | 313.916 | 0.062 |
| libcurl_ffi | upload_104857600_bytes | 2 | 1675628.142 | 1675628.142 | 1676391.869 | 1676391.869 | 1676391.869 | 381.863 | 1675622.966 | 0.060 |
| rust_reqwest_ffi | download_104857600_bytes | 2 | 1593031.767 | 1593031.767 | 1666444.602 | 1666444.602 | 1666444.602 | 36706.418 | 311.017 | 0.061 |
| rust_reqwest_ffi | upload_104857600_bytes | 2 | 1630913.483 | 1630913.483 | 1671191.557 | 1671191.557 | 1671191.557 | 20139.037 | 1630909.904 | 0.061 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `upload_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
