#!/usr/bin/env bash
set -euo pipefail

MAIN_FILE="/etc/caddy/Caddyfile"
ROUTES_FILE="/etc/caddy/shortcuts.caddy"
IMPORT_LINE="import /etc/caddy/shortcuts.caddy"

URL_SCHEME=""
URL_HOST=""
URL_PORT=""
URL_PATH=""
URL_QUERY=""
URL_FRAGMENT=""
BUILT_MODE=""
SELECTED_DOMAIN=""
SELECTED_TARGET=""
SELECTED_MODE=""

declare -a SHORTCUT_DOMAINS=()
declare -a SHORTCUT_MODES=()
declare -a SHORTCUT_TARGETS=()

COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[1;36m'
COLOR_BLUE=$'\033[1;34m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_GREEN=$'\033[1;32m'

clear_screen() {
	printf '\033[2J\033[H'
}

print_banner() {
	cat <<EOF
${COLOR_CYAN}  ____          _     _         ____  _                _            _ ${COLOR_RESET}
${COLOR_CYAN} / ___|__ _  __| | __| |_   _  / ___|| |__   ___  _ __| |_ ___ _   _| |${COLOR_RESET}
${COLOR_CYAN}| |   / _\` |/ _\` |/ _\` | | | | \___ \| '_ \ / _ \| '__| __/ __| | | | |${COLOR_RESET}
${COLOR_CYAN}| |__| (_| | (_| | (_| | |_| |  ___) | | | | (_) | |  | |_\__ \ |_| | |${COLOR_RESET}
${COLOR_CYAN} \____\__,_|\__,_|\__,_|\__, | |____/|_| |_|\___/|_|   \__|___/\__,_|_|${COLOR_RESET}
${COLOR_CYAN}                        |___/                                            ${COLOR_RESET}
${COLOR_BLUE}======================= Caddy Shortcut Control Panel =======================${COLOR_RESET}
EOF
}

run_root() {
	if [[ ${EUID} -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

repeat_char() {
	local ch="$1"
	local count="$2"
	printf '%*s' "$count" '' | tr ' ' "$ch"
}

load_shortcuts() {
	local -a rows=()
	local row domain mode target

	SHORTCUT_DOMAINS=()
	SHORTCUT_MODES=()
	SHORTCUT_TARGETS=()

	ensure_routes_file

	mapfile -t rows < <(
		run_root awk '
		function flush_row() {
			if (site == "") {
				return
			}
			m = (mode == "" ? "-" : mode)
			t = (target == "" ? "-" : target)
			print site "\t" m "\t" t
		}
		BEGIN {
			in_block = 0
			site = ""
			mode = ""
			target = ""
		}
		{
			line = $0
			if (line ~ /^[[:space:]]*http:\/\/[^[:space:]]+[[:space:]]*\{[[:space:]]*$/) {
				if (in_block == 1) {
					flush_row()
				}
				site = $1
				sub(/^http:\/\//, "", site)
				sub(/\{.*/, "", site)
				gsub(/[[:space:]]+$/, "", site)
				mode = ""
				target = ""
				in_block = 1
				next
			}
			if (in_block == 1 && line ~ /^[[:space:]]*reverse_proxy[[:space:]]+/) {
				mode = "reverse_proxy"
				target = $2
				next
			}
			if (in_block == 1 && line ~ /^[[:space:]]*redir[[:space:]]+/) {
				mode = "redir"
				target = $2
				next
			}
			if (in_block == 1 && line ~ /^[[:space:]]*}[[:space:]]*$/) {
				flush_row()
				in_block = 0
				site = ""
				mode = ""
				target = ""
				next
			}
		}
		END {
			if (in_block == 1) {
				flush_row()
			}
		}
		' "$ROUTES_FILE"
	)

	for row in "${rows[@]}"; do
		IFS=$'\t' read -r domain mode target <<<"$row"
		[[ -z "$domain" ]] && continue
		SHORTCUT_DOMAINS+=("$domain")
		SHORTCUT_MODES+=("$mode")
		SHORTCUT_TARGETS+=("$target")
	done
}

print_shortcuts_table() {
	local i
	local idx domain mode target
	local w_idx=3
	local w_domain=24
	local w_mode=14
	local w_target=56
	local sep

	for i in "${!SHORTCUT_DOMAINS[@]}"; do
		idx="$((i + 1))"
		domain="${SHORTCUT_DOMAINS[$i]}"
		mode="${SHORTCUT_MODES[$i]}"
		target="${SHORTCUT_TARGETS[$i]}"
		(( ${#idx} > w_idx )) && w_idx=${#idx}
		(( ${#domain} > w_domain )) && w_domain=${#domain}
		(( ${#mode} > w_mode )) && w_mode=${#mode}
		(( ${#target} > w_target )) && w_target=${#target}
	done

	sep="+-$(repeat_char "-" "$w_idx")-+-$(repeat_char "-" "$w_domain")-+-$(repeat_char "-" "$w_mode")-+-$(repeat_char "-" "$w_target")-+"
	echo "$sep"
	printf "| %*s | %-*s | %-*s | %-*s |\n" "$w_idx" "#" "$w_domain" "Domain" "$w_mode" "Mode" "$w_target" "Target"
	echo "$sep"

	for i in "${!SHORTCUT_DOMAINS[@]}"; do
		domain="${SHORTCUT_DOMAINS[$i]}"
		mode="${SHORTCUT_MODES[$i]}"
		target="${SHORTCUT_TARGETS[$i]}"
		printf "| %*d | %-*s | %-*s | %-*s |\n" "$w_idx" "$((i + 1))" "$w_domain" "$domain" "$w_mode" "$mode" "$w_target" "$target"
	done

	echo "$sep"
}

select_shortcut_domain() {
	local action="$1"
	local choice

	load_shortcuts

	if [[ "${#SHORTCUT_DOMAINS[@]}" -eq 0 ]]; then
		echo "No shortcuts available."
		return 1
	fi

	echo "Current shortcuts ($ROUTES_FILE):"
	print_shortcuts_table

	while true; do
		read -r -p "Choose number to ${action} [1-${#SHORTCUT_DOMAINS[@]}], 0 cancel: " choice
		choice="$(trim "$choice")"

		if [[ "$choice" == "0" ]]; then
			echo "Canceled."
			return 1
		fi

			if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#SHORTCUT_DOMAINS[@]} )); then
				SELECTED_DOMAIN="${SHORTCUT_DOMAINS[$((choice - 1))]}"
				SELECTED_MODE="${SHORTCUT_MODES[$((choice - 1))]}"
				SELECTED_TARGET="${SHORTCUT_TARGETS[$((choice - 1))]}"
				return 0
			fi

		echo "Invalid selection."
	done
}

normalize_target_for_prompt() {
	local mode="$1"
	local target="$2"

	if [[ "$mode" == "reverse_proxy" && "$target" != http://* && "$target" != https://* ]]; then
		printf 'http://%s' "$target"
		return 0
	fi

	printf '%s' "$target"
}

backup_with_ts() {
	local file="$1"
	local ts backup
	ts="$(date +%Y%m%d-%H%M%S)"
	backup="${file}.bak.${ts}"
	run_root cp -a "$file" "$backup"
	echo "$backup"
}

ensure_import_line() {
	if run_root test -f "$MAIN_FILE"; then
		if run_root grep -Eq '^[[:space:]]*import[[:space:]]+/etc/caddy/shortcuts\.caddy[[:space:]]*$' "$MAIN_FILE"; then
			return 0
		fi
		backup_with_ts "$MAIN_FILE" >/dev/null
		printf "\n# Local shortcut routes\n%s\n" "$IMPORT_LINE" | run_root tee -a "$MAIN_FILE" >/dev/null
		return 0
	fi

	printf "%s\n" "$IMPORT_LINE" | run_root tee "$MAIN_FILE" >/dev/null
}

ensure_routes_file() {
	run_root install -d /etc/caddy
	if ! run_root test -f "$ROUTES_FILE"; then
		run_root install -m 0644 /dev/null "$ROUTES_FILE"
	fi
}

validate_domain() {
	local domain="$1"
	[[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]
}

parse_url() {
	local url="$1"
	if [[ ! "$url" =~ ^(https?)://([^/:?#]+)(:([0-9]{1,5}))?(/[^?#]*)?(\?[^#]*)?(#.*)?$ ]]; then
		return 1
	fi

	URL_SCHEME="${BASH_REMATCH[1]}"
	URL_HOST="${BASH_REMATCH[2]}"
	URL_PORT="${BASH_REMATCH[4]}"
	URL_PATH="${BASH_REMATCH[5]:-/}"
	URL_QUERY="${BASH_REMATCH[6]}"
	URL_FRAGMENT="${BASH_REMATCH[7]}"
	return 0
}

is_private_ipv4() {
	local ip="$1"
	if [[ "$ip" =~ ^10\. ]]; then
		return 0
	fi
	if [[ "$ip" =~ ^127\. ]]; then
		return 0
	fi
	if [[ "$ip" =~ ^192\.168\. ]]; then
		return 0
	fi
	if [[ "$ip" =~ ^172\.([0-9]{1,3})\. ]]; then
		local oct2="${BASH_REMATCH[1]}"
		if (( oct2 >= 16 && oct2 <= 31 )); then
			return 0
		fi
	fi
	return 1
}

is_private_host() {
	local host="$1"
	if [[ "$host" == "localhost" || "$host" == *.lan ]]; then
		return 0
	fi
	if is_private_ipv4 "$host"; then
		return 0
	fi
	return 1
}

build_block() {
	local domain="$1"
	local target="$2"
	local path_part

	parse_url "$target" || return 1
	path_part="${URL_PATH}${URL_QUERY}${URL_FRAGMENT}"

	if is_private_host "$URL_HOST" && [[ "$path_part" == "/" ]]; then
		BUILT_MODE="reverse_proxy"
		cat <<EOF
http://${domain} {
	reverse_proxy ${target}
}
EOF
	else
		BUILT_MODE="redir"
		cat <<EOF
http://${domain} {
	redir ${target} 302
}
EOF
	fi
}

remove_site_block() {
	local domain="$1"
	local in_file="$2"
	local out_file="$3"
	local site="http://${domain}"

	awk -v site="$site" '
	BEGIN {
		skip = 0
		depth = 0
	}
	{
		if (skip == 1) {
			line = $0
			open_n = gsub(/\{/, "{", line)
			close_n = gsub(/\}/, "}", line)
			depth += open_n - close_n
			if (depth <= 0) {
				skip = 0
			}
			next
		}
		if ($0 ~ "^[[:space:]]*" site "[[:space:]]*\\{[[:space:]]*$") {
			skip = 1
			depth = 1
			next
		}
		print
	}
	' "$in_file" >"$out_file"
}

site_block_exists() {
	local domain="$1"
	local site="http://${domain}"

	run_root awk -v site="$site" '
	{
		line = $0
		sub(/^[[:space:]]+/, "", line)
		sub(/[[:space:]]+$/, "", line)
		if (line == site " {") {
			found = 1
		}
	}
	END {
		exit found ? 0 : 1
	}
	' "$ROUTES_FILE"
}

ensure_host_entry() {
	local host="$1"
	local host_re
	host_re="${host//./\\.}"

	if run_root grep -Eq "^[[:space:]]*127\\.0\\.0\\.1([[:space:]]+.*)?\\b${host_re}\\b" /etc/hosts; then
		echo "[hosts] ${host} already maps to 127.0.0.1"
		return 0
	fi

	if run_root grep -Eq "\\b${host_re}\\b" /etc/hosts; then
		echo "[hosts] ${host} already exists in /etc/hosts (not 127.0.0.1), skipped."
		return 0
	fi

	printf "127.0.0.1 %s\n" "$host" | run_root tee -a /etc/hosts >/dev/null
	echo "[hosts] added ${host} -> 127.0.0.1"
}

remove_host_entry() {
	local host="$1"
	local tmp changed
	tmp="$(mktemp)"
	changed=0

	run_root awk -v host="$host" '
	function trim(s) {
		sub(/^[ \t]+/, "", s)
		sub(/[ \t]+$/, "", s)
		return s
	}
	{
		orig = $0
		if (orig ~ /^[[:space:]]*#/ || orig ~ /^[[:space:]]*$/) {
			print orig
			next
		}

		comment = ""
		line = orig
		pos = index(line, "#")
		if (pos > 0) {
			comment = substr(line, pos)
			line = substr(line, 1, pos - 1)
		}
		line = trim(line)
		if (line == "") {
			print orig
			next
		}

		n = split(line, f, /[[:space:]]+/)
		ip = f[1]
		keep_n = 0
		removed = 0

		for (i = 2; i <= n; i++) {
			if (f[i] == host) {
				removed = 1
				continue
			}
			keep[++keep_n] = f[i]
		}

		if (removed == 1) {
			changed = 1
		}

		if (keep_n == 0) {
			delete keep
			next
		}

		out = ip
		for (i = 1; i <= keep_n; i++) {
			out = out " " keep[i]
		}
		if (comment != "") {
			out = out " " comment
		}
		print out
		delete keep
	}
	' /etc/hosts >"$tmp"

	if run_root cmp -s "$tmp" /etc/hosts; then
		echo "[hosts] ${host} not found, skipped."
		rm -f "$tmp"
		return 0
	fi

	run_root install -m 0644 "$tmp" /etc/hosts
	echo "[hosts] removed ${host} from /etc/hosts"
	rm -f "$tmp"
}

validate_and_reload() {
	run_root caddy validate --config "$MAIN_FILE" --adapter caddyfile
	if run_root systemctl is-active --quiet caddy; then
		run_root systemctl reload caddy
	else
		run_root systemctl enable --now caddy
	fi
}

add_shortcut() {
	local target="$1"
	local domain="$2"
	local current tmp_stripped tmp_next tmp_mode mode backup=""

	if ! parse_url "$target"; then
		echo "Invalid target URL. Use format: http://... or https://..." >&2
		return 1
	fi

	if ! validate_domain "$domain"; then
		echo "Invalid domain: $domain" >&2
		return 1
	fi

	ensure_routes_file
	ensure_import_line

	current="$(mktemp)"
	tmp_stripped="$(mktemp)"
	tmp_next="$(mktemp)"
	tmp_mode="$(mktemp)"

	run_root cat "$ROUTES_FILE" >"$current"
	remove_site_block "$domain" "$current" "$tmp_stripped"

	if [[ -s "$tmp_stripped" ]]; then
		cat "$tmp_stripped" >"$tmp_next"
		printf "\n" >>"$tmp_next"
	else
		: >"$tmp_next"
	fi

	build_block "$domain" "$target" >"$tmp_mode"
	mode="$BUILT_MODE"
	cat "$tmp_mode" >>"$tmp_next"
	printf "\n" >>"$tmp_next"

	if run_root test -f "$ROUTES_FILE"; then
		backup="$(backup_with_ts "$ROUTES_FILE")"
	fi

	run_root install -m 0644 "$tmp_next" "$ROUTES_FILE"

	if ! run_root caddy validate --config "$MAIN_FILE" --adapter caddyfile >/dev/null; then
		echo "Caddy validation failed, rolling back changes." >&2
		if [[ -n "$backup" ]]; then
			run_root cp -a "$backup" "$ROUTES_FILE"
		fi
		return 1
	fi

	ensure_host_entry "$domain"
	validate_and_reload

	echo "Added shortcut:"
	echo "  domain: http://${domain}"
	echo "  target: ${target}"
	echo "  mode: ${mode}"
}

modify_shortcut() {
	local old_domain="$1"
	local new_domain="$2"
	local new_target="$3"
	local current tmp_next tmp_mode mode backup=""

	if ! validate_domain "$old_domain"; then
		echo "Invalid old domain: $old_domain" >&2
		return 1
	fi
	if ! validate_domain "$new_domain"; then
		echo "Invalid new domain: $new_domain" >&2
		return 1
	fi
	if ! parse_url "$new_target"; then
		echo "Invalid target URL. Use format: http://... or https://..." >&2
		return 1
	fi

	ensure_routes_file
	ensure_import_line

	if ! site_block_exists "$old_domain"; then
		echo "Domain does not exist in routes file: ${old_domain}" >&2
		return 1
	fi
	if [[ "$new_domain" != "$old_domain" ]] && site_block_exists "$new_domain"; then
		echo "Target domain already exists: ${new_domain}" >&2
		return 1
	fi

	current="$(mktemp)"
	tmp_next="$(mktemp)"
	tmp_mode="$(mktemp)"

	run_root cat "$ROUTES_FILE" >"$current"
	remove_site_block "$old_domain" "$current" "$tmp_next"

	if [[ -s "$tmp_next" ]]; then
		printf "\n" >>"$tmp_next"
	fi

	build_block "$new_domain" "$new_target" >"$tmp_mode"
	mode="$BUILT_MODE"
	cat "$tmp_mode" >>"$tmp_next"
	printf "\n" >>"$tmp_next"

	if run_root test -f "$ROUTES_FILE"; then
		backup="$(backup_with_ts "$ROUTES_FILE")"
	fi
	run_root install -m 0644 "$tmp_next" "$ROUTES_FILE"

	if ! run_root caddy validate --config "$MAIN_FILE" --adapter caddyfile >/dev/null; then
		echo "Caddy validation failed, rolling back changes." >&2
		if [[ -n "$backup" ]]; then
			run_root cp -a "$backup" "$ROUTES_FILE"
		fi
		return 1
	fi

	if [[ "$new_domain" != "$old_domain" ]]; then
		remove_host_entry "$old_domain"
	fi
	ensure_host_entry "$new_domain"
	validate_and_reload

	echo "Modified shortcut:"
	echo "  old domain: http://${old_domain}"
	echo "  new domain: http://${new_domain}"
	echo "  new target: ${new_target}"
	echo "  mode: ${mode}"
}

delete_shortcut() {
	local domain="$1"
	local current tmp_next backup=""

	if ! validate_domain "$domain"; then
		echo "Invalid domain: $domain" >&2
		return 1
	fi

	ensure_routes_file
	ensure_import_line

	if ! site_block_exists "$domain"; then
		echo "Domain does not exist in routes file: ${domain}" >&2
		return 1
	fi

	current="$(mktemp)"
	tmp_next="$(mktemp)"

	run_root cat "$ROUTES_FILE" >"$current"
	remove_site_block "$domain" "$current" "$tmp_next"

	if run_root test -f "$ROUTES_FILE"; then
		backup="$(backup_with_ts "$ROUTES_FILE")"
	fi
	run_root install -m 0644 "$tmp_next" "$ROUTES_FILE"

	if ! run_root caddy validate --config "$MAIN_FILE" --adapter caddyfile >/dev/null; then
		echo "Caddy validation failed, rolling back changes." >&2
		if [[ -n "$backup" ]]; then
			run_root cp -a "$backup" "$ROUTES_FILE"
		fi
		return 1
	fi

	remove_host_entry "$domain"
	validate_and_reload

	echo "Deleted shortcut: http://${domain}"
}

list_shortcuts() {
	load_shortcuts
	echo "Current shortcuts ($ROUTES_FILE):"

	if [[ "${#SHORTCUT_DOMAINS[@]}" -eq 0 ]]; then
		echo "(empty)"
		return 0
	fi

	print_shortcuts_table
}

prompt_add_shortcut() {
	local target domain

	read -r -p "Target URL (http://... or https://...): " target
	target="$(trim "$target")"
	if [[ -z "$target" ]]; then
		echo "Target URL is required."
		return 1
	fi

	read -r -p "New local domain (example: nas.lan / news.wsj): " domain
	domain="$(trim "$domain")"
	if [[ -z "$domain" ]]; then
		echo "Domain is required."
		return 1
	fi

	add_shortcut "$target" "$domain"
}

prompt_modify_shortcut() {
	local old_domain new_domain new_target default_target

	if ! select_shortcut_domain "modify"; then
		return 0
	fi
	old_domain="$SELECTED_DOMAIN"
	default_target="$(normalize_target_for_prompt "$SELECTED_MODE" "$SELECTED_TARGET")"
	echo "Selected domain: http://${old_domain}"
	echo "Current target: ${default_target}"

	read -r -p "New domain [${old_domain}]: " new_domain
	new_domain="$(trim "$new_domain")"
	if [[ -z "$new_domain" ]]; then
		new_domain="$old_domain"
	fi

	read -r -p "New target URL [${default_target}]: " new_target
	new_target="$(trim "$new_target")"
	if [[ -z "$new_target" ]]; then
		new_target="$default_target"
	fi
	if [[ -z "$new_target" || "$new_target" == "-" ]]; then
		echo "Target URL is required."
		return 1
	fi

	modify_shortcut "$old_domain" "$new_domain" "$new_target"
}

prompt_delete_shortcut() {
	local domain confirm

	if ! select_shortcut_domain "delete"; then
		return 0
	fi
	domain="$SELECTED_DOMAIN"
	echo "Selected domain: http://${domain}"

	read -r -p "Confirm delete http://${domain}? [y/N]: " confirm
	confirm="$(trim "$confirm")"
	if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
		echo "Canceled."
		return 0
	fi

	delete_shortcut "$domain"
}

print_menu() {
	cat <<'MENU'

======== Caddy Shortcut Panel ========
1) Add shortcut (interactive)
2) Modify shortcut
3) Delete shortcut
4) List shortcut domains
5) Validate and reload Caddy
6) Show routes file path
0) Exit
======================================
MENU
}

panel() {
	local choice rc
	while true; do
		clear_screen
		print_banner
		print_menu
		read -r -p "Choose [0-6]: " choice || break
		case "$choice" in
		1)
			clear_screen
			print_banner
			echo -e "${COLOR_YELLOW}Running: Add shortcut${COLOR_RESET}"
			set +e
			prompt_add_shortcut
			rc=$?
			set -e
			;;
		2)
			clear_screen
			print_banner
			echo -e "${COLOR_YELLOW}Running: Modify shortcut${COLOR_RESET}"
			set +e
			prompt_modify_shortcut
			rc=$?
			set -e
			;;
		3)
			clear_screen
			print_banner
			echo -e "${COLOR_YELLOW}Running: Delete shortcut${COLOR_RESET}"
			set +e
			prompt_delete_shortcut
			rc=$?
			set -e
			;;
		4)
			clear_screen
			print_banner
			echo -e "${COLOR_YELLOW}Running: List shortcuts${COLOR_RESET}"
			set +e
			list_shortcuts
			rc=$?
			set -e
			;;
		5)
			clear_screen
			print_banner
			echo -e "${COLOR_YELLOW}Running: Validate and reload${COLOR_RESET}"
			set +e
			validate_and_reload
			rc=$?
			set -e
			;;
		6)
			clear_screen
			print_banner
			echo -e "${COLOR_YELLOW}Routes file path${COLOR_RESET}"
			rc=0
			echo "$ROUTES_FILE"
			;;
		0)
			clear_screen
			print_banner
			echo -e "${COLOR_GREEN}Bye.${COLOR_RESET}"
			break
			;;
		*)
			clear_screen
			print_banner
			rc=1
			echo "Unknown option: $choice"
			;;
		esac

		if [[ "${rc:-0}" -ne 0 ]]; then
			echo "Action failed (exit=${rc})"
		fi
		read -r -p "Press Enter to continue..." _
	done
}

usage() {
	cat <<USAGE
Usage: $(basename "$0") [panel|add|modify|delete|list|reload]

Commands:
  panel          Interactive panel (default)
  add            Add one shortcut interactively
  modify         Modify one shortcut interactively
  delete         Delete one shortcut interactively
  list           List current shortcut domains
  reload         Validate and reload Caddy
USAGE
}

main() {
	local cmd="${1:-panel}"
	require_cmd caddy
	require_cmd awk
	require_cmd systemctl
	if [[ ${EUID} -ne 0 ]]; then
		require_cmd sudo
	fi

	case "$cmd" in
	panel) panel ;;
	add) prompt_add_shortcut ;;
	modify) prompt_modify_shortcut ;;
	delete) prompt_delete_shortcut ;;
	list) list_shortcuts ;;
	reload) validate_and_reload ;;
	-h | --help | help) usage ;;
	*)
		echo "Unknown command: $cmd" >&2
		usage
		return 1
		;;
	esac
}

main "$@"
