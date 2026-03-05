#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${REPO_ROOT}/toolbox-panel.sh"
BIN_DIR="${HOME}/.local/bin"
TARGET_LINK="${BIN_DIR}/toolbox"

if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
	echo "Missing source script: ${SOURCE_SCRIPT}" >&2
	exit 1
fi

mkdir -p "${BIN_DIR}"

if [[ -e "${TARGET_LINK}" && ! -L "${TARGET_LINK}" ]]; then
	backup="${TARGET_LINK}.bak.$(date +%Y%m%d-%H%M%S)"
	mv "${TARGET_LINK}" "${backup}"
	echo "Backed up existing ${TARGET_LINK} -> ${backup}"
fi

ln -sfn "${SOURCE_SCRIPT}" "${TARGET_LINK}"
chmod +x "${SOURCE_SCRIPT}"

echo "Installed command: toolbox -> ${SOURCE_SCRIPT}"

case ":${PATH}:" in
*":${BIN_DIR}:"*)
	echo "${BIN_DIR} is already in PATH."
	;;
*)
	echo
	echo "Add this to your shell config (~/.bashrc or ~/.zshrc):"
	echo "  export PATH=\"${BIN_DIR}:\$PATH\""
	echo
	echo "Then reload shell:"
	echo "  source ~/.bashrc"
	;;
esac

echo
echo "Try:"
echo "  toolbox"
