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
| dart_io | connection_reuse_sequential | 10 | 51.829 | 59.689 | 69.816 | 73.666 | 73.666 | 6.460 | unavailable | 1.595 |
| dart_io | download_104857600_bytes | 10 | 1388.881 | 1449.772 | 1515.877 | 1524.914 | 1524.914 | 48.803 | 1.827 | 68.777 |
| dart_io | upload_104857600_bytes | 10 | 702.618 | 718.014 | 769.500 | 881.973 | 881.973 | 51.441 | 717.927 | 135.631 |
| dart_io | stream_2097152_bytes | 10 | 31.733 | 33.598 | 35.518 | 46.592 | 46.592 | 4.102 | 1.497 | 57.927 |
| libcurl_ffi | connection_reuse_sequential | 10 | 37.609 | 39.937 | 46.994 | 47.640 | 47.640 | 3.727 | unavailable | 2.316 |
| libcurl_ffi | download_104857600_bytes | 10 | 1393.959 | 1447.039 | 1533.191 | 1631.498 | 1631.498 | 65.624 | 6.134 | 68.312 |
| libcurl_ffi | upload_104857600_bytes | 10 | 881.792 | 897.957 | 955.946 | 976.364 | 976.364 | 31.679 | 897.759 | 109.536 |
| libcurl_ffi | stream_2097152_bytes | 10 | 31.938 | 35.972 | 39.181 | 39.551 | 39.551 | 2.270 | 1.175 | 55.237 |
| rust_reqwest_ffi | connection_reuse_sequential | 10 | 40.597 | 45.845 | 49.459 | 56.824 | 56.824 | 4.413 | unavailable | 2.113 |
| rust_reqwest_ffi | download_104857600_bytes | 10 | 1401.846 | 1439.479 | 1535.219 | 1536.300 | 1536.300 | 50.934 | 1.287 | 68.070 |
| rust_reqwest_ffi | upload_104857600_bytes | 10 | 825.295 | 839.600 | 968.967 | 988.380 | 988.380 | 56.528 | 839.422 | 115.712 |
| rust_reqwest_ffi | stream_2097152_bytes | 10 | 32.999 | 35.600 | 36.643 | 36.788 | 36.788 | 1.126 | 1.184 | 56.395 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `connection_reuse_sequential`: likely difference: libcurl_ffi is faster, but variance or overlap limits confidence.
- `download_104857600_bytes`: approximately equivalent: p50 values differ by at most 5%.
- `upload_104857600_bytes`: likely difference: dart_io is faster, but variance or overlap limits confidence.
- `stream_2097152_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
