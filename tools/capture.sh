#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
capture_data=$(mktemp -d)
trap 'rm -rf "$capture_data"' EXIT
XDG_DATA_HOME="$capture_data" "${GODOT_BIN:-godot}" --audio-driver Dummy --script tests/capture.gd 2>&1 | tee "$capture_data/output.log"
if rg -q '^(SCRIPT ERROR|ERROR):|ObjectDB instances leaked' "$capture_data/output.log"; then
  exit 1
fi
