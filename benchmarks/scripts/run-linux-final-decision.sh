#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_directory/../.." && pwd)"
output_directory="${ALPHAX_FINAL_OUTPUT_DIR:-}"
profiles_csv="${ALPHAX_FINAL_PROFILES:-local,good-network,typical-mobile,poor-mobile}"
client_image="${ALPHAX_FINAL_CLIENT_IMAGE:-alphax-phase0-final-client:round5}"
server_image="${ALPHAX_FINAL_SERVER_IMAGE:-alphax-phase0-http2:round5}"

if [[ -z "$output_directory" ]]; then
  printf 'Set ALPHAX_FINAL_OUTPUT_DIR to a host directory outside the repository.\n' >&2
  exit 2
fi

mkdir -p "$output_directory"
output_directory="$(cd "$output_directory" && pwd)"

network_name="alphax-final-net-$$"
client_name="alphax-final-client-$$"
h1_name="alphax-final-h1-$$"
h2_name="alphax-final-h2-$$"
tls_directory="$(mktemp -d "${TMPDIR:-/tmp}/alphax-final-tls.XXXXXX")"

cleanup() {
  set +e
  for container in "$client_name" "$h1_name" "$h2_name"; do
    docker exec "$container" env ALPHAX_NETEM_INTERFACE=eth0 \
      bash /src/benchmarks/scripts/network-profile-linux.sh reset >/dev/null 2>&1 || true
    docker exec "$container" env ALPHAX_NETEM_INTERFACE=eth0 \
      bash /scripts/network-profile-linux.sh reset >/dev/null 2>&1 || true
    docker rm --force "$container" >/dev/null 2>&1 || true
  done
  docker network rm "$network_name" >/dev/null 2>&1 || true
  find "$tls_directory" -mindepth 1 -maxdepth 1 -exec rm -rf {} + >/dev/null 2>&1 || true
  rmdir "$tls_directory" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

IFS=',' read -r -a profiles <<< "$profiles_csv"

ALPHAX_TLS_SERVER_NAMES=alphax-h1-server,alphax-h2-server \
  "$repo_root/benchmarks/scripts/create-local-tls.sh" "$tls_directory" >/dev/null

docker network create "$network_name" >/dev/null

docker run --detach \
  --name "$client_name" \
  --network "$network_name" \
  --cap-add NET_ADMIN \
  --volume "$repo_root:/src" \
  --volume "$tls_directory:/tls:ro" \
  --volume "$output_directory:/results" \
  "$client_image" \
  bash -c 'while :; do sleep 3600; done' >/dev/null

docker run --detach \
  --name "$h1_name" \
  --network "$network_name" \
  --network-alias alphax-h1-server \
  --cap-add NET_ADMIN \
  --volume "$repo_root:/src" \
  --volume "$tls_directory:/tls:ro" \
  "$client_image" \
  bash -c 'cd /src/benchmarks/server && dart pub get >/tmp/alphax-h1-pub-get.log && exec dart run server.dart --host 0.0.0.0 --port 8443 --tls-certificate /tls/server.pem --tls-private-key /tls/server.key' >/dev/null

docker run --detach \
  --name "$h2_name" \
  --network "$network_name" \
  --network-alias alphax-h2-server \
  --cap-add NET_ADMIN \
  --volume "$repo_root/benchmarks/server/http2:/app:ro" \
  --volume "$repo_root/benchmarks/scripts:/scripts:ro" \
  --volume "$tls_directory:/tls:ro" \
  "$server_image" \
  --config file:/app/hypercorn_config.py \
  --bind 0.0.0.0:8443 \
  --certfile /tls/server.pem \
  --keyfile /tls/server.key \
  http2_server:app >/dev/null

wait_for_h1() {
  for _ in $(seq 1 60); do
    if docker exec "$client_name" curl --silent --fail --cacert /tls/ca.pem \
      https://alphax-h1-server:8443/health >/dev/null; then
      return
    fi
    sleep 1
  done
  docker logs "$h1_name" >&2 || true
  return 1
}

wait_for_h2() {
  for _ in $(seq 1 60); do
    if docker exec "$client_name" bash -c \
      "printf '' | openssl s_client -connect alphax-h2-server:8443 -servername alphax-h2-server -CAfile /tls/ca.pem -alpn h2,http/1.1 2>&1 | grep -q 'ALPN protocol: h2'"; then
      return
    fi
    sleep 1
  done
  docker logs "$h2_name" >&2 || true
  return 1
}

docker exec "$client_name" bash -c '
  cd /src
  make -C prototypes/libcurl_ffi
  cargo build --release --manifest-path prototypes/rust_http/Cargo.toml
  cd benchmarks/runner
  dart pub get
' >/tmp/alphax-final-client-build.log

wait_for_h1
wait_for_h2

apply_profile() {
  local container="$1"
  local profile="$2"
  local script_path='/src/benchmarks/scripts/network-profile-linux.sh'
  if [[ "$container" == "$h2_name" ]]; then
    script_path='/scripts/network-profile-linux.sh'
  fi
  docker exec "$container" env ALPHAX_NETEM_INTERFACE=eth0 \
    bash "$script_path" apply "$profile" >/dev/null
}

reset_profile() {
  local container="$1"
  local script_path='/src/benchmarks/scripts/network-profile-linux.sh'
  if [[ "$container" == "$h2_name" ]]; then
    script_path='/scripts/network-profile-linux.sh'
  fi
  docker exec "$container" env ALPHAX_NETEM_INTERFACE=eth0 \
    bash "$script_path" reset >/dev/null 2>&1 || true
}

run_candidate() {
  local profile="$1"
  local protocol="$2"
  local candidate="$3"
  local base_url="$4"
  local iterations="$5"
  local scenarios="$6"
  local output_label="$7"
  local warmup="$8"
  local candidate_argument=''
  if [[ "$candidate" != 'combined' ]]; then
    candidate_argument="--candidate '$candidate'"
  fi
  docker exec "$client_name" bash -c "
    export ALPHAX_CURL_LIBRARY=/src/prototypes/libcurl_ffi/libalphax_curl.so
    export ALPHAX_RUST_LIBRARY=/src/prototypes/rust_http/target/release/libalphax_rust_http.so
    export ALPHAX_BENCHMARK_CA_CERT=/tls/ca.pem
    export ALPHAX_BENCHMARK_PROTOCOL_PROFILE='$protocol'
    cd /src/benchmarks/runner
    dart run bin/run_benchmarks.dart \\
      $candidate_argument \\
      --base-url '$base_url' \\
      --warmup '$warmup' \\
      --iterations '$iterations' \\
      --network-profile '$profile' \\
      --only '$scenarios' \\
      --output /results
  " >"$output_directory/${output_label}.log"
}

run_h1_profile() {
  local profile="$1"
  local request_iterations="$2"
  local stream_iterations="$3"
  local transfer_iterations="$4"
  local request_scenarios='small_1024_cold,small_1024_warm,connection_reuse_sequential,concurrency_50,concurrency_100,concurrency_250'
  local stream_scenarios='stream_2097152_bytes,stream_2097152_bytes_slow_consumer,stream_2097152_bytes_paused_consumer'
  local transfer_scenarios='download_104857600_bytes,upload_104857600_bytes'

  apply_profile "$client_name" "$profile"
  apply_profile "$h1_name" "$profile"
  run_candidate "$profile" 'HTTP/1.1 over TLS' combined 'https://alphax-h1-server:8443' \
    "$request_iterations" "$request_scenarios" "h1-${profile}-requests" 3
  run_candidate "$profile" 'HTTP/1.1 over TLS' combined 'https://alphax-h1-server:8443' \
    "$stream_iterations" "$stream_scenarios" "h1-${profile}-stream" 2
  if [[ "$transfer_iterations" -gt 0 ]]; then
    run_candidate "$profile" 'HTTP/1.1 over TLS' combined 'https://alphax-h1-server:8443' \
      "$transfer_iterations" "$transfer_scenarios" "h1-${profile}-transfers" 1
  fi
  reset_profile "$client_name"
  reset_profile "$h1_name"
}

run_h2_profile() {
  local profile="$1"
  local request_iterations="$2"
  local stream_iterations="$3"
  local transfer_iterations="$4"
  local request_scenarios='small_1024_cold,small_1024_warm,connection_reuse_sequential,concurrency_50,concurrency_100,concurrency_250'
  local stream_scenarios='stream_2097152_bytes,stream_2097152_bytes_slow_consumer,stream_2097152_bytes_paused_consumer'
  local transfer_scenarios='download_104857600_bytes,upload_104857600_bytes'

  apply_profile "$client_name" "$profile"
  apply_profile "$h2_name" "$profile"
  for candidate in libcurl_ffi rust_reqwest_ffi; do
    run_candidate "$profile" 'HTTP/2 over TLS; ALPN h2 verified' "$candidate" \
      'https://alphax-h2-server:8443' "$request_iterations" "$request_scenarios" \
      "h2-${profile}-${candidate}-requests" 3
    run_candidate "$profile" 'HTTP/2 over TLS; ALPN h2 verified' "$candidate" \
      'https://alphax-h2-server:8443' "$stream_iterations" "$stream_scenarios" \
      "h2-${profile}-${candidate}-stream" 2
    if [[ "$transfer_iterations" -gt 0 ]]; then
      run_candidate "$profile" 'HTTP/2 over TLS; ALPN h2 verified' "$candidate" \
        'https://alphax-h2-server:8443' "$transfer_iterations" "$transfer_scenarios" \
        "h2-${profile}-${candidate}-transfers" 1
    fi
  done
  reset_profile "$client_name"
  reset_profile "$h2_name"
}

for profile in "${profiles[@]}"; do
  case "$profile" in
    local)
      run_h1_profile "$profile" 30 10 5
      run_h2_profile "$profile" 30 10 3
      ;;
    good-network)
      run_h1_profile "$profile" 30 5 3
      run_h2_profile "$profile" 30 5 2
      ;;
    typical-mobile)
      run_h1_profile "$profile" 30 3 2
      run_h2_profile "$profile" 30 3 1
      ;;
    poor-mobile)
      # The poor profile keeps the request/concurrency comparison at 30
      # samples. Large transfers are intentionally limited to one sample per
      # protocol path because 100 MB at the constrained rate is long.
      run_h1_profile "$profile" 30 2 1
      run_h2_profile "$profile" 30 2 1
      ;;
    *)
      printf 'Unknown profile: %s\n' "$profile" >&2
      exit 2
      ;;
  esac
done

printf 'Linux final decision results written under %s.\n' "$output_directory"
