#!/usr/bin/env bash
set -euo pipefail

# This helper documents macOS packet impairment commands without applying them
# automatically. Applying dummynet rules changes host networking and requires
# administrator privileges; callers must explicitly run `apply` and then `reset`.

profile="${2:-local}"
pipe_id="${ALPHAX_DNCTL_PIPE_ID:-101}"
anchor="${ALPHAX_PF_ANCHOR:-alphax-phase0}"
port="${ALPHAX_BENCHMARK_PORT:-8080}"

usage() {
  printf '%s\n' \
    'Usage:' \
    '  network-profile.sh describe PROFILE' \
    '  network-profile.sh apply PROFILE' \
    '  network-profile.sh reset'
}

describe() {
  case "$1" in
    local)
      printf '%s\n' 'local: no impairment; do not install dummynet rules.' ;;
    good-network)
      printf '%s\n' 'good-network: 30 ms one-way delay (approximately 60 ms RTT), 100 Mbps, no loss.' ;;
    typical-mobile)
      printf '%s\n' 'typical-mobile: 50 ms one-way delay (approximately 100 ms RTT), 10 Mbps, 0.5% loss.' ;;
    poor-mobile)
      printf '%s\n' 'poor-mobile: 150 ms one-way delay (approximately 300 ms RTT), 1 Mbps, 2% loss.' ;;
    *)
      printf 'unknown profile: %s\n' "$1" >&2
      return 2 ;;
  esac
}

reset() {
  sudo dnctl pipe "$pipe_id" delete 2>/dev/null || true
  sudo pfctl -a "$anchor" -F all 2>/dev/null || true
  sudo pfctl -a "$anchor" -d 2>/dev/null || true
  printf 'Reset attempted for dummynet pipe %s and pf anchor %s.\n' "$pipe_id" "$anchor"
}

apply_profile() {
  local selected="$1"
  if [[ "$selected" == local ]]; then
    reset
    return
  fi
  local delay bandwidth loss
  case "$selected" in
    good-network) delay='30ms'; bandwidth='100Mbit/s'; loss='0' ;;
    typical-mobile) delay='50ms'; bandwidth='10Mbit/s'; loss='0.005' ;;
    poor-mobile) delay='150ms'; bandwidth='1Mbit/s'; loss='0.02' ;;
    *) describe "$selected" ;;
  esac
  sudo dnctl pipe "$pipe_id" config delay "$delay" bw "$bandwidth" plr "$loss"
  sudo pfctl -a "$anchor" -f - <<EOF
dummynet out proto tcp from any to any port $port pipe $pipe_id
dummynet in proto tcp from any to any port $port pipe $pipe_id
EOF
  printf 'Applied %s to TCP port %s through dummynet pipe %s.\n' "$selected" "$port" "$pipe_id"
  printf 'Run this exact cleanup when finished: %s reset\n' "$0"
}

case "${1:-}" in
  describe) describe "$profile" ;;
  apply) apply_profile "$profile" ;;
  reset) reset ;;
  *) usage; exit 2 ;;
esac
