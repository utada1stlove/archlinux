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
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SYSTEMD_SERVICE_NAME="clouddrive-autofs.service"
SYSTEMD_TIMER_NAME="clouddrive-autofs.timer"

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

systemd_install() {
  local service_src="$SCRIPT_DIR/systemd/$SYSTEMD_SERVICE_NAME"
  local timer_src="$SCRIPT_DIR/systemd/$SYSTEMD_TIMER_NAME"

  require_cmd systemctl

  if [[ ! -f "$service_src" || ! -f "$timer_src" ]]; then
    log "Missing systemd templates under $SCRIPT_DIR/systemd"
    return 1
  fi

  mkdir -p "$SYSTEMD_USER_DIR"
  cp "$service_src" "$SYSTEMD_USER_DIR/$SYSTEMD_SERVICE_NAME"
  cp "$timer_src" "$SYSTEMD_USER_DIR/$SYSTEMD_TIMER_NAME"
  systemctl --user daemon-reload
  log "Installed systemd user units to $SYSTEMD_USER_DIR"
}

systemd_enable() {
  require_cmd systemctl
  systemctl --user enable --now "$SYSTEMD_TIMER_NAME"
  log "Enabled and started: $SYSTEMD_TIMER_NAME"
}

systemd_disable() {
  require_cmd systemctl
  if systemctl --user disable --now "$SYSTEMD_TIMER_NAME" >/dev/null 2>&1; then
    log "Disabled and stopped: $SYSTEMD_TIMER_NAME"
  else
    log "Timer already disabled or not installed: $SYSTEMD_TIMER_NAME"
  fi
  systemctl --user stop "$SYSTEMD_SERVICE_NAME" >/dev/null 2>&1 || true
}

systemd_uninstall() {
  local removed=0
  local service_dst="$SYSTEMD_USER_DIR/$SYSTEMD_SERVICE_NAME"
  local timer_dst="$SYSTEMD_USER_DIR/$SYSTEMD_TIMER_NAME"

  require_cmd systemctl
  systemd_disable

  if [[ -f "$service_dst" ]]; then
    rm -f "$service_dst"
    removed=1
  fi
  if [[ -f "$timer_dst" ]]; then
    rm -f "$timer_dst"
    removed=1
  fi

  systemctl --user daemon-reload
  systemctl --user reset-failed >/dev/null 2>&1 || true

  if [[ "$removed" -eq 1 ]]; then
    log "Removed systemd user units from $SYSTEMD_USER_DIR"
  else
    log "No systemd user units to remove in $SYSTEMD_USER_DIR"
  fi
}

systemd_status() {
  local enabled="not-found"
  local active="not-found"
  local service_file="NO"
  local timer_file="NO"

  require_cmd systemctl

  if [[ -f "$SYSTEMD_USER_DIR/$SYSTEMD_SERVICE_NAME" ]]; then
    service_file="YES"
  fi
  if [[ -f "$SYSTEMD_USER_DIR/$SYSTEMD_TIMER_NAME" ]]; then
    timer_file="YES"
  fi

  enabled="$(systemctl --user is-enabled "$SYSTEMD_TIMER_NAME" 2>/dev/null || true)"
  active="$(systemctl --user is-active "$SYSTEMD_TIMER_NAME" 2>/dev/null || true)"

  echo "SYSTEMD_USER_DIR=$SYSTEMD_USER_DIR"
  echo "SERVICE_FILE=$service_file"
  echo "TIMER_FILE=$timer_file"
  echo "TIMER_ENABLED=${enabled:-not-found}"
  echo "TIMER_ACTIVE=${active:-not-found}"
}

panel_print_menu() {
  cat <<MENU

======== CloudDrive CLI Panel ========
1) Show status
2) Run auto reconcile once
3) Force mount
4) Force unmount
5) systemd install units
6) systemd enable timer
7) systemd disable timer
8) systemd uninstall units
9) systemd status
10) Show last 50 lines of rclone log
11) Show last 50 lines of systemd service log
0) Exit
=====================================
MENU
}

panel_run_action() {
  local choice="$1"
  case "$choice" in
    1) status ;;
    2) require_cmd rclone; reconcile_once ;;
    3) require_cmd rclone; mount_cloudrive ;;
    4) require_cmd rclone; unmount_cloudrive ;;
    5) systemd_install ;;
    6) systemd_enable ;;
    7) systemd_disable ;;
    8) systemd_uninstall ;;
    9) systemd_status ;;
    10)
      if [[ -f "$LOG_FILE" ]]; then
        tail -n 50 "$LOG_FILE"
      else
        echo "Log file not found: $LOG_FILE"
      fi
      ;;
    11)
      require_cmd journalctl
      journalctl --user -u "$SYSTEMD_SERVICE_NAME" -n 50 --no-pager
      ;;
    *)
      echo "Unknown option: $choice"
      return 1
      ;;
  esac
}

panel() {
  local choice=""
  local rc=0

  while true; do
    panel_print_menu
    read -r -p "Choose [0-11]: " choice || break

    if [[ "$choice" == "0" ]]; then
      echo "Bye."
      break
    fi

    set +e
    panel_run_action "$choice"
    rc=$?
    set -e

    if [[ "$rc" -ne 0 ]]; then
      echo "Action failed (exit=$rc)"
    fi

    read -r -p "Press Enter to continue..." _
  done
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [status|run-once|watch|mount|unmount|systemd-install|systemd-enable|systemd-disable|systemd-uninstall|systemd-status|panel]

Commands:
  status    Show endpoint and mount status
  run-once  Check endpoint once, then mount/unmount accordingly (default)
  watch     Keep checking every CHECK_INTERVAL_SEC
  mount     Force mount now
  unmount   Force unmount now
  systemd-install    Install user service/timer to ~/.config/systemd/user
  systemd-enable     Enable and start timer
  systemd-disable    Disable and stop timer
  systemd-uninstall  Disable timer and remove unit files
  systemd-status     Show timer enabled/active status
  panel              Interactive command-line control panel
USAGE
}

main() {
  local cmd="${1:-run-once}"

  case "$cmd" in
    status)
      status
      ;;
    run-once)
      require_cmd rclone
      reconcile_once
      ;;
    watch)
      require_cmd rclone
      watch_loop
      ;;
    mount)
      require_cmd rclone
      mount_cloudrive
      ;;
    unmount)
      require_cmd rclone
      unmount_cloudrive
      ;;
    systemd-install)
      systemd_install
      ;;
    systemd-enable)
      systemd_enable
      ;;
    systemd-disable)
      systemd_disable
      ;;
    systemd-uninstall)
      systemd_uninstall
      ;;
    systemd-status)
      systemd_status
      ;;
    panel)
      panel
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
