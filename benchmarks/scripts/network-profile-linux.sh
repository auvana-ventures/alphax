#!/usr/bin/env bash
set -euo pipefail

profile_command="${1:-}"
profile="${2:-local}"
interface="${ALPHAX_NETEM_INTERFACE:-}"

usage() {
  printf '%s\n' \
    'Usage:' \
    '  network-profile-linux.sh describe PROFILE' \
    '  ALPHAX_NETEM_INTERFACE=INTERFACE network-profile-linux.sh apply PROFILE' \
    '  ALPHAX_NETEM_INTERFACE=INTERFACE network-profile-linux.sh reset'
}

describe() {
  case "$1" in
    local) printf '%s\n' 'local: no impairment.' ;;
    good-network) printf '%s\n' 'good-network: 15 ms one-way delay on each endpoint (~30 ms RTT), 100 Mbit/s, no loss.' ;;
    typical-mobile) printf '%s\n' 'typical-mobile: 50 ms one-way delay on each endpoint (~100 ms RTT), 10 Mbit/s, 0.5% loss.' ;;
    poor-mobile) printf '%s\n' 'poor-mobile: 150 ms one-way delay on each endpoint (~300 ms RTT), 5 Mbit/s, 2% loss.' ;;
    *) printf 'unknown profile: %s\n' "$1" >&2; return 2 ;;
  esac
}

require_interface() {
  if [[ -z "$interface" ]]; then
    printf 'Set ALPHAX_NETEM_INTERFACE to the isolated benchmark interface.\n' >&2
    exit 2
  fi
  if ! command -v tc >/dev/null 2>&1; then
    printf 'tc is unavailable; run this path in a Linux environment with iproute2.\n' >&2
    exit 2
  fi
}

run_tc() {
  if [[ "$(id -u)" -eq 0 ]]; then
    tc "$@"
  else
    sudo tc "$@"
  fi
}

reset() {
  require_interface
  run_tc qdisc del dev "$interface" root 2>/dev/null || true
  printf 'Removed the root qdisc from %s.\n' "$interface"
}

apply_profile() {
  require_interface
  local delay bandwidth loss
  case "$1" in
    local) reset; return ;;
    # Apply the profile to both isolated endpoints for an approximate RTT of
    # twice this one-way delay.
    good-network) delay='15ms'; bandwidth='100mbit'; loss='0%' ;;
    typical-mobile) delay='50ms'; bandwidth='10mbit'; loss='0.5%' ;;
    poor-mobile) delay='150ms'; bandwidth='5mbit'; loss='2%' ;;
    *) describe "$1"; return 2 ;;
  esac

  # netem applies delay, loss, and the rate ceiling on the isolated endpoint.
  # Run this on both client and server endpoints to approximate symmetric RTT.
  run_tc qdisc replace dev "$interface" root netem \
    delay "$delay" loss "$loss" rate "$bandwidth" limit 10000
  printf 'Applied %s to %s (one-way delay %s). Always run %s reset afterwards.\n' \
    "$1" "$interface" "$delay" "$0"
}

case "$profile_command" in
  describe) describe "$profile" ;;
  apply) apply_profile "$profile" ;;
  reset) reset ;;
  *) usage; exit 2 ;;
esac
