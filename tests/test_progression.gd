extends SceneTree
const Skills = preload("res://scripts/progression/skill_rules.gd")
const Store = preload("res://scripts/systems/save_store.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	check(Skills.level(39) == 1 and Skills.level(40) == 2, "level threshold grants first point at 40 XP")
	check(Skills.level(119) == 2 and Skills.level(120) == 3, "later levels require increasing experience")
	check(Skills.level(100000) == 20, "level has a bounded cap")
	check(Skills.learn(0, {}, "sword").is_empty(), "cannot learn without earned points")
	var learned := Skills.learn(40, {}, "sword")
	check(learned.get("sword") == 1 and Skills.points(40, learned) == 0, "learning spends exactly one earned point")
	check(Skills.learn(40, learned, "light").is_empty(), "spent point cannot buy another skill")
	check(Skills.learn(120, {}, "ward").is_empty(), "prerequisite prevents skipping foundational skill")
	var ward := Skills.learn(120, learned, "ward")
	check(ward.get("ward") == 1 and ward.get("sword") == 1, "prerequisite unlocks defensive skill")
	check(not Skills.valid(40, {"sword": 2}), "save cannot contain unearned skill ranks")
	check(not Skills.valid(100000, {"sword": 4}), "rank cap enforced")
	check(not Skills.valid(100000, {"unknown": 1}), "unknown saved skill rejected")
	var legacy := {"version": 2, "region": "crossing", "position": [410, 490], "difficulty": 1,
		"quest": 3, "inventory": {"coin": 12}, "defeated": ["road_1", "road_2"], "gathered": [],
		"vitals": {"health": 80, "stamina": 100, "mana": 50}}
	var upgraded := Store.migrate(legacy)
	check(Store.validate(upgraded), "v2 state migrates to a complete valid v3 save")
	check(upgraded.get("xp") == 80 and upgraded.get("skills") == {}, "migration credits past encounters and quest without spending points")
	check(upgraded.get("vitals", {}).get("health") == 80, "migration preserves wounded character")
	print("Progression checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
