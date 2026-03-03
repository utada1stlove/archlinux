#!/usr/bin/env bash
set -euo pipefail

print_header() {
  printf "\n== %s ==\n" "$1"
}

show_size_if_exists() {
  local path="$1"
  local label="$2"
  local size
  if [[ -e "$path" ]]; then
    size="$(du -sh "$path" 2>/dev/null | awk '{print $1}' || true)"
    [[ -n "$size" ]] || size="(no permission)"
    printf "%-32s %s\n" "$label" "$size"
  else
    printf "%-32s %s\n" "$label" "(not found)"
  fi
}

print_header "Filesystem Usage"
df -hT /
if [[ "$HOME" != "/" ]]; then
  df -hT "$HOME"
fi

print_header "Filesystem Inodes"
df -i /
if [[ "$HOME" != "/" ]]; then
  df -i "$HOME"
fi

print_header "Partition Note"
root_dev="$(df -P / | awk 'NR==2 {print $1}')"
home_dev="$(df -P "$HOME" | awk 'NR==2 {print $1}')"
if [[ "$root_dev" != "$home_dev" ]]; then
  echo "Root and HOME are on different filesystems:"
  echo "/     -> $root_dev"
  echo "\$HOME -> $home_dev"
  echo "Deleting files in \$HOME may not change free space shown for '/'."
else
  echo "/ and \$HOME are on the same filesystem: $root_dev"
fi

print_header "Deleted But Still Open Files"
if command -v lsof >/dev/null 2>&1; then
  deleted_open="$(lsof -nP +L1 2>/dev/null | head -n 20 || true)"
  if [[ -n "$deleted_open" ]]; then
    echo "$deleted_open"
    echo "Above files are deleted but still held by processes."
    echo "Restart the related process/service to release disk space."
  else
    echo "No deleted-but-open files found (current user view)."
  fi
  echo "Tip: run 'sudo lsof -nP +L1' for full system-wide results."
else
  echo "lsof not found"
fi

print_header "Pacman Cache"
show_size_if_exists "/var/cache/pacman/pkg" "/var/cache/pacman/pkg"

print_header "systemd Journal"
if command -v journalctl >/dev/null 2>&1; then
  journalctl --disk-usage || true
else
  echo "journalctl not found"
fi

print_header "User Space Hotspots"
show_size_if_exists "$HOME/.cache" "~/.cache"
show_size_if_exists "$HOME/.local/share/Trash" "~/.local/share/Trash"
show_size_if_exists "$HOME/Downloads" "~/Downloads"

print_header "AUR Cache (yay/paru)"
show_size_if_exists "$HOME/.cache/yay" "~/.cache/yay"
show_size_if_exists "$HOME/.cache/paru" "~/.cache/paru"

print_header "Top Directories Under HOME"
du -xh --max-depth=1 "$HOME" 2>/dev/null | sort -h | tail -n 15 || true

if [[ -d "$HOME/.var/app" ]]; then
  print_header "Top Directories Under ~/.var/app"
  du -xh --max-depth=1 "$HOME/.var/app" 2>/dev/null | sort -h | tail -n 15 || true
fi

print_header "WebDAV / FUSE Mounts"
if command -v findmnt >/dev/null 2>&1; then
  mounts="$(findmnt -rn -o TARGET,FSTYPE,SOURCE | grep -Ei 'davfs|webdav|fuse|rclone' || true)"
  if [[ -n "$mounts" ]]; then
    echo "$mounts"
  else
    echo "No WebDAV/FUSE mounts found."
  fi
else
  echo "findmnt not found"
fi

print_header "WebDAV Cache (davfs)"
show_size_if_exists "/var/cache/davfs2" "/var/cache/davfs2"
show_size_if_exists "$HOME/.davfs2/cache" "~/.davfs2/cache"

print_header "Orphan Packages"
if command -v pacman >/dev/null 2>&1; then
  orphans="$(pacman -Qtdq 2>/dev/null || true)"
  if [[ -n "$orphans" ]]; then
    echo "Found orphan packages:"
    echo "$orphans"
  else
    echo "No orphan packages found."
  fi
else
  echo "pacman not found"
fi

print_header "Btrfs Snapshot Hints"
if command -v findmnt >/dev/null 2>&1 && [[ "$(findmnt -rn -o FSTYPE -T / 2>/dev/null || true)" == "btrfs" ]]; then
  show_size_if_exists "/.snapshots" "/.snapshots"
  show_size_if_exists "/var/lib/snapper" "/var/lib/snapper"
  show_size_if_exists "/timeshift" "/timeshift"
  echo "If snapshots are large, deleting normal files may not free much space."
else
  echo "Root filesystem is not btrfs (or findmnt unavailable)."
fi

print_header "Done"
echo "Run ./scripts/space-clean-safe.sh for routine cleanup."
