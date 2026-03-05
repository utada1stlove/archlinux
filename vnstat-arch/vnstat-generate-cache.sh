#!/usr/bin/env bash
set -euo pipefail

IFACE="${VNSTAT_IFACE:-wlan0}"
CACHE_DIR="${VNSTAT_CACHE_DIR:-$HOME/.cache/vnstat-arch}"

log() {
  printf "[%s] %s\n" "$(date '+%F %T')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

generate_if_missing() {
  local mode="$1"
  local out_file="$2"
  local tmp_file="${out_file%.png}.tmp.$$.png"

  if [[ -e "$out_file" ]]; then
    log "Skip existing: $out_file"
    return 0
  fi

  if vnstati -i "$IFACE" "$mode" -o "$tmp_file"; then
    mv "$tmp_file" "$out_file"
    log "Generated: $out_file"
    return 0
  fi

  rm -f "$tmp_file"
  log "Failed to generate: mode=$mode file=$out_file"
  return 1
}

main() {
  local ym
  local ymd
  local ymdh
  local status=0

  require_cmd vnstati

  mkdir -p "$CACHE_DIR"

  ym="$(date '+%y-%m')"
  ymd="$(date '+%y-%m-%d')"
  ymdh="$(date '+%y-%m-%d-%H')"

  generate_if_missing -m "$CACHE_DIR/month${ym}.png" || status=1
  generate_if_missing -d "$CACHE_DIR/day${ymd}.png" || status=1
  generate_if_missing -h "$CACHE_DIR/hour${ymdh}.png" || status=1

  return "$status"
}

main "$@"
