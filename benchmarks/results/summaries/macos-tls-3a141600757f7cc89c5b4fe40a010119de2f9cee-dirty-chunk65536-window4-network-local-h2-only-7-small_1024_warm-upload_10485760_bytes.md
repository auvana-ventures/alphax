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
| dart_io | small_1024_warm | 30 | 1.034 | 1.317 | 2.313 | 2.415 | 2.727 | 0.472 | 1.027 | 0.690 |
| dart_io | concurrency_100 | 30 | 36.493 | 40.293 | 48.011 | 49.301 | 49.821 | 3.777 | unavailable | 2.392 |
| dart_io | concurrency_250 | 30 | 76.746 | 101.937 | 124.725 | 132.661 | 137.195 | 14.018 | unavailable | 2.374 |
| dart_io | connection_reuse_sequential | 30 | 63.622 | 69.220 | 73.361 | 76.510 | 84.812 | 4.265 | unavailable | 1.410 |
| dart_io | download_10485760_bytes | 30 | 696.663 | 703.726 | 721.527 | 726.349 | 739.515 | 9.603 | 1.556 | 14.147 |
| dart_io | upload_10485760_bytes | 30 | 1212.688 | 1227.554 | 1247.569 | 1275.631 | 1301.311 | 17.589 | 1227.518 | 8.107 |
| dart_io | stream_2097152_bytes | 30 | 139.875 | 141.691 | 145.523 | 147.742 | 156.377 | 3.211 | 1.427 | 14.019 |
| libcurl_ffi | small_1024_warm | 30 | 0.993 | 1.145 | 1.362 | 1.806 | 1.938 | 0.208 | 0.976 | 0.812 |
| libcurl_ffi | concurrency_100 | 30 | 47.940 | 51.249 | 54.582 | 56.879 | 72.360 | 4.205 | unavailable | 1.875 |
| libcurl_ffi | concurrency_250 | 30 | 122.767 | 132.034 | 142.212 | 151.795 | 154.986 | 7.471 | unavailable | 1.843 |
| libcurl_ffi | connection_reuse_sequential | 30 | 76.419 | 80.232 | 94.462 | 99.302 | 133.179 | 10.742 | unavailable | 1.174 |
| libcurl_ffi | download_10485760_bytes | 30 | 764.264 | 776.442 | 792.862 | 798.047 | 835.418 | 13.849 | 6.463 | 12.832 |
| libcurl_ffi | upload_10485760_bytes | 30 | 1271.595 | 1301.387 | 1460.782 | 1535.868 | 1557.717 | 83.752 | 1301.282 | 7.485 |
| libcurl_ffi | stream_2097152_bytes | 30 | 153.530 | 155.970 | 162.747 | 164.523 | 170.989 | 3.801 | 5.816 | 12.715 |
| rust_reqwest_ffi | small_1024_warm | 30 | 1.059 | 1.280 | 1.454 | 1.660 | 1.821 | 0.173 | 0.874 | 0.756 |
| rust_reqwest_ffi | concurrency_100 | 30 | 48.487 | 51.865 | 55.969 | 59.593 | 61.679 | 3.045 | unavailable | 1.865 |
| rust_reqwest_ffi | concurrency_250 | 30 | 142.990 | 151.596 | 166.047 | 176.099 | 180.576 | 8.863 | unavailable | 1.583 |
| rust_reqwest_ffi | connection_reuse_sequential | 30 | 77.633 | 81.811 | 86.943 | 89.295 | 97.210 | 4.104 | unavailable | 1.183 |
| rust_reqwest_ffi | download_10485760_bytes | 30 | 761.011 | 770.748 | 789.979 | 791.323 | 797.156 | 9.192 | 1.590 | 12.921 |
| rust_reqwest_ffi | upload_10485760_bytes | 30 | 1335.427 | 1349.518 | 1378.921 | 1385.920 | 1420.426 | 18.275 | 1349.402 | 7.374 |
| rust_reqwest_ffi | stream_2097152_bytes | 30 | 152.990 | 154.081 | 159.531 | 160.822 | 163.763 | 2.564 | 1.390 | 12.887 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `small_1024_warm`: likely difference: libcurl_ffi is faster, but variance or overlap limits confidence.
- `concurrency_100`: clear difference: dart_io is faster with stable, non-overlapping samples.
- `concurrency_250`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `connection_reuse_sequential`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `download_10485760_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `upload_10485760_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
