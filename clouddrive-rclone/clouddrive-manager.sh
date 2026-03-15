#!/usr/bin/env bash
set -euo pipefail

resolve_script_dir() {
  local src="${BASH_SOURCE[0]}"
  local dir=""

  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done

  cd -P "$(dirname "$src")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"
AUTOFS_SCRIPT="$SCRIPT_DIR/clouddrive-autofs.sh"
PROFILE_DIR="$SCRIPT_DIR/profiles"
DEFAULT_PROFILE="clouddrive"
OPENLIST_PROFILE="openlist"

if [[ ! -f "$AUTOFS_SCRIPT" ]]; then
  echo "Missing script: $AUTOFS_SCRIPT"
  exit 1
fi

if [[ ! -x "$AUTOFS_SCRIPT" ]]; then
  chmod +x "$AUTOFS_SCRIPT"
fi

clear_screen() {
  printf '\033[2J\033[H'
}

profile_exists() {
  local profile="$1"
  local item=""

  while IFS= read -r item; do
    [[ "$item" == "$profile" ]] && return 0
  done < <("$AUTOFS_SCRIPT" profiles --plain)

  return 1
}

run_profile_panel() {
  local profile="${1:-$DEFAULT_PROFILE}"

  if [[ "$profile" == "$DEFAULT_PROFILE" ]]; then
    exec env CLOUDRIVE_PROFILE="$DEFAULT_PROFILE" "$AUTOFS_SCRIPT" panel
  fi

  exec env CLOUDRIVE_PROFILE="$profile" "$AUTOFS_SCRIPT" panel
}

show_missing_profile_help() {
  local profile="$1"
  local file="$PROFILE_DIR/$profile.env"

  echo "Profile not configured yet: $profile"
  echo "Create: $file"
  echo
  echo "Example:"
  echo "  mkdir -p $PROFILE_DIR"
  echo "  cp $SCRIPT_DIR/config.env.example $file"
}

other_profiles_menu() {
  local -a profiles=()
  local profile=""
  local choice=""
  local index=1

  while IFS= read -r profile; do
    if [[ "$profile" != "$DEFAULT_PROFILE" && "$profile" != "$OPENLIST_PROFILE" ]]; then
      profiles+=("$profile")
    fi
  done < <("$AUTOFS_SCRIPT" profiles --plain)

  if [[ "${#profiles[@]}" -eq 0 ]]; then
    clear_screen
    echo "No additional WebDAV profiles configured."
    echo
    "$AUTOFS_SCRIPT" profiles
    echo
    read -r -p "Press Enter to return..." _
    return 0
  fi

  while true; do
    clear_screen
    echo "Other WebDAV Profiles"
    echo
    "$AUTOFS_SCRIPT" profiles
    echo
    for profile in "${profiles[@]}"; do
      printf '%d) %s\n' "$index" "$profile"
      index=$((index + 1))
    done
    echo "0) Back"
    echo
    read -r -p "Choose [0-${#profiles[@]}]: " choice || return 0

    if [[ "$choice" == "0" ]]; then
      return 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#profiles[@]} )); then
      run_profile_panel "${profiles[choice-1]}"
    fi

    index=1
  done
}

menu() {
  local choice=""

  while true; do
    clear_screen
    echo "WebDAV Manager"
    echo
    echo "1) clouddrive"
    echo "2) openlist"
    echo "3) Other WebDAV profiles"
    echo "4) List configured profiles"
    echo "0) Exit"
    echo
    read -r -p "Choose [0-4]: " choice || exit 0

    case "$choice" in
      1)
        run_profile_panel "$DEFAULT_PROFILE"
        ;;
      2)
        clear_screen
        if profile_exists "$OPENLIST_PROFILE"; then
          run_profile_panel "$OPENLIST_PROFILE"
        else
          show_missing_profile_help "$OPENLIST_PROFILE"
          echo
          read -r -p "Press Enter to return..." _
        fi
        ;;
      3)
        other_profiles_menu
        ;;
      4)
        clear_screen
        "$AUTOFS_SCRIPT" profiles
        echo
        read -r -p "Press Enter to return..." _
        ;;
      0)
        exit 0
        ;;
    esac
  done
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu|panel)
      menu
      ;;
    clouddrive|"$DEFAULT_PROFILE")
      run_profile_panel "$DEFAULT_PROFILE"
      ;;
    openlist|"$OPENLIST_PROFILE")
      if profile_exists "$OPENLIST_PROFILE"; then
        run_profile_panel "$OPENLIST_PROFILE"
      else
        show_missing_profile_help "$OPENLIST_PROFILE"
        exit 1
      fi
      ;;
    profiles|list)
      exec "$AUTOFS_SCRIPT" profiles
      ;;
    *)
      if profile_exists "$cmd"; then
        run_profile_panel "$cmd"
      fi
      echo "Unknown profile or command: $cmd" >&2
      exit 1
      ;;
  esac
}

main "$@"
