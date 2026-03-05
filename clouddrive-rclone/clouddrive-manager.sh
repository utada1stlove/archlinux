#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOFS_SCRIPT="$SCRIPT_DIR/clouddrive-autofs.sh"

if [[ ! -f "$AUTOFS_SCRIPT" ]]; then
  echo "Missing script: $AUTOFS_SCRIPT"
  exit 1
fi

if [[ ! -x "$AUTOFS_SCRIPT" ]]; then
  chmod +x "$AUTOFS_SCRIPT"
fi

exec "$AUTOFS_SCRIPT" panel
