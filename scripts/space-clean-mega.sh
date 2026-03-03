#!/usr/bin/env bash
set -euo pipefail

MOUNT_DIR="${HOME}/MEGA"

is_mounted() {
  local target=""
  local norm_path="${MOUNT_DIR%/}"
  [[ -n "$norm_path" ]] || norm_path="/"

  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "$MOUNT_DIR"
    return $?
  fi
  if command -v findmnt >/dev/null 2>&1; then
    target="$(findmnt -rn -o TARGET -T "$MOUNT_DIR" 2>/dev/null | head -n 1 || true)"
    target="${target%/}"
    [[ -n "$target" ]] || target="/"
    [[ "$target" == "$norm_path" ]]
    return $?
  fi
  return 1
}

main() {
  if [[ ! -d "$MOUNT_DIR" ]]; then
    echo "MEGA directory not found: $MOUNT_DIR"
    exit 0
  fi

  echo "CloudDrive will not be touched. Target is only: $MOUNT_DIR"

  if ! is_mounted; then
    echo "MEGA is not mounted now."
    exit 0
  fi

  read -r -p "Detected mounted MEGA path. Unmount now? [y/N] " ans
  if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    echo "Canceled."
    exit 0
  fi

  if command -v fusermount >/dev/null 2>&1; then
    fusermount -u "$MOUNT_DIR" && echo "Unmounted via fusermount." && exit 0
  fi

  if command -v umount >/dev/null 2>&1; then
    umount "$MOUNT_DIR" && echo "Unmounted via umount." && exit 0
  fi

  echo "Failed to unmount MEGA. You can try manually: fusermount -u \"$MOUNT_DIR\""
  exit 1
}

main "$@"
