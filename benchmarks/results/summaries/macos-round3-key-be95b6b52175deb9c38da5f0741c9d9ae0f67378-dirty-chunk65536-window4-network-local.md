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
| dart_io | concurrency_100 | 30 | 27.791 | 42.523 | 97.453 | 107.286 | 131.445 | 27.907 | unavailable | 2.186 |
| dart_io | concurrency_250 | 30 | 46.453 | 63.450 | 83.240 | 95.636 | 119.908 | 16.379 | unavailable | 3.897 |
| dart_io | connection_reuse_sequential | 30 | 32.711 | 54.896 | 66.603 | 69.399 | 74.536 | 11.102 | unavailable | 1.933 |
| dart_io | download_10485760_bytes | 30 | 155.796 | 237.141 | 276.176 | 312.158 | 313.227 | 35.561 | 158.656 | 43.320 |
| dart_io | download_104857600_bytes | 30 | 1764.403 | 1954.000 | 2205.068 | 2340.030 | 2349.844 | 142.911 | 172.471 | 49.786 |
| dart_io | download_stream_to_dart_file_10485760_bytes | 30 | 345.830 | 420.819 | 484.658 | 533.574 | 583.793 | 50.737 | 145.837 | 23.616 |
| dart_io | download_stream_to_dart_file_104857600_bytes | 30 | 3993.304 | 4276.290 | 4469.678 | 4790.735 | 4888.734 | 189.943 | 170.742 | 23.195 |
| dart_io | upload_10485760_bytes | 30 | 47.273 | 72.851 | 117.730 | 150.988 | 153.226 | 28.375 | 72.788 | 139.750 |
| dart_io | upload_104857600_bytes | 30 | 616.355 | 723.656 | 988.231 | 1086.955 | 1269.966 | 151.479 | 723.604 | 129.270 |
| dart_io | stream_2097152_bytes | 30 | 76.153 | 98.875 | 145.431 | 184.143 | 343.136 | 47.791 | 59.375 | 18.470 |
| dart_io | stream_2097152_bytes_slow_consumer | 30 | 228.288 | 248.328 | 281.860 | 293.960 | 299.256 | 19.187 | 65.063 | 7.925 |
| libcurl_ffi | concurrency_100 | 30 | 44.686 | 64.220 | 136.808 | 146.132 | 155.772 | 32.333 | unavailable | 1.357 |
| libcurl_ffi | concurrency_250 | 30 | 86.438 | 141.095 | 171.346 | 196.956 | 209.804 | 27.171 | unavailable | 1.802 |
| libcurl_ffi | connection_reuse_sequential | 30 | 75.312 | 138.096 | 304.636 | 358.210 | 378.931 | 79.141 | unavailable | 0.704 |
| libcurl_ffi | download_10485760_bytes | 30 | 215.735 | 251.054 | 292.771 | 338.093 | 429.871 | 41.969 | 244.532 | 39.089 |
| libcurl_ffi | download_104857600_bytes | 30 | 2332.299 | 2474.169 | 2715.357 | 2808.763 | 2815.831 | 140.833 | 362.527 | 39.760 |
| libcurl_ffi | download_stream_to_dart_file_10485760_bytes | 30 | 609.820 | 705.675 | 790.124 | 943.780 | 987.697 | 86.381 | 25.903 | 14.078 |
| libcurl_ffi | download_stream_to_dart_file_104857600_bytes | 30 | 6448.654 | 7290.722 | 8316.711 | 8359.503 | 8397.677 | 577.229 | 34.116 | 13.584 |
| libcurl_ffi | upload_10485760_bytes | 30 | 34.170 | 57.379 | 90.568 | 105.248 | 149.441 | 23.476 | 57.292 | 168.472 |
| libcurl_ffi | upload_104857600_bytes | 30 | 452.499 | 520.611 | 567.393 | 584.800 | 650.483 | 44.600 | 520.491 | 193.313 |
| libcurl_ffi | stream_2097152_bytes | 30 | 102.121 | 133.977 | 165.367 | 174.426 | 176.723 | 19.071 | 38.880 | 14.785 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 30 | 192.791 | 235.307 | 281.641 | 317.972 | 325.506 | 33.932 | 41.700 | 8.426 |
| rust_reqwest_ffi | concurrency_100 | 30 | 32.056 | 58.785 | 82.736 | 98.838 | 112.062 | 17.747 | unavailable | 1.684 |
| rust_reqwest_ffi | concurrency_250 | 30 | 56.565 | 103.327 | 119.861 | 148.860 | 191.128 | 27.242 | unavailable | 2.642 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 67.297 | 123.685 | 181.785 | 225.143 | 243.232 | 45.196 | unavailable | 0.828 |
| rust_reqwest_ffi | download_10485760_bytes | 30 | 199.230 | 238.186 | 291.504 | 301.849 | 330.903 | 30.089 | 237.138 | 41.420 |
| rust_reqwest_ffi | download_104857600_bytes | 30 | 2051.950 | 2300.880 | 2433.581 | 2572.391 | 2597.024 | 132.151 | 2168.398 | 43.633 |
| rust_reqwest_ffi | download_stream_to_dart_file_10485760_bytes | 30 | 601.778 | 704.324 | 825.288 | 949.415 | 962.263 | 90.313 | 60.490 | 13.961 |
| rust_reqwest_ffi | download_stream_to_dart_file_104857600_bytes | 30 | 6881.428 | 7437.923 | 8269.868 | 8355.928 | 9622.981 | 528.525 | 70.080 | 13.139 |
| rust_reqwest_ffi | upload_10485760_bytes | 30 | 73.503 | 180.002 | 283.799 | 402.344 | 671.121 | 116.793 | 179.920 | 64.246 |
| rust_reqwest_ffi | upload_104857600_bytes | 30 | 1256.349 | 2123.232 | 3539.691 | 4236.379 | 4475.961 | 844.751 | 2123.157 | 47.169 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 97.537 | 123.403 | 159.377 | 167.205 | 174.147 | 21.113 | 57.637 | 15.912 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 30 | 214.665 | 261.309 | 295.821 | 333.353 | 333.740 | 30.829 | 71.571 | 7.765 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `concurrency_100`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `concurrency_250`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `connection_reuse_sequential`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `download_10485760_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `download_104857600_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `download_stream_to_dart_file_10485760_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `download_stream_to_dart_file_104857600_bytes`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `upload_10485760_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `upload_104857600_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_slow_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
