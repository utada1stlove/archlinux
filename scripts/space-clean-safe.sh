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

safe_clear_dir_contents() {
  local dir="$1"
  local item

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
  for item in "$dir"/*; do
    if is_mount_point "$item"; then
      log "Skipping mount point: $item"
      continue
    fi
    rm -rf -- "$item" 2>/dev/null || true
  done
  shopt -u dotglob nullglob
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    exit 1
  fi
}

clean_pacman_cache() {
  if command -v paccache >/dev/null 2>&1; then
    log "Cleaning pacman cache (keep latest 2 versions)"
    sudo paccache -rk 2
    log "Removing cache of uninstalled packages"
    sudo paccache -ruk 0
  else
    log "paccache not found, fallback to pacman -Sc"
    sudo pacman -Sc --noconfirm
  fi
}

clean_journal() {
  if command -v journalctl >/dev/null 2>&1; then
    log "Cleaning journal logs older than 14 days"
    sudo journalctl --vacuum-time=14d
  fi
}

clean_trash() {
  local trash_dir="$HOME/.local/share/Trash/files"
  if [[ -d "$trash_dir" ]]; then
    log "Cleaning user trash"
    safe_clear_dir_contents "$trash_dir"
  fi
}

clean_user_cache_dirs() {
  local dir
  local dirs=(
    "$HOME/.cache/mozilla"
    "$HOME/.cache/google-chrome"
    "$HOME/.cache/chromium"
    "$HOME/.cache/yay"
    "$HOME/.cache/paru"
  )

  log "Cleaning common user cache directories"
  for dir in "${dirs[@]}"; do
    safe_clear_dir_contents "$dir"
  done
}

remove_orphans() {
  local -a orphans=()
  mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
  if (( ${#orphans[@]} > 0 )); then
    log "Removing orphan packages"
    sudo pacman -Rns --noconfirm "${orphans[@]}"
  else
    log "No orphan packages found"
  fi
}

main() {
  require_cmd pacman
  require_cmd sudo

  log "Before cleanup"
  df -h /

  clean_pacman_cache
  clean_journal
  clean_trash
  clean_user_cache_dirs
  remove_orphans

  log "After cleanup"
  df -h /
  log "Safe cleanup finished"
}

main "$@"
