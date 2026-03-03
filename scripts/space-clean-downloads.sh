#!/usr/bin/env bash
set -euo pipefail

DOWNLOADS_DIR="${HOME}/Downloads"
MIN_SIZE_GB="${MIN_SIZE_GB:-1}"
MAX_ITEMS="${MAX_ITEMS:-30}"

human_size() {
  local bytes="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$bytes"
  else
    echo "${bytes}B"
  fi
}

is_remote_path() {
  local path="$1"
  local fs
  if ! command -v findmnt >/dev/null 2>&1; then
    return 1
  fi
  fs="$(findmnt -no FSTYPE -T "$path" 2>/dev/null || true)"
  [[ "$fs" =~ ^(davfs|fuse|fuse\..*|rclone)$ ]]
}

main() {
  local line size path choice token idx
  local -a files=()
  local -a sizes=()
  local -a selected=()
  local removed=0 skipped=0
  local reclaimed=0
  declare -A seen=()

  if [[ ! -d "$DOWNLOADS_DIR" ]]; then
    echo "Downloads directory not found: $DOWNLOADS_DIR"
    exit 1
  fi

  while IFS=$'\t' read -r size path; do
    files+=("$path")
    sizes+=("$size")
  done < <(
    find "$DOWNLOADS_DIR" -xdev -type f -size +"${MIN_SIZE_GB}"G -printf '%s\t%p\n' 2>/dev/null \
      | sort -nr \
      | head -n "$MAX_ITEMS"
  )

  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No files >= ${MIN_SIZE_GB}G found in $DOWNLOADS_DIR."
    exit 0
  fi

  printf "\nTop %d files (>= %sG):\n" "${#files[@]}" "$MIN_SIZE_GB"
  for idx in "${!files[@]}"; do
    printf "%2d) %-10s %s\n" "$((idx + 1))" "$(human_size "${sizes[$idx]}")" "${files[$idx]}"
  done

  printf "\n选择删除方式:\n"
  echo "a) 删除以上全部文件"
  echo "0) 取消"
  echo "或输入序号（空格/逗号分隔，如: 1 3 5）"
  read -r -p "你的选择: " choice

  case "$choice" in
    a|A)
      for idx in "${!files[@]}"; do
        selected+=("$idx")
      done
      ;;
    0|"")
      echo "Canceled."
      exit 0
      ;;
    *)
      choice="${choice//,/ }"
      for token in $choice; do
        if ! [[ "$token" =~ ^[0-9]+$ ]]; then
          echo "Skip invalid token: $token"
          continue
        fi
        if (( token < 1 || token > ${#files[@]} )); then
          echo "Skip out-of-range index: $token"
          continue
        fi
        idx=$((token - 1))
        if [[ -n "${seen[$idx]:-}" ]]; then
          continue
        fi
        seen[$idx]=1
        selected+=("$idx")
      done
      ;;
  esac

  if [[ "${#selected[@]}" -eq 0 ]]; then
    echo "No valid selection. Nothing deleted."
    exit 0
  fi

  for idx in "${selected[@]}"; do
    path="${files[$idx]}"
    size="${sizes[$idx]}"

    if [[ ! -f "$path" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    if is_remote_path "$path"; then
      echo "Skip remote-mounted file: $path"
      skipped=$((skipped + 1))
      continue
    fi

    rm -f -- "$path"
    removed=$((removed + 1))
    reclaimed=$((reclaimed + size))
    echo "Removed: $path"
  done

  printf "\nDone. Removed %d file(s), skipped %d file(s), reclaimed about %s.\n" \
    "$removed" "$skipped" "$(human_size "$reclaimed")"
}

main "$@"
