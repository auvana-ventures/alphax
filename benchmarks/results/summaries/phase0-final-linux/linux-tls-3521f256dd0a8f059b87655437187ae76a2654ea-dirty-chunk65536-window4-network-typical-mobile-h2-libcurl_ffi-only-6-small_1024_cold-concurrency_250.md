# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| libcurl_ffi | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| libcurl_ffi | small_1024_cold | 30 | 311.692 | 317.152 | 321.971 | 622.891 | 722.377 | 89.871 | 316.319 | 0.003 |
| libcurl_ffi | small_1024_warm | 30 | 102.855 | 103.206 | 105.825 | 106.321 | 235.045 | 23.584 | 102.713 | 0.009 |
| libcurl_ffi | concurrency_50 | 30 | 312.636 | 334.296 | 425.342 | 519.005 | 526.118 | 59.941 | unavailable | 0.135 |
| libcurl_ffi | concurrency_100 | 30 | 447.720 | 543.235 | 649.125 | 679.139 | 730.323 | 69.448 | unavailable | 0.173 |
| libcurl_ffi | concurrency_250 | 30 | 446.636 | 589.045 | 738.970 | 793.721 | 1005.159 | 109.151 | unavailable | 0.406 |
| libcurl_ffi | connection_reuse_sequential | 30 | 10329.176 | 11037.404 | 11914.560 | 12624.738 | 12784.747 | 632.420 | unavailable | 0.009 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: only one candidate has measured samples.
- `small_1024_warm`: only one candidate has measured samples.
- `concurrency_50`: only one candidate has measured samples.
- `concurrency_100`: only one candidate has measured samples.
- `concurrency_250`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
