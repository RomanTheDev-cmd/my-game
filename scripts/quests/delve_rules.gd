extends RefCounted
# Access and save validation for the generated hollows. Region/enemy/herb IDs use hollow*,
# claimed caches use delve_*; the layout is regenerated from the stored seed to check every ID.
const Generator = preload("res://scripts/world/delve_generator.gd")
const DEPTHS := 3
const GEAR := "deep_mail"
static func region(depth: int) -> String: return "hollow_%d" % depth
static func depth_of(region_id: String) -> int:
	for depth in range(1, DEPTHS + 1):
		if region_id == region(depth): return depth
	return 0
static func seed_of(world_state: Dictionary) -> int:
	return int(world_state.get("delve_seed", world_state.get("seed", 0)))
static func keystone(depth: int) -> String: return "delve_keystone_%d" % depth
static func chest_depth(id: String) -> int:
	var parts := id.split("_")
	return int(parts[2]) if id.begins_with("delve_") and parts.size() >= 3 and parts[2].is_valid_int() else 0
static func progress(region_id: String, gathered: Array, defeated: Array, opened: Array, owned: Array) -> bool:
	return region_id.begins_with("hollow") or gathered.any(func(flag): return flag.begins_with("hollow") or flag.begins_with("delve")) or defeated.any(func(flag): return flag.begins_with("hollow") or flag.begins_with("delve")) or opened.any(func(flag): return flag.begins_with("hollow") or flag.begins_with("delve")) or GEAR in owned
static func can_enter(depth: int, opened: Array) -> bool:
	return depth == 1 or (depth > 1 and depth <= DEPTHS and keystone(depth - 1) in opened)
static func cleared(opened: Array) -> int:
	var count := 0
	for depth in range(1, DEPTHS + 1):
		if keystone(depth) in opened: count = depth
	return count
static func layouts(world_state: Dictionary) -> Dictionary:
	var result := {}
	for depth in range(1, DEPTHS + 1): result[depth] = Generator.generate(seed_of(world_state), depth)
	return result
static func valid(world_state: Dictionary, region_id: String, gathered: Array, defeated: Array, opened: Array, owned: Array) -> bool:
	if not progress(region_id, gathered, defeated, opened, owned): return true
	var maps := layouts(world_state)
	var enemies := {}
	var herbs := {}
	var chests := {}
	for depth in maps:
		for entry in maps[depth].enemies: enemies[entry[0]] = depth
		for point in maps[depth].herbs: herbs[region(depth) + ":herb_%d_%d" % [point.x, point.y]] = depth
		for entry in maps[depth].chests:
			chests[entry.id] = depth
			if entry.id in opened and not entry.get("requires", []).all(func(guard): return guard in defeated): return false
	if region_id.begins_with("hollow") and (depth_of(region_id) == 0 or not can_enter(depth_of(region_id), opened)): return false
	for flag in gathered:
		if flag.begins_with("delve"): return false
		if flag.begins_with("hollow") and (not herbs.has(flag) or gathered.count(flag) > 1 or not can_enter(herbs[flag], opened)): return false
	for flag in defeated:
		if flag.begins_with("delve"): return false
		if flag.begins_with("hollow") and (not enemies.has(flag) or defeated.count(flag) > 1 or not can_enter(enemies[flag], opened)): return false
	for flag in opened:
		if flag.begins_with("hollow"): return false
		if flag.begins_with("delve") and (not chests.has(flag) or opened.count(flag) > 1 or not can_enter(chests[flag], opened)): return false
	for depth in range(2, DEPTHS + 1):
		if keystone(depth) in opened and keystone(depth - 1) not in opened: return false
	return GEAR not in owned or keystone(DEPTHS) in opened
