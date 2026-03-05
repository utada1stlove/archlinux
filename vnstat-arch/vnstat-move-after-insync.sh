#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${VNSTAT_CACHE_DIR:-$HOME/.cache/vnstat-arch}"
TARGET_DIR="${VNSTAT_TARGET_DIR:-/home/aerith/Insync/innovationqvq@hotmail.com/OneDrive/vnstat-arch}"
WAIT_TIMEOUT_SEC="${INSYNC_WAIT_TIMEOUT_SEC:-1800}"
POLL_INTERVAL_SEC="${INSYNC_POLL_INTERVAL_SEC:-5}"

log() {
  printf "[%s] %s\n" "$(date '+%F %T')" "$*"
}

is_insync_running() {
  pgrep -x insync >/dev/null 2>&1
}

wait_for_insync() {
  local waited=0

  if is_insync_running; then
    log "Insync is already running."
    return 0
  fi

  log "Waiting for Insync process..."
  while ! is_insync_running; do
    if (( waited >= WAIT_TIMEOUT_SEC )); then
      log "Insync not detected within ${WAIT_TIMEOUT_SEC}s, skip this run."
      return 1
    fi

    sleep "$POLL_INTERVAL_SEC"
    waited=$((waited + POLL_INTERVAL_SEC))
  done

  log "Insync detected after ${waited}s."
  return 0
}

is_expected_file() {
  case "$1" in
    month[0-9][0-9]-[0-9][0-9].png) return 0 ;;
    day[0-9][0-9]-[0-9][0-9]-[0-9][0-9].png) return 0 ;;
    hour[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9].png) return 0 ;;
    *) return 1 ;;
  esac
}

move_cached_images() {
  local src
  local base
  local dst
  local moved=0
  local skipped_existing=0

  mkdir -p "$CACHE_DIR"
  mkdir -p "$TARGET_DIR"

  shopt -s nullglob
  for src in "$CACHE_DIR"/*.png; do
    base="$(basename "$src")"

    if ! is_expected_file "$base"; then
      continue
    fi

    dst="$TARGET_DIR/$base"
    if [[ -e "$dst" ]]; then
      log "Skip existing target: $dst"
      skipped_existing=$((skipped_existing + 1))
      continue
    fi

    mv "$src" "$dst"
    log "Moved: $src -> $dst"
    moved=$((moved + 1))
  done
  shopt -u nullglob

  log "Move completed. moved=${moved}, skipped_existing=${skipped_existing}"
}

main() {
  if wait_for_insync; then
    move_cached_images
  fi
}

main "$@"
