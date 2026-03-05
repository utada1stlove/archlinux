#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FALLBACK_REPO="/home/aerith/archlinux/workshop/github/archlinux"
REPO_ROOT="${ARCHLINUX_TOOLBOX_HOME:-}"

COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[1;36m'
COLOR_BLUE=$'\033[1;34m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_GREEN=$'\033[1;32m'
COLOR_RED=$'\033[1;31m'

clear_screen() {
	printf '\033[2J\033[H'
}

print_banner() {
	cat <<EOF
${COLOR_CYAN}    _             _     _ _                     _____           _ _           ${COLOR_RESET}
${COLOR_CYAN}   / \   _ __ ___| |__ | (_)_ __  _   ___  __ |_   _|__   ___ | | |__   _____  __${COLOR_RESET}
${COLOR_CYAN}  / _ \ | '__/ __| '_ \| | | '_ \| | | \ \/ /   | |/ _ \ / _ \| | '_ \ / _ \ \/ /${COLOR_RESET}
${COLOR_CYAN} / ___ \| | | (__| | | | | | | | | |_| |>  <    | | (_) | (_) | | |_) | (_) >  < ${COLOR_RESET}
${COLOR_CYAN}/_/   \_\_|  \___|_| |_|_|_|_| |_|\__,_/_/\_\   |_|\___/ \___/|_|_.__/ \___/_/\_\\${COLOR_RESET}
${COLOR_BLUE}=============================== Toolbox Master Panel ===============================${COLOR_RESET}
EOF
	echo -e "${COLOR_YELLOW}Repo root:${COLOR_RESET} ${REPO_ROOT}"
	echo
}

usage() {
	cat <<USAGE
Usage: $(basename "$0") [--repo /path/to/archlinux]

Environment:
  ARCHLINUX_TOOLBOX_HOME   Set repo root when this script is copied elsewhere.
USAGE
}

resolve_repo_root() {
	if [[ -n "$REPO_ROOT" ]]; then
		return 0
	fi

	if [[ -d "$SCRIPT_DIR/caddy-shortcuts" && -d "$SCRIPT_DIR/clouddrive-rclone" ]]; then
		REPO_ROOT="$SCRIPT_DIR"
		return 0
	fi

	if [[ -d "$FALLBACK_REPO/caddy-shortcuts" && -d "$FALLBACK_REPO/clouddrive-rclone" ]]; then
		REPO_ROOT="$FALLBACK_REPO"
		return 0
	fi

	echo "Cannot determine repo root. Use --repo or ARCHLINUX_TOOLBOX_HOME." >&2
	return 1
}

run_child_script() {
	local title="$1"
	local rel="$2"
	local child rc

	child="${REPO_ROOT}/${rel}"
	if [[ ! -f "$child" ]]; then
		echo -e "${COLOR_RED}Missing script:${COLOR_RESET} $child"
		read -r -p "Press Enter to continue..." _
		return 1
	fi

	clear_screen
	print_banner
	echo -e "${COLOR_GREEN}Launching:${COLOR_RESET} ${title}"
	echo

	set +e
	bash "$child"
	rc=$?
	set -e

	echo
	if [[ "$rc" -eq 0 ]]; then
		echo -e "${COLOR_GREEN}${title} exited successfully.${COLOR_RESET}"
	else
		echo -e "${COLOR_RED}${title} exited with code ${rc}.${COLOR_RESET}"
	fi
	read -r -p "Press Enter to return to master panel..." _
	return 0
}

print_menu() {
	cat <<'MENU'
1) Caddy shortcut panel
2) CloudDrive panel
3) Disk cleanup menu
4) Waydroid menu
0) Exit
MENU
}

panel() {
	local choice

	while true; do
		clear_screen
		print_banner
		print_menu
		echo
		read -r -p "Choose [0-4]: " choice || break

		case "$choice" in
		1) run_child_script "Caddy Shortcut Panel" "caddy-shortcuts/shortcut-manager.sh" ;;
		2) run_child_script "CloudDrive Panel" "clouddrive-rclone/clouddrive-manager.sh" ;;
		3) run_child_script "Disk Cleanup Menu" "scripts/space-clean-menu.sh" ;;
		4) run_child_script "Waydroid Menu" "waydroid-launcher/waydroid-menu.sh" ;;
		0)
			clear_screen
			print_banner
			echo -e "${COLOR_GREEN}Bye.${COLOR_RESET}"
			break
			;;
		*)
			echo -e "${COLOR_RED}Unknown option: $choice${COLOR_RESET}"
			read -r -p "Press Enter to continue..." _
			;;
		esac
	done
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--repo)
			if [[ $# -lt 2 ]]; then
				echo "--repo requires a path." >&2
				return 1
			fi
			REPO_ROOT="$2"
			shift 2
			;;
		-h | --help | help)
			usage
			return 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage
			return 1
			;;
		esac
	done

	resolve_repo_root
	panel
}

main "$@"
