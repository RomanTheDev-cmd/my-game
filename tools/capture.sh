#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
capture_data=$(mktemp -d)
trap 'rm -rf "$capture_data"' EXIT
XDG_DATA_HOME="$capture_data" "${GODOT_BIN:-godot}" --audio-driver Dummy --script tests/capture.gd
