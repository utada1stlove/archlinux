#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.vscode/extensions/dae-local-syntax"

echo "Installing DAE syntax extension..."
mkdir -p "${TARGET_DIR}"
cp -a "${SCRIPT_DIR}/." "${TARGET_DIR}/"

echo "Installed to: ${TARGET_DIR}"
echo "Now run in VS Code: Developer: Reload Window"
