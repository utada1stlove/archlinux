#!/usr/bin/env bash
set -euo pipefail

log() {
  printf "\n[+] %s\n" "$1"
}

show_size_if_exists() {
  local path="$1"
  local label="$2"
  if [[ -e "$path" ]]; then
    printf "%-28s %s\n" "$label" "$(du -sh "$path" 2>/dev/null | awk '{print $1}')"
  else
    printf "%-28s %s\n" "$label" "(not found)"
  fi
}

main() {
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "flatpak command not found."
    exit 1
  fi

  log "Before cleanup"
  show_size_if_exists "/var/lib/flatpak" "/var/lib/flatpak"
  show_size_if_exists "$HOME/.local/share/flatpak" "~/.local/share/flatpak"

  log "Removing unused Flatpak runtimes (user)"
  flatpak uninstall --user --unused -y || true

  log "Removing unused Flatpak runtimes (system)"
  if command -v sudo >/dev/null 2>&1; then
    sudo flatpak uninstall --system --unused -y || true
  else
    flatpak uninstall --system --unused -y || true
  fi

  log "Cleaning flatpak download cache"
  rm -rf "$HOME/.cache/flatpak/"* 2>/dev/null || true

  log "After cleanup"
  show_size_if_exists "/var/lib/flatpak" "/var/lib/flatpak"
  show_size_if_exists "$HOME/.local/share/flatpak" "~/.local/share/flatpak"
}

main "$@"
