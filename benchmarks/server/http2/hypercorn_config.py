"""Stable Hypercorn settings for the AlphaX HTTP/2 benchmark profile."""

# Hypercorn's default keep-alive request cap is 1,000. That would make a
# long-lived HTTP/2 connection emit GOAWAY during repeated benchmark runs and
# would incorrectly look like a client transport failure.
keep_alive_max_requests = 100_000

# The candidate workload reaches 250 concurrent requests. Keep the server
# limit above the workload without making it unbounded.
h2_max_concurrent_streams = 512

# This profile is HTTP/2-only. A client that falls back to HTTP/1.1 must fail
# or be run separately; it must not be labeled as an h2 measurement.
alpn_protocols = ["h2"]
