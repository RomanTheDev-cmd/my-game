#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
# Tests never read or overwrite a player's actual save directory.
test_data=$(mktemp -d)
trap 'rm -rf "$test_data"' EXIT
runner=()
if command -v timeout >/dev/null; then runner=(timeout 90); fi
for suite in tests/test_rules.gd tests/test_saves.gd tests/test_regions.gd tests/test_quests.gd tests/test_gameplay.gd tests/test_travel.gd; do
  XDG_DATA_HOME="$test_data" "${runner[@]}" "$godot_bin" --headless --path . --script "$suite" 2>&1 | tee "$test_data/output.log"
  if rg -q '^(SCRIPT ERROR|ERROR):' "$test_data/output.log"; then
    exit 1
  fi
done
