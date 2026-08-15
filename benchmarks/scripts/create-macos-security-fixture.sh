#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi

output_directory="$1"
mkdir -p "$output_directory"
chmod 700 "$output_directory"

ca_key="$output_directory/ca.key"
ca_certificate="$output_directory/ca.pem"
wrong_ca_key="$output_directory/wrong-ca.key"
wrong_ca_certificate="$output_directory/wrong-ca.pem"
server_key="$output_directory/server.key"
server_csr="$output_directory/server.csr"
server_certificate="$output_directory/server.pem"
untrusted_key="$output_directory/untrusted.key"
untrusted_certificate="$output_directory/untrusted.pem"
extensions="$output_directory/server.ext"

openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 2 \
  -subj '/CN=AlphaX Fixture CA' \
  -addext 'basicConstraints=critical,CA:true' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$ca_key" -out "$ca_certificate"

openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 2 \
  -subj '/CN=AlphaX Wrong Fixture CA' \
  -addext 'basicConstraints=critical,CA:true' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$wrong_ca_key" -out "$wrong_ca_certificate"

openssl req -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' \
  -keyout "$server_key" -out "$server_csr"

printf '%s\n' \
  'basicConstraints=critical,CA:false' \
  'keyUsage=critical,digitalSignature,keyEncipherment' \
  'extendedKeyUsage=serverAuth' \
  'subjectAltName=DNS:localhost,DNS:example.com,IP:127.0.0.1' > "$extensions"

openssl x509 -req -sha256 -days 2 \
  -in "$server_csr" \
  -CA "$ca_certificate" \
  -CAkey "$ca_key" \
  -CAcreateserial \
  -out "$server_certificate" \
  -extfile "$extensions"

openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 2 \
  -subj '/CN=localhost' \
  -addext 'basicConstraints=critical,CA:false' \
  -addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
  -addext 'extendedKeyUsage=serverAuth' \
  -addext 'subjectAltName=DNS:localhost,DNS:example.com,IP:127.0.0.1' \
  -keyout "$untrusted_key" -out "$untrusted_certificate"

openssl x509 -in "$ca_certificate" -outform DER -out "$output_directory/ca.der"
openssl x509 -in "$wrong_ca_certificate" -outform DER -out "$output_directory/wrong-ca.der"

for certificate in "$server_certificate" "$untrusted_certificate"; do
  stem="${certificate%.pem}"
  openssl x509 -in "$certificate" -pubkey -noout -out "$stem.pub"
  openssl pkey -pubin -in "$stem.pub" -outform DER -out "$stem.spki"
  openssl dgst -sha256 -binary "$stem.spki" > "$stem.pin"
done

rm -f "$server_csr" "$extensions" "$output_directory/ca.srl"
chmod 600 "$ca_key" "$wrong_ca_key" "$server_key" "$untrusted_key"
printf 'Created temporary AlphaX macOS security fixture material in %s\n' \
  "$output_directory"
