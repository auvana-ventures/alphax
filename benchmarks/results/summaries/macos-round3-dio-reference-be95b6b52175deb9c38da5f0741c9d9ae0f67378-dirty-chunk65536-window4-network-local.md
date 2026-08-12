# AlphaX Phase 0 macOS local benchmark summary

This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.

## Correctness

| Candidate | Passed | Checks | Failures |
| --- | ---: | ---: | --- |
| dio_reference | true | 10 |  |

## Scenario summaries

| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dio_reference | concurrency_100 | 30 | 31.574 | 53.168 | 77.482 | 84.775 | 86.589 | 13.664 | unavailable | 1.891 |
| dio_reference | connection_reuse_sequential | 30 | 37.381 | 56.373 | 85.599 | 97.415 | 119.981 | 17.202 | unavailable | 1.673 |
| dio_reference | download_10485760_bytes | 30 | 137.024 | 190.088 | 230.572 | 259.183 | 259.515 | 27.470 | unavailable | 52.604 |
| dio_reference | upload_10485760_bytes | 30 | 42.376 | 55.297 | 83.526 | 89.904 | 100.893 | 14.923 | unavailable | 173.949 |
| dio_reference | stream_2097152_bytes | 30 | 86.998 | 109.001 | 125.464 | 128.803 | 136.607 | 12.322 | 51.640 | 18.491 |
| dio_reference | stream_2097152_bytes_slow_consumer | 30 | 221.361 | 237.483 | 252.162 | 255.587 | 295.630 | 13.904 | 52.655 | 8.353 |

## Scenario-local interpretation

The following observations are descriptive only; they do not choose AlphaX’s production transport.

- `concurrency_100`: only one candidate has measured samples.
- `connection_reuse_sequential`: only one candidate has measured samples.
- `download_10485760_bytes`: only one candidate has measured samples.
- `upload_10485760_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes`: only one candidate has measured samples.
- `stream_2097152_bytes_slow_consumer`: only one candidate has measured samples.
