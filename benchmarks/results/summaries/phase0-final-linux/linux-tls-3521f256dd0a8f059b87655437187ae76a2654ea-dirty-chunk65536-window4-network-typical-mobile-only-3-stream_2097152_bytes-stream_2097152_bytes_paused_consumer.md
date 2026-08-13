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
| dart_io | stream_2097152_bytes | 3 | 5654.340 | 6394.349 | 7398.236 | 7398.236 | 7398.236 | 714.654 | 113.379 | 0.312 |
| dart_io | stream_2097152_bytes_slow_consumer | 3 | 4001.955 | 4233.697 | 6810.587 | 6810.587 | 6810.587 | 1272.900 | 114.429 | 0.422 |
| dart_io | stream_2097152_bytes_paused_consumer | 3 | 6311.427 | 6729.352 | 7190.465 | 7190.465 | 7190.465 | 359.010 | 110.818 | 0.297 |
| libcurl_ffi | stream_2097152_bytes | 3 | 5024.588 | 5426.990 | 8305.542 | 8305.542 | 8305.542 | 1461.074 | 110.772 | 0.336 |
| libcurl_ffi | stream_2097152_bytes_slow_consumer | 3 | 6877.321 | 7284.801 | 7507.621 | 7507.621 | 7507.621 | 260.974 | 110.549 | 0.277 |
| libcurl_ffi | stream_2097152_bytes_paused_consumer | 3 | 5316.741 | 5407.295 | 7194.458 | 7194.458 | 7194.458 | 864.611 | 107.247 | 0.341 |
| rust_reqwest_ffi | stream_2097152_bytes | 3 | 7140.138 | 8248.349 | 9397.171 | 9397.171 | 9397.171 | 921.480 | 112.331 | 0.245 |
| rust_reqwest_ffi | stream_2097152_bytes_slow_consumer | 3 | 6123.593 | 6423.664 | 7608.288 | 7608.288 | 7608.288 | 640.980 | 111.335 | 0.300 |
| rust_reqwest_ffi | stream_2097152_bytes_paused_consumer | 3 | 6182.903 | 6530.212 | 7219.818 | 7219.818 | 7219.818 | 430.939 | 107.869 | 0.302 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `stream_2097152_bytes`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_slow_consumer`: inconclusive: the observed separation is not stable enough for a stronger claim.
- `stream_2097152_bytes_paused_consumer`: likely difference: libcurl_ffi is faster, but variance or overlap limits confidence.
