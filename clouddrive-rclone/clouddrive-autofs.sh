#!/usr/bin/env bash
set -euo pipefail

resolve_script_path() {
  local src="${BASH_SOURCE[0]}"
  local dir=""

  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done

  printf '%s\n' "$(cd -P "$(dirname "$src")" && pwd)/$(basename "$src")"
}

SCRIPT_PATH="$(resolve_script_path)"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PROFILE_DIR="$SCRIPT_DIR/profiles"
DEFAULT_PROFILE_NAME="clouddrive"
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/config.env"
CONFIG_FILE="${CLOUDRIVE_CONFIG:-}"
ACTIVE_PROFILE="${CLOUDRIVE_PROFILE:-$DEFAULT_PROFILE_NAME}"
ACTIVE_PROFILE_SOURCE="default"
CONFIG_FILE_FOUND="NO"
CONFIG_READY="YES"
CONFIG_ERROR=""

# Defaults (can be overridden in config files)
TARGET_HOST="192.168.100.1"
TARGET_PORT="19798"
RCLONE_REMOTE="cloudrive:"
MOUNT_POINT="$HOME/CloudDrive"
CHECK_INTERVAL_SEC="20"
CONNECT_TIMEOUT_SEC="2"
LOG_FILE="$HOME/.cache/rclone-clouddrive.log"
RCLONE_EXTRA_ARGS="--vfs-cache-mode full --dir-cache-time 10m"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SYSTEMD_UNIT_PREFIX="clouddrive-autofs"
SYSTEMD_SERVICE_NAME=""
SYSTEMD_TIMER_NAME=""

COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[1;36m'
COLOR_BLUE=$'\033[1;34m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_GREEN=$'\033[1;32m'

clear_screen() {
  printf '\033[2J\033[H'
}

profile_slug() {
  local value="${1:-$DEFAULT_PROFILE_NAME}"
  local slug="${value,,}"
  slug="${slug//[^[:alnum:]._-]/-}"
  slug="${slug#-}"
  slug="${slug%-}"
  printf '%s\n' "${slug:-$DEFAULT_PROFILE_NAME}"
}

profile_config_path() {
  local profile="${1:-$DEFAULT_PROFILE_NAME}"

  if [[ "$profile" == "$DEFAULT_PROFILE_NAME" || "$profile" == "default" ]]; then
    printf '%s\n' "$DEFAULT_CONFIG_FILE"
  else
    printf '%s\n' "$PROFILE_DIR/$profile.env"
  fi
}

discover_profiles() {
  local file=""
  local name=""

  printf '%s\n' "$DEFAULT_PROFILE_NAME"
  if [[ -d "$PROFILE_DIR" ]]; then
    while IFS= read -r -d '' file; do
      name="$(basename "$file" .env)"
      [[ -n "$name" && "$name" != "$DEFAULT_PROFILE_NAME" && "$name" != "default" ]] && printf '%s\n' "$name"
    done < <(find "$PROFILE_DIR" -maxdepth 1 -type f -name '*.env' -print0 | sort -z)
  fi
}

resolve_active_config() {
  local requested_profile="${CLOUDRIVE_PROFILE:-}"
  local slug=""

  if [[ -n "$CONFIG_FILE" ]]; then
    ACTIVE_PROFILE_SOURCE="custom-config"
    if [[ -n "$requested_profile" ]]; then
      ACTIVE_PROFILE="$requested_profile"
    else
      ACTIVE_PROFILE="$(basename "$CONFIG_FILE")"
      ACTIVE_PROFILE="${ACTIVE_PROFILE%.env}"
      [[ -z "$ACTIVE_PROFILE" ]] && ACTIVE_PROFILE="custom"
    fi
  elif [[ -n "$requested_profile" && "$requested_profile" != "$DEFAULT_PROFILE_NAME" && "$requested_profile" != "default" ]]; then
    ACTIVE_PROFILE="$requested_profile"
    ACTIVE_PROFILE_SOURCE="profile"
    CONFIG_FILE="$(profile_config_path "$ACTIVE_PROFILE")"
  else
    ACTIVE_PROFILE="$DEFAULT_PROFILE_NAME"
    ACTIVE_PROFILE_SOURCE="default"
    CONFIG_FILE="$DEFAULT_CONFIG_FILE"
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    CONFIG_FILE_FOUND="YES"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  elif [[ "$ACTIVE_PROFILE_SOURCE" != "default" ]]; then
    CONFIG_READY="NO"
    CONFIG_ERROR="Config file not found for profile '${ACTIVE_PROFILE}': ${CONFIG_FILE}"
  fi

  slug="$(profile_slug "$ACTIVE_PROFILE")"
  if [[ "$slug" == "$(profile_slug "$DEFAULT_PROFILE_NAME")" ]]; then
    SYSTEMD_UNIT_PREFIX="clouddrive-autofs"
  else
    SYSTEMD_UNIT_PREFIX="clouddrive-autofs-$slug"
  fi
  SYSTEMD_SERVICE_NAME="${SYSTEMD_UNIT_PREFIX}.service"
  SYSTEMD_TIMER_NAME="${SYSTEMD_UNIT_PREFIX}.timer"
}

panel_print_banner() {
  cat <<EOF
${COLOR_CYAN} __        __   _     ____     ___     __     __ ${COLOR_RESET}
${COLOR_CYAN} \ \      / /__| |__ |  _ \   / \ \   / /__ _/ _|${COLOR_RESET}
${COLOR_CYAN}  \ \ /\ / / _ \ '_ \| | | | / _ \ \ / / _ \ |_ ${COLOR_RESET}
${COLOR_CYAN}   \ V  V /  __/ |_) | |_| |/ ___ \ V /  __/  _|${COLOR_RESET}
${COLOR_CYAN}    \_/\_/ \___|_.__/|____//_/   \_\_/ \___|_|  ${COLOR_RESET}
${COLOR_BLUE}========================= WebDAV Mount Panel ==========================${COLOR_RESET}
EOF
  echo -e "${COLOR_YELLOW}Profile:${COLOR_RESET} ${ACTIVE_PROFILE}    ${COLOR_YELLOW}Config:${COLOR_RESET} ${CONFIG_FILE}"
}

resolve_active_config

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_config_ready() {
  if [[ "$CONFIG_READY" != "YES" ]]; then
    echo "$CONFIG_ERROR" >&2
    return 1
  fi
}

log() {
  printf "[%s] %s\n" "$(date '+%F %T')" "$1"
}

profile_summary() {
  local profile="$1"
  local file=""

  file="$(profile_config_path "$profile")"
  if [[ ! -f "$file" ]]; then
    if [[ "$profile" == "$DEFAULT_PROFILE_NAME" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$profile" "$file" "$RCLONE_REMOTE" "$MOUNT_POINT" "$TARGET_HOST" "$TARGET_PORT"
    fi
    return 0
  fi

  (
    set +u
    # shellcheck disable=SC1090
    source "$file"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$profile" \
      "$file" \
      "${RCLONE_REMOTE:-}" \
      "${MOUNT_POINT:-}" \
      "${TARGET_HOST:-}" \
      "${TARGET_PORT:-}"
  )
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

mount_webdav() {
  local -a extra
  local -a cmd

  require_config_ready

  if is_mounted; then
    log "Already mounted: $MOUNT_POINT"
    return 0
  fi

  mkdir -p "$MOUNT_POINT"
  mkdir -p "$(dirname "$LOG_FILE")"

  read -r -a extra <<<"$RCLONE_EXTRA_ARGS"
  cmd=(
    rclone
    mount
    "$RCLONE_REMOTE"
    "$MOUNT_POINT"
    --daemon
    --daemon-timeout
    20s
    --log-file
    "$LOG_FILE"
    --log-level
    INFO
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

unmount_webdav() {
  require_config_ready

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

  require_config_ready

  if is_endpoint_reachable; then
    endpoint="UP"
  fi

  if is_mounted; then
    mounted="YES"
    fs="$(mount_fstype)"
  fi

  echo "PROFILE=$ACTIVE_PROFILE"
  echo "PROFILE_SOURCE=$ACTIVE_PROFILE_SOURCE"
  echo "CONFIG_FILE=$CONFIG_FILE"
  echo "CONFIG_FILE_FOUND=$CONFIG_FILE_FOUND"
  echo "TARGET_HOST=$TARGET_HOST"
  echo "TARGET_PORT=$TARGET_PORT"
  echo "RCLONE_REMOTE=$RCLONE_REMOTE"
  echo "MOUNT_POINT=$MOUNT_POINT"
  echo "SYSTEMD_SERVICE_NAME=$SYSTEMD_SERVICE_NAME"
  echo "SYSTEMD_TIMER_NAME=$SYSTEMD_TIMER_NAME"
  echo "ENDPOINT=$endpoint"
  echo "MOUNTED=$mounted"
  if [[ -n "$fs" ]]; then
    echo "FSTYPE=$fs"
  fi
}

reconcile_once() {
  require_config_ready

  if is_endpoint_reachable; then
    log "Endpoint ${TARGET_HOST}:${TARGET_PORT} reachable."
    mount_webdav
  else
    log "Endpoint ${TARGET_HOST}:${TARGET_PORT} unreachable."
    unmount_webdav || true
  fi
}

watch_loop() {
  require_config_ready
  log "Starting watch loop, interval=${CHECK_INTERVAL_SEC}s"
  while true; do
    reconcile_once
    sleep "$CHECK_INTERVAL_SEC"
  done
}

systemd_install() {
  local service_dst="$SYSTEMD_USER_DIR/$SYSTEMD_SERVICE_NAME"
  local timer_dst="$SYSTEMD_USER_DIR/$SYSTEMD_TIMER_NAME"

  require_config_ready
  require_cmd systemctl

  mkdir -p "$SYSTEMD_USER_DIR"

  cat > "$service_dst" <<EOF
[Unit]
Description=WebDAV rclone auto mount/unmount (${ACTIVE_PROFILE})
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
KillMode=none
EOF

  if [[ "$ACTIVE_PROFILE_SOURCE" == "custom-config" ]]; then
    printf 'Environment=CLOUDRIVE_CONFIG=%s\n' "$CONFIG_FILE" >> "$service_dst"
  else
    printf 'Environment=CLOUDRIVE_PROFILE=%s\n' "$ACTIVE_PROFILE" >> "$service_dst"
  fi

  cat >> "$service_dst" <<EOF
ExecStart=$SCRIPT_PATH run-once
EOF

  cat > "$timer_dst" <<EOF
[Unit]
Description=Run WebDAV rclone auto mount/unmount periodically (${ACTIVE_PROFILE})

[Timer]
OnBootSec=${CHECK_INTERVAL_SEC}s
OnUnitActiveSec=${CHECK_INTERVAL_SEC}s
AccuracySec=1s
Unit=$SYSTEMD_SERVICE_NAME

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  log "Installed systemd user units to $SYSTEMD_USER_DIR for profile ${ACTIVE_PROFILE}"
}

systemd_enable() {
  require_config_ready
  require_cmd systemctl
  systemctl --user enable --now "$SYSTEMD_TIMER_NAME"
  log "Enabled and started: $SYSTEMD_TIMER_NAME"
}

systemd_disable() {
  require_config_ready
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

  require_config_ready
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

  require_config_ready
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

list_profiles() {
  local mode="${1:-pretty}"
  local -a profiles=()
  local profile=""
  local line=""

  while IFS= read -r profile; do
    profiles+=("$profile")
  done < <(discover_profiles)

  if [[ "$mode" == "--plain" ]]; then
    printf '%s\n' "${profiles[@]}"
    return 0
  fi

  for profile in "${profiles[@]}"; do
    line="$(profile_summary "$profile")"
    if [[ -z "$line" ]]; then
      continue
    fi

    IFS=$'\t' read -r profile _ remote mount host port <<<"$line"
    printf '%-12s remote=%-18s mount=%-28s endpoint=%s:%s\n' \
      "$profile" \
      "${remote:-<unset>}" \
      "${mount:-<unset>}" \
      "${host:-<unset>}" \
      "${port:-<unset>}"
  done
}

panel_print_menu() {
  cat <<MENU

========= WebDAV CLI Panel =========
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
12) List available profiles
0) Exit
===================================
MENU
}

panel_run_action() {
  local choice="$1"
  case "$choice" in
    1) status ;;
    2) require_cmd rclone; reconcile_once ;;
    3) require_cmd rclone; mount_webdav ;;
    4) require_cmd rclone; unmount_webdav ;;
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
    12)
      list_profiles
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
    clear_screen
    panel_print_banner
    panel_print_menu
    read -r -p "Choose [0-12]: " choice || break

    if [[ "$choice" == "0" ]]; then
      clear_screen
      panel_print_banner
      echo -e "${COLOR_GREEN}Bye.${COLOR_RESET}"
      break
    fi

    clear_screen
    panel_print_banner
    echo -e "${COLOR_YELLOW}Running action: ${choice}${COLOR_RESET}"
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
Usage: $(basename "$0") [status|run-once|watch|mount|unmount|systemd-install|systemd-enable|systemd-disable|systemd-uninstall|systemd-status|profiles|panel]

Commands:
  status            Show endpoint and mount status
  run-once          Check endpoint once, then mount/unmount accordingly (default)
  watch             Keep checking every CHECK_INTERVAL_SEC
  mount             Force mount now
  unmount           Force unmount now
  systemd-install   Install user service/timer to ~/.config/systemd/user
  systemd-enable    Enable and start timer
  systemd-disable   Disable and stop timer
  systemd-uninstall Disable timer and remove unit files
  systemd-status    Show timer enabled/active status
  profiles          List available config profiles
  panel             Interactive command-line control panel

Environment:
  CLOUDRIVE_PROFILE Use named profile from $PROFILE_DIR/<name>.env
  CLOUDRIVE_CONFIG  Use a specific config file path
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
      mount_webdav
      ;;
    unmount)
      unmount_webdav
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
    profiles)
      list_profiles "${2:-pretty}"
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
