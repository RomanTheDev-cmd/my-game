#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
import_log=$(mktemp)
trap 'rm -f "$import_log"' EXIT
"${GODOT_BIN:-godot}" --headless --editor --import 2>&1 | tee "$import_log"
if rg -q '^(SCRIPT ERROR|ERROR):' "$import_log"; then
  printf '%s\n' 'Godot import reported errors.' >&2
  exit 1
fi
