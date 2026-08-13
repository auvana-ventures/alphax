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
| dart_io | small_1024_cold | 30 | 310.821 | 315.503 | 318.312 | 319.884 | 323.432 | 2.764 | 314.898 | 0.003 |
| dart_io | small_1024_warm | 30 | 103.387 | 105.673 | 107.356 | 110.324 | 112.091 | 1.845 | 105.182 | 0.009 |
| dart_io | concurrency_50 | 30 | 171.229 | 176.191 | 460.809 | 514.527 | 610.276 | 144.269 | unavailable | 0.215 |
| dart_io | concurrency_100 | 30 | 237.346 | 530.239 | 876.912 | 920.372 | 956.558 | 241.304 | unavailable | 0.236 |
| dart_io | concurrency_250 | 30 | 440.364 | 840.889 | 1340.604 | 1428.857 | 1497.513 | 282.883 | unavailable | 0.305 |
| dart_io | connection_reuse_sequential | 30 | 10489.262 | 10818.854 | 11338.357 | 11910.066 | 12273.175 | 380.089 | unavailable | 0.009 |
| libcurl_ffi | small_1024_cold | 30 | 310.738 | 315.286 | 320.101 | 327.018 | 1351.684 | 186.012 | 314.138 | 0.003 |
| libcurl_ffi | small_1024_warm | 30 | 103.171 | 104.718 | 106.066 | 106.429 | 108.114 | 0.938 | 103.961 | 0.009 |
| libcurl_ffi | concurrency_50 | 30 | 335.029 | 379.428 | 1326.163 | 1375.961 | 1766.581 | 414.104 | unavailable | 0.099 |
| libcurl_ffi | concurrency_100 | 30 | 379.050 | 692.218 | 1357.396 | 1371.682 | 1486.690 | 365.500 | unavailable | 0.140 |
| libcurl_ffi | concurrency_250 | 30 | 696.175 | 1404.114 | 1718.628 | 2327.779 | 2432.745 | 405.961 | unavailable | 0.189 |
| libcurl_ffi | connection_reuse_sequential | 30 | 10458.766 | 10784.518 | 11355.935 | 11531.016 | 11738.848 | 354.230 | unavailable | 0.009 |
| rust_reqwest_ffi | small_1024_cold | 30 | 307.894 | 312.379 | 317.997 | 330.680 | 650.190 | 60.553 | 311.564 | 0.003 |
| rust_reqwest_ffi | small_1024_warm | 30 | 104.119 | 105.845 | 107.582 | 107.984 | 108.503 | 0.960 | 104.822 | 0.009 |
| rust_reqwest_ffi | concurrency_50 | 30 | 168.756 | 435.464 | 700.146 | 712.547 | 713.760 | 213.276 | unavailable | 0.176 |
| rust_reqwest_ffi | concurrency_100 | 30 | 234.399 | 492.733 | 797.864 | 802.671 | 821.155 | 249.114 | unavailable | 0.244 |
| rust_reqwest_ffi | concurrency_250 | 30 | 430.635 | 876.503 | 1306.687 | 1403.005 | 1403.420 | 326.008 | unavailable | 0.323 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 10458.974 | 10837.266 | 11418.158 | 11514.748 | 11870.211 | 370.885 | unavailable | 0.009 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_cold`: approximately equivalent: p50 values differ by at most 5%.
- `small_1024_warm`: approximately equivalent: p50 values differ by at most 5%.
- `concurrency_50`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_100`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_250`: approximately equivalent: p50 values differ by at most 5%.
- `connection_reuse_sequential`: approximately equivalent: p50 values differ by at most 5%.
