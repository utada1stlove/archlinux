#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_MAIN="${BASE_DIR}/Caddyfile.main"
SRC_ROUTES="${BASE_DIR}/shortcuts.caddy"
IMPORT_LINE="import /etc/caddy/shortcuts.caddy"

DST_DIR="/etc/caddy"
DST_MAIN="${DST_DIR}/Caddyfile"
DST_ROUTES="${DST_DIR}/shortcuts.caddy"
RESET_ROUTES=0

COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[1;36m'
COLOR_BLUE=$'\033[1;34m'

print_banner() {
	cat <<EOF
${COLOR_CYAN}  ____          _     _         ____  _                _            _ ${COLOR_RESET}
${COLOR_CYAN} / ___|__ _  __| | __| |_   _  / ___|| |__   ___  _ __| |_ ___ _   _| |${COLOR_RESET}
${COLOR_CYAN}| |   / _\` |/ _\` |/ _\` | | | | \___ \| '_ \ / _ \| '__| __/ __| | | | |${COLOR_RESET}
${COLOR_CYAN}| |__| (_| | (_| | (_| | |_| |  ___) | | | | (_) | |  | |_\__ \ |_| | |${COLOR_RESET}
${COLOR_CYAN} \____\__,_|\__,_|\__,_|\__, | |____/|_| |_|\___/|_|   \__|___/\__,_|_|${COLOR_RESET}
${COLOR_CYAN}                        |___/                                            ${COLOR_RESET}
${COLOR_BLUE}========================== Caddy Shortcut Installer ==========================${COLOR_RESET}
EOF
}

print_banner

if ! command -v caddy >/dev/null 2>&1; then
	echo "caddy is not installed. Install first: sudo pacman -S caddy" >&2
	exit 1
fi

usage() {
	cat <<'USAGE'
Usage: install.sh [--reset-routes]

Options:
  --reset-routes   Overwrite /etc/caddy/shortcuts.caddy with template defaults.
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--reset-routes)
		RESET_ROUTES=1
		shift
		;;
	-h | --help | help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage
		exit 1
		;;
	esac
done

if [[ ${EUID} -eq 0 ]]; then
	SUDO=""
else
	SUDO="sudo"
fi

ensure_host() {
	local ip="$1"
	local host="$2"
	local ip_re host_re
	ip_re="${ip//./\\.}"
	host_re="${host//./\\.}"

	if ${SUDO} grep -Eq "^[[:space:]]*${ip_re}([[:space:]]+.*)?\\b${host_re}\\b" /etc/hosts; then
		echo "[hosts] ${host} already exists"
		return 0
	fi

	echo "${ip} ${host}" | ${SUDO} tee -a /etc/hosts >/dev/null
	echo "[hosts] added ${host}"
}

backup_file() {
	local file="$1"
	local ts backup
	ts="$(date +%Y%m%d-%H%M%S)"
	backup="${file}.bak.${ts}"
	${SUDO} cp -a "${file}" "${backup}"
	echo "[backup] ${file} -> ${backup}"
}

echo "[1/4] Install Caddy config files"
${SUDO} install -d "${DST_DIR}"
if ${SUDO} test -f "${DST_MAIN}"; then
	if ${SUDO} grep -Eq '^[[:space:]]*import[[:space:]]+/etc/caddy/shortcuts\.caddy[[:space:]]*$' "${DST_MAIN}"; then
		echo "[caddy] import line already exists in ${DST_MAIN}"
	else
		backup_file "${DST_MAIN}"
		printf "\n# Local shortcut routes\n%s\n" "${IMPORT_LINE}" | ${SUDO} tee -a "${DST_MAIN}" >/dev/null
		echo "[caddy] appended import line to ${DST_MAIN}"
	fi
else
	${SUDO} install -m 0644 "${SRC_MAIN}" "${DST_MAIN}"
	echo "[caddy] installed new ${DST_MAIN}"
fi

if ${SUDO} test -f "${DST_ROUTES}"; then
	if [[ "${RESET_ROUTES}" -eq 1 ]]; then
		backup_file "${DST_ROUTES}"
		${SUDO} install -m 0644 "${SRC_ROUTES}" "${DST_ROUTES}"
		echo "[caddy] reset ${DST_ROUTES} from template"
	else
		echo "[caddy] keeping existing ${DST_ROUTES} (use --reset-routes to overwrite)"
	fi
else
	${SUDO} install -m 0644 "${SRC_ROUTES}" "${DST_ROUTES}"
	echo "[caddy] installed new ${DST_ROUTES}"
fi

echo "[2/4] Update /etc/hosts for local shortcut domains"
ensure_host "127.0.0.1" "clouddrive.lan"
ensure_host "127.0.0.1" "news.economist"

echo "[3/4] Validate Caddy config"
${SUDO} caddy validate --config "${DST_MAIN}" --adapter caddyfile

echo "[4/4] Enable and reload Caddy service"
${SUDO} systemctl enable --now caddy
${SUDO} systemctl reload caddy

cat <<'EOF'
Done.

Try:
  http://clouddrive.lan
  http://news.economist

To add more shortcuts, edit:
  /etc/caddy/shortcuts.caddy
Then reload:
  sudo systemctl reload caddy
EOF
