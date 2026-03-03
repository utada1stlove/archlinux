#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CLOUDRIVE_CONFIG:-$SCRIPT_DIR/config.env}"

# Defaults (can be overridden in config.env)
TARGET_HOST="192.168.100.1"
TARGET_PORT="19798"
RCLONE_REMOTE="cloudrive:"
MOUNT_POINT="$HOME/CloudDrive"
CHECK_INTERVAL_SEC="20"
CONNECT_TIMEOUT_SEC="2"
LOG_FILE="$HOME/.cache/rclone-clouddrive.log"
RCLONE_EXTRA_ARGS="--vfs-cache-mode full --dir-cache-time 10m"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

log() {
  printf "[%s] %s\n" "$(date '+%F %T')" "$1"
}

mount_fstype() {
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -n -o FSTYPE -T "$MOUNT_POINT" 2>/dev/null || true
  else
    echo ""
  fi
}

is_mounted() {
  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "$MOUNT_POINT"
    return $?
  fi
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -T "$MOUNT_POINT" >/dev/null 2>&1
    return $?
  fi
  return 1
}

is_rclone_mount() {
  local fs
  fs="$(mount_fstype)"
  [[ "$fs" == "fuse.rclone" || "$fs" == "rclone" || "$fs" == fuse* ]]
}

is_endpoint_reachable() {
  if command -v nc >/dev/null 2>&1; then
    nc -z -w "$CONNECT_TIMEOUT_SEC" "$TARGET_HOST" "$TARGET_PORT" >/dev/null 2>&1
    return $?
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "$CONNECT_TIMEOUT_SEC" bash -c "exec 3<>/dev/tcp/${TARGET_HOST}/${TARGET_PORT}" >/dev/null 2>&1
    return $?
  fi

  return 1
}

mount_cloudrive() {
  local -a extra
  local -a cmd

  if is_mounted; then
    log "Already mounted: $MOUNT_POINT"
    return 0
  fi

  mkdir -p "$MOUNT_POINT"
  mkdir -p "$(dirname "$LOG_FILE")"

  read -r -a extra <<<"$RCLONE_EXTRA_ARGS"
  cmd=(
    rclone mount "$RCLONE_REMOTE" "$MOUNT_POINT"
    --daemon
    --daemon-timeout 20s
    --log-file "$LOG_FILE"
    --log-level INFO
  )

  if [[ "${#extra[@]}" -gt 0 ]]; then
    cmd+=("${extra[@]}")
  fi

  "${cmd[@]}"
  sleep 1

  if is_mounted; then
    log "Mounted: $RCLONE_REMOTE -> $MOUNT_POINT"
  else
    log "Mount failed. Check log: $LOG_FILE"
    return 1
  fi
}

unmount_cloudrive() {
  if ! is_mounted; then
    log "Already unmounted: $MOUNT_POINT"
    return 0
  fi

  if ! is_rclone_mount; then
    log "Mounted but not recognized as rclone mount, skip unmount: $MOUNT_POINT"
    return 1
  fi

  if command -v fusermount >/dev/null 2>&1; then
    fusermount -u "$MOUNT_POINT" && log "Unmounted via fusermount: $MOUNT_POINT" && return 0
  fi

  if command -v umount >/dev/null 2>&1; then
    umount "$MOUNT_POINT" && log "Unmounted via umount: $MOUNT_POINT" && return 0
  fi

  log "Unmount failed: no usable unmount command"
  return 1
}

status() {
  local endpoint="DOWN"
  local mounted="NO"
  local fs=""

  if is_endpoint_reachable; then
    endpoint="UP"
  fi

  if is_mounted; then
    mounted="YES"
    fs="$(mount_fstype)"
  fi

  echo "TARGET_HOST=$TARGET_HOST"
  echo "TARGET_PORT=$TARGET_PORT"
  echo "RCLONE_REMOTE=$RCLONE_REMOTE"
  echo "MOUNT_POINT=$MOUNT_POINT"
  echo "ENDPOINT=$endpoint"
  echo "MOUNTED=$mounted"
  if [[ -n "$fs" ]]; then
    echo "FSTYPE=$fs"
  fi
}

reconcile_once() {
  if is_endpoint_reachable; then
    log "Endpoint ${TARGET_HOST}:${TARGET_PORT} reachable."
    mount_cloudrive
  else
    log "Endpoint ${TARGET_HOST}:${TARGET_PORT} unreachable."
    unmount_cloudrive || true
  fi
}

watch_loop() {
  log "Starting watch loop, interval=${CHECK_INTERVAL_SEC}s"
  while true; do
    reconcile_once
    sleep "$CHECK_INTERVAL_SEC"
  done
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [status|run-once|watch|mount|unmount]

Commands:
  status    Show endpoint and mount status
  run-once  Check endpoint once, then mount/unmount accordingly (default)
  watch     Keep checking every CHECK_INTERVAL_SEC
  mount     Force mount now
  unmount   Force unmount now
USAGE
}

main() {
  local cmd="${1:-run-once}"
  require_cmd rclone

  case "$cmd" in
    status)
      status
      ;;
    run-once)
      reconcile_once
      ;;
    watch)
      watch_loop
      ;;
    mount)
      mount_cloudrive
      ;;
    unmount)
      unmount_cloudrive
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
