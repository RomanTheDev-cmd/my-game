#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
# Tests never read or overwrite a player's actual save directory.
test_data=$(mktemp -d)
trap 'rm -rf "$test_data"' EXIT
runner=()
if command -v timeout >/dev/null; then runner=(timeout 90); fi
for suite in tests/test_rules.gd tests/test_saves.gd tests/test_regions.gd tests/test_quests.gd tests/test_gameplay.gd tests/test_travel.gd tests/test_navigation.gd tests/test_magic.gd tests/test_items.gd tests/test_preferences.gd tests/test_progression.gd tests/test_aid.gd tests/test_equipment.gd tests/test_commerce.gd tests/test_archetypes.gd tests/test_loot.gd tests/test_gear_migration.gd tests/test_world_time.gd tests/test_living_rules.gd tests/test_living_world.gd tests/test_audio.gd tests/test_defense_magic.gd tests/test_commission_rules.gd tests/test_faction_migration.gd tests/test_workshop.gd tests/test_commission_world.gd tests/test_faction_benefits.gd tests/test_faction_economy.gd tests/test_boss_rules.gd tests/test_trial.gd tests/test_waterworks.gd tests/test_boss_combat.gd tests/test_trial_gameplay.gd tests/test_nature_rules.gd tests/test_nature_migration.gd tests/test_nature_combat.gd tests/test_nature_gameplay.gd tests/test_dialogue_memory.gd tests/test_pack_rules.gd tests/test_pack_migration.gd tests/test_thicket.gd tests/test_pack_combat.gd tests/test_pack_gameplay.gd tests/test_flight_rules.gd tests/test_flight_migration.gd tests/test_flight_gameplay.gd tests/test_stealth.gd tests/test_community_rules.gd tests/test_haven.gd tests/test_community_gameplay.gd tests/test_community_history.gd tests/test_spell_training.gd tests/test_field_rules.gd tests/test_field_gameplay.gd tests/test_field_history.gd tests/test_campaign_rules.gd tests/test_terrace.gd tests/test_campaign_gameplay.gd tests/test_campaign_paths.gd tests/test_forest_rules.gd tests/test_forest_gameplay.gd tests/test_forest_history.gd tests/test_city_rules.gd tests/test_city_gameplay.gd tests/test_city_history.gd tests/test_city_combat.gd; do
  suite_data="$test_data/$(basename "$suite" .gd)"
  mkdir -p "$suite_data"
  XDG_DATA_HOME="$suite_data" "${runner[@]}" "$godot_bin" --headless --path . --script "$suite" 2>&1 | tee "$test_data/output.log"
  if rg -q '^(SCRIPT ERROR|ERROR):|ObjectDB instances leaked' "$test_data/output.log"; then
    exit 1
  fi
done

python3 tools/verify_audio.py
python3 tools/audit_story.py
python3 -m unittest discover -s tests -p 'test_*.py'
