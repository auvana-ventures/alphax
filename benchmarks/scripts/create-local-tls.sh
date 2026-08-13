#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi

output_directory="$1"
mkdir -p "$output_directory"

ca_key="$output_directory/ca.key"
ca_certificate="$output_directory/ca.pem"
server_key="$output_directory/server.key"
server_csr="$output_directory/server.csr"
server_certificate="$output_directory/server.pem"
extensions="$output_directory/server.ext"

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$ca_key" \
  -out "$ca_certificate" \
  -days 1 \
  -subj '/CN=AlphaX Phase 0 Local Benchmark CA'

openssl req -newkey rsa:2048 -nodes \
  -keyout "$server_key" \
  -out "$server_csr" \
  -subj '/CN=127.0.0.1'

printf '%s\n' \
  'basicConstraints=critical,CA:false' \
  'keyUsage=critical,digitalSignature,keyEncipherment' \
  'extendedKeyUsage=serverAuth' \
  'subjectAltName=IP:127.0.0.1,DNS:localhost' > "$extensions"

openssl x509 -req \
  -in "$server_csr" \
  -CA "$ca_certificate" \
  -CAkey "$ca_key" \
  -CAcreateserial \
  -out "$server_certificate" \
  -days 1 \
  -extfile "$extensions"

rm -f "$server_csr" "$extensions" "$output_directory/ca.srl"
chmod 600 "$ca_key" "$server_key"
printf 'CA certificate: %s\nServer certificate: %s\nServer key: %s\n' \
  "$ca_certificate" "$server_certificate" "$server_key"
