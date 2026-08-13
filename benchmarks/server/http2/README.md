# AlphaX HTTP/2 benchmark server

This directory contains a benchmark-only ASGI server for the Phase 0 HTTP/2
profile. It mirrors the deterministic endpoint contract used by the Dart
server. Hypercorn is pinned in `requirements.txt`, and the image is separate
from the Dart server so a profile cannot be mislabeled as HTTP/2 when the
server is only speaking HTTP/1.1.

Generate a temporary trusted certificate and build the image:

```text
TLS_DIR="$(mktemp -d /tmp/alphax-http2-tls.XXXXXX)"
benchmarks/scripts/create-local-tls.sh "$TLS_DIR"
docker build -t alphax-phase0-http2:round4 benchmarks/server/http2
```

Start the server from the repository root:

```text
docker run --rm --name alphax-round4-http2 \
  -p 18445:8443 \
  -v "$PWD/benchmarks/server/http2:/app:ro" \
  -v "$TLS_DIR:/tls:ro" \
  alphax-phase0-http2:round4 \
  --config file:/app/hypercorn_config.py \
  --bind 0.0.0.0:8443 \
  --certfile /tls/server.pem \
  --keyfile /tls/server.key \
  http2_server:app
```

Verify certificate validation and ALPN before running candidates:

```text
curl --fail --http2 --cacert "$TLS_DIR/ca.pem" \
  https://127.0.0.1:18445/health
printf '' | openssl s_client -connect 127.0.0.1:18445 \
  -CAfile "$TLS_DIR/ca.pem" -alpn h2,http/1.1 2>&1 \
  | rg 'ALPN protocol: h2|Verify return code: 0 \(ok\)'
```

The checked-in Hypercorn configuration raises its request cap above the Round 4
workload and limits ALPN to `h2`. Without that configuration Hypercorn's default
request cap can send a clean GOAWAY in the middle of a long benchmark and make
a correct client report an HTTP/2 stream error.

The server is a test fixture only. It is not an AlphaX production engine and it
does not justify a transport selection by itself.
