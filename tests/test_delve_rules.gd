extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Generator = preload("res://scripts/world/delve_generator.gd")
const Rules = preload("res://scripts/quests/delve_rules.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func inside_obstacle(layout: Dictionary, point: Vector2, margin: float) -> bool:
	for rect in Generator.ROCK + Generator.FRAME + layout.walls + layout.pillars + layout.rubble:
		if rect.grow(margin).has_point(point): return true
	return false
func connected_without_rubble(layout: Dictionary) -> bool:
	var seen := {Generator.ENTRANCE: true}
	var queue: Array = [Generator.ENTRANCE]
	while not queue.is_empty():
		var cell: int = queue.pop_front()
		for other in Generator.neighbors(cell):
			var link := Generator.key(cell, other)
			if seen.has(other) or not layout.doors.has(link) or link == layout.rubble_loop: continue
			seen[other] = true
			queue.append(other)
	return seen.size() == Generator.COLS * Generator.ROWS
func run() -> void:
	var session := root.get_node("Session")
	check(Regions.exits("ruins").any(func(exit): return exit.destination == "hollow_1") and Regions.exits("hollow_1").any(func(exit): return exit.destination == "ruins"), "hollows connect to the old guardhouse and back to the surface")
	check(Generator.generate(1234, 2) == Generator.generate(1234, 2), "same seed and depth always give the same layout")
	var shapes := {}
	var all_ok := true
	var placement_ok := true
	var counts_ok := true
	var unique_ok := true
	var calm_ok := true
	for seed_value in range(1, 121):
		for depth in [1, 2, 3]:
			var layout := Generator.generate(seed_value * 7919, depth)
			if depth == 1: shapes[str(layout.tree) + layout.rubble_loop] = true
			if not connected_without_rubble(layout) or layout.tree.size() != 11 or layout.rubble.size() != 1 or layout.keystone == Generator.ENTRANCE or layout.keystone in Generator.neighbors(Generator.ENTRANCE): all_ok = false
			for entry in layout.enemies:
				if entry[1].distance_to(Vector2(230, 780)) < 420 or entry[1].distance_to(Vector2(175, 680)) < 420: calm_ok = false
			var ids := {}
			for entry in layout.enemies:
				if ids.has(entry[0]) or not entry[0].begins_with("hollow_%d_" % depth): unique_ok = false
				ids[entry[0]] = true
				if inside_obstacle(layout, entry[1], 30) or Generator.cell_rect(Generator.ENTRANCE).has_point(entry[1]): placement_ok = false
			for point in layout.herbs + layout.chests.map(func(chest): return chest.point) + ([layout.stairs] if layout.has("stairs") else []) + [layout.note, Vector2(230, 780), Vector2(175, 680), Vector2(250, 680)]:
				if inside_obstacle(layout, point, 20): placement_ok = false
			var guards: int = layout.enemies.filter(func(entry): return Generator.cell_rect(layout.keystone).has_point(entry[1])).size()
			if guards != Generator.GUARDS[depth].size() or layout.enemies.size() < 4 + depth or layout.enemies.size() > 14: counts_ok = false
			if layout.chests.filter(func(chest): return chest.get("hidden", false)).size() != 2 or layout.herbs.size() != 2: counts_ok = false
			if layout.has("stairs") != (depth < 3) or (depth == 3 and layout.chests.filter(func(chest): return chest.has("gear")).size() != 1): counts_ok = false
	check(all_ok, "every layout over 360 seeds/depths is connected on foot without rubble, keeps one rubble loop and a distant keystone room")
	check(placement_ok, "no enemy, herb, cache, stairs, note, camp or exit is generated inside a wall, pillar or rubble; the entrance room stays free of enemies")
	check(counts_ok, "each depth has its guards, two hidden caches, two herbs, sane enemy counts and stairs except the deepest")
	check(unique_ok, "enemy IDs are unique per depth and use the hollow namespace")
	check(calm_ok, "no generated enemy stands within reach of the entrance camp or exit, so rest and leaving stay safe")
	check(shapes.size() > 100, "different playthrough seeds dig genuinely different hollows: %d shapes" % shapes.size())
	# Save validation regenerates the layout from the stored seed.
	session.fresh()
	check(session.world_state.has("delve_seed") and session.Store.validate(session.snapshot(Vector2(410, 490))), "new playthrough stores its own valid hollow seed")
	var plain: Dictionary = session.snapshot(Vector2(410, 490))
	plain.world_state.erase("delve_seed")
	check(session.Store.validate(plain) and Rules.seed_of(plain.world_state) == plain.world_state.seed, "old v9 without the optional seed stays valid and falls back to the world seed")
	var bad_seed := plain.duplicate(true)
	bad_seed.world_state["delve_seed"] = -5
	check(not session.Store.validate(bad_seed), "malformed hollow seed is rejected")
	var layouts := Rules.layouts(plain.world_state)
	var first: Dictionary = layouts[1]
	var second: Dictionary = layouts[2]
	var data := plain.duplicate(true)
	data.region = "hollow_1"
	data.position = [250.0, 680.0]
	data.defeated.append(first.enemies[0][0])
	data.gathered.append("hollow_1:herb_%d_%d" % [first.herbs[0].x, first.herbs[0].y])
	data.opened.append(first.chests.filter(func(chest): return chest.get("hidden", false))[0].id)
	check(session.Store.validate(data), "real generated enemy, herb and cache IDs of the first depth are valid")
	var guards_of := func(depth: int) -> Array: return layouts[depth].chests.filter(func(chest): return chest.id == Rules.keystone(depth))[0].requires
	check(Rules.chest_depth("delve_keystone_3") == 3 and Rules.chest_depth("delve_cache_2_1") == 2 and Rules.chest_depth("delve_x") == 0, "chest IDs carry their own depth")
	for corruption in ["keystone_without_guards", "region_sealed", "foreign_enemy", "foreign_herb", "unknown_cache", "deeper_cache", "deeper_enemy", "keystone_order", "gear_without_keystone", "duplicate_enemy", "wrong_collection", "reserved_flag", "other_seed"]:
		var bad := data.duplicate(true)
		match corruption:
			"keystone_without_guards": bad.opened.append("delve_keystone_1")
			"region_sealed": bad.region = "hollow_2"
			"foreign_enemy": bad.defeated.append("hollow_1_e99")
			"foreign_herb": bad.gathered.append("hollow_1:herb_1_1")
			"unknown_cache": bad.opened.append("delve_cache_1_9")
			"deeper_cache": bad.opened.append(second.chests.filter(func(chest): return chest.get("hidden", false))[0].id)
			"deeper_enemy": bad.defeated.append(second.enemies[0][0])
			"keystone_order": bad.opened.append("delve_keystone_2")
			"gear_without_keystone": bad.gear_owned.append("deep_mail")
			"duplicate_enemy": bad.defeated.append(first.enemies[0][0])
			"wrong_collection": bad.gathered.append("delve_keystone_1")
			"reserved_flag": bad.opened.append("hollow_1_e0")
			"other_seed": bad.world_state["delve_seed"] = int(bad.world_state.seed) + 1
		check(not session.Store.validate(bad), "save rejects inconsistent hollow progress: " + corruption)
	data.opened.append("delve_keystone_1")
	data.defeated.append_array(guards_of.call(1).filter(func(id): return id not in data.defeated))
	data.region = "hollow_2"
	data.defeated.append(second.enemies[0][0])
	check(session.Store.validate(data), "first keystone opens the second depth for region, enemies and caches")
	data.opened.append_array(["delve_keystone_2", "delve_keystone_3"])
	for depth in [2, 3]: data.defeated.append_array(guards_of.call(depth).filter(func(id): return id not in data.defeated))
	data.gear_owned.append("deep_mail")
	check(session.Store.validate(data) and Rules.cleared(data.opened) == 3, "complete descent permits the unique armour")
	# Saves from before the hollows receive their own seed on load until hollow progress exists.
	session.fresh()
	var legacy: Dictionary = session.snapshot(Vector2(410, 490))
	legacy.world_state.erase("delve_seed")
	check(session.Store.write_game(legacy) == OK and session.load_saved() and session.world_state.has("delve_seed") and session.checkpoint.world_state.has("delve_seed") and session.Store.validate(session.snapshot(Vector2(410, 490))), "an old save without hollow progress gets its own playthrough seed on load")
	var started := legacy.duplicate(true)
	started.region = "hollow_1"
	started.position = [250.0, 680.0]
	check(session.Store.write_game(started) == OK and session.load_saved() and not session.world_state.has("delve_seed") and session.Store.validate(session.snapshot(Vector2(250, 680))), "existing hollow progress keeps the fallback seed so its layout never changes")
	session.fresh()
	check(not session.travel("hollow_2", Vector2(1650, 1000), {"health": 80.0, "stamina": 100.0, "mana": 90.0}) and session.region == "crossing", "backend refuses a sealed depth even when called directly")
	print("Delve rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
