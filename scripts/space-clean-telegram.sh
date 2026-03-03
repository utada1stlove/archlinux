#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "\n[+] %s\n" "$1"
}

is_mount_point() {
  local path="$1"
  local target=""
  local norm_path="${path%/}"
  [[ -n "$norm_path" ]] || norm_path="/"

  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "$path"
    return $?
  fi
  if command -v findmnt >/dev/null 2>&1; then
    target="$(findmnt -rn -o TARGET -T "$path" 2>/dev/null | head -n 1 || true)"
    target="${target%/}"
    [[ -n "$target" ]] || target="/"
    [[ "$target" == "$norm_path" ]]
    return $?
  fi
  return 1
}

clear_dir_contents() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  [[ "$dir" != "/" ]] || return 0

  if [[ -L "$dir" ]]; then
    log "Skipping symlink directory: $dir"
    return 0
  fi
  if is_mount_point "$dir"; then
    log "Skipping mounted directory: $dir"
    return 0
  fi

  shopt -s dotglob nullglob
  rm -rf -- "$dir"/* 2>/dev/null || true
  shopt -u dotglob nullglob
}

cleanup_telegram_tdata() {
  local base="$1"
  local target

  [[ -d "$base" ]] || return 0

  shopt -s nullglob
  for target in \
    "$base"/user_data/cache \
    "$base"/user_data/media_cache \
    "$base"/user_data#*/cache \
    "$base"/user_data#*/media_cache \
    "$base"/temp_data \
    "$base"/temp_data#* \
    "$base"/emoji
  do
    clear_dir_contents "$target"
  done
  shopt -u nullglob
}

show_size_if_exists() {
  local path="$1"
  local label="$2"
  if [[ -d "$path" ]]; then
    printf "%-42s %s\n" "$label" "$(du -sh "$path" 2>/dev/null | awk '{print $1}')"
  else
    printf "%-42s %s\n" "$label" "(not found)"
  fi
}

main() {
  local flatpak_tdata="$HOME/.var/app/org.telegram.desktop/data/TelegramDesktop/tdata"
  local native_tdata="$HOME/.local/share/TelegramDesktop/tdata"

  log "Stopping Telegram process"
  if command -v flatpak >/dev/null 2>&1; then
    flatpak kill org.telegram.desktop >/dev/null 2>&1 || true
  fi
  pkill -f '[T]elegram' >/dev/null 2>&1 || true

  log "Before cleanup"
  show_size_if_exists "$flatpak_tdata" "Flatpak Telegram tdata"
  show_size_if_exists "$native_tdata" "Native Telegram tdata"

  log "Cleaning Telegram cache/media cache"
  cleanup_telegram_tdata "$flatpak_tdata"
  cleanup_telegram_tdata "$native_tdata"

  log "After cleanup"
  show_size_if_exists "$flatpak_tdata" "Flatpak Telegram tdata"
  show_size_if_exists "$native_tdata" "Native Telegram tdata"
  log "Done. Spotify data remains untouched."
}

main "$@"
