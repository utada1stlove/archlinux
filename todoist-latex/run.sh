#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# Check Flask availability
if ! python3 -c "import flask" 2>/dev/null; then
  echo "Flask not found. Install it with:"
  echo "  sudo pacman -S python-flask   # Arch Linux"
  echo "  pip install flask             # other systems"
  exit 1
fi

echo "Starting Todo List server at http://localhost:5000"
python3 app.py
