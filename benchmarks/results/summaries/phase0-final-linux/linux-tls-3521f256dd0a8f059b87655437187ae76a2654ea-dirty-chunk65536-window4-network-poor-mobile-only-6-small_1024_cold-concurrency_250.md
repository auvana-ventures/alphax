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
| dart_io | small_1024_cold | 30 | 916.151 | 923.012 | 1874.353 | 1960.366 | 2141.036 | 402.618 | 922.487 | 0.001 |
| dart_io | small_1024_warm | 30 | 305.655 | 307.794 | 309.256 | 1173.388 | 1600.486 | 274.747 | 307.215 | 0.003 |
| dart_io | concurrency_50 | 30 | 438.188 | 1263.832 | 1566.234 | 1614.348 | 1635.243 | 402.703 | unavailable | 0.053 |
| dart_io | concurrency_100 | 30 | 940.700 | 1722.394 | 2124.144 | 2153.905 | 2283.356 | 334.510 | unavailable | 0.061 |
| dart_io | concurrency_250 | 30 | 1398.621 | 2672.740 | 3309.284 | 5020.739 | 5218.048 | 756.697 | unavailable | 0.093 |
| dart_io | connection_reuse_sequential | 30 | 31483.626 | 33755.486 | 36112.173 | 36989.818 | 38032.057 | 1703.894 | unavailable | 0.003 |
| libcurl_ffi | small_1024_cold | 30 | 916.471 | 921.455 | 1848.414 | 2095.066 | 2609.153 | 440.055 | 920.447 | 0.001 |
| libcurl_ffi | small_1024_warm | 30 | 305.412 | 307.569 | 315.396 | 853.610 | 1354.025 | 208.863 | 306.469 | 0.003 |
| libcurl_ffi | concurrency_50 | 30 | 1005.677 | 2408.022 | 3219.620 | 3513.142 | 7004.862 | 1042.113 | unavailable | 0.021 |
| libcurl_ffi | concurrency_100 | 30 | 2257.597 | 3539.289 | 3935.082 | 4754.805 | 5202.034 | 709.093 | unavailable | 0.031 |
| libcurl_ffi | concurrency_250 | 30 | 3290.088 | 5240.344 | 7598.189 | 11425.269 | 13292.777 | 2173.638 | unavailable | 0.048 |
| libcurl_ffi | connection_reuse_sequential | 30 | 32086.734 | 34134.625 | 36349.829 | 36691.499 | 37155.485 | 1401.784 | unavailable | 0.003 |
| rust_reqwest_ffi | small_1024_cold | 30 | 912.053 | 917.955 | 920.677 | 1763.358 | 1924.109 | 232.052 | 916.989 | 0.001 |
| rust_reqwest_ffi | small_1024_warm | 30 | 305.326 | 307.404 | 309.567 | 869.163 | 1181.086 | 183.551 | 306.335 | 0.003 |
| rust_reqwest_ffi | concurrency_50 | 30 | 613.260 | 1315.938 | 1731.290 | 2250.756 | 2791.139 | 430.168 | unavailable | 0.039 |
| rust_reqwest_ffi | concurrency_100 | 30 | 1130.410 | 1751.866 | 2203.149 | 2625.046 | 3454.169 | 431.038 | unavailable | 0.056 |
| rust_reqwest_ffi | concurrency_250 | 30 | 2148.454 | 3163.241 | 4123.363 | 4578.777 | 4641.556 | 602.852 | unavailable | 0.079 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 31164.675 | 33716.888 | 35666.423 | 37386.598 | 38365.051 | 1646.645 | unavailable | 0.003 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: approximately equivalent: p50 values differ by at most 5%.
- `small_1024_warm`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_50`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_100`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_250`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `connection_reuse_sequential`: approximately equivalent: p50 values differ by at most 5%.
