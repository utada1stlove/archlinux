#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "\n[!] %s\n" "$1"
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

confirm() {
  read -r -p "This is deep cleanup and may remove many caches. Continue? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

deep_clean_pacman() {
  if command -v paccache >/dev/null 2>&1; then
    log "Cleaning pacman cache aggressively (keep latest 1 version)"
    sudo paccache -rk 1
  fi
  log "Removing all cached packages and sync databases"
  sudo pacman -Scc --noconfirm
}

deep_clean_journal() {
  if command -v journalctl >/dev/null 2>&1; then
    log "Shrinking journal logs to 100M"
    sudo journalctl --vacuum-size=100M
  fi
}

deep_clean_user_cache() {
  log "Cleaning all files under ~/.cache (skip mount points)"
  safe_clear_dir_contents "$HOME/.cache"
}

deep_clean_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Pruning Docker images/containers/networks"
    sudo docker system prune -af
  fi
}

main() {
  require_cmd pacman
  require_cmd sudo

  if ! confirm; then
    echo "Canceled."
    exit 0
  fi

  log "Before cleanup"
  df -h /

  deep_clean_pacman
  deep_clean_journal
  deep_clean_user_cache
  deep_clean_docker

  log "After cleanup"
  df -h /
  log "Deep cleanup finished"
}

main "$@"
