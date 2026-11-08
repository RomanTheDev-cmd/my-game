extends RefCounted
# Deterministic layouts for the optional hollows below the old guardhouse.
# The same world seed and depth always give the same rooms, doors, enemies and caches.
const COLS := 4
const ROWS := 3
const ORIGIN := Vector2(120, 170)
const CELL := Vector2(420, 340)
const ENTRANCE := 4
const DOOR := 110.0
const THICK := 30.0
const DEPTHS := 3
const OFFSETS := [Vector2(-90, -70), Vector2(90, -70), Vector2(-90, 70), Vector2(90, 70), Vector2(0, 0), Vector2(0, -90), Vector2(0, 90)]
const KINDS := {1: ["melee", "melee", "ranged"], 2: ["melee", "ranged", "heavy", "echo"], 3: ["melee", "ranged", "heavy", "echo", "echo"]}
const GUARDS := {1: ["heavy"], 2: ["heavy", "echo"], 3: ["warden", "echo"]}
const KEYSTONE_ITEMS := {1: {"coin": 12, "potion": 1}, 2: {"coin": 16, "herb": 2, "potion": 1}, 3: {"coin": 24, "potion": 2}}
const ROCK := [Rect2(0, 0, 105, 1280), Rect2(0, 0, 1920, 155), Rect2(0, 1200, 1920, 80), Rect2(1815, 0, 105, 1280)]
# The frame ends at y 1200 so the map shows all four outer walls.
const FRAME := [Rect2(105, 155, 1710, 30), Rect2(105, 1170, 1710, 30), Rect2(105, 155, 30, 1045), Rect2(1785, 155, 30, 1045)]

static func cell_rect(index: int) -> Rect2:
	return Rect2(ORIGIN + Vector2(index % COLS, floori(index / float(COLS))) * CELL, CELL)
static func cell_center(index: int) -> Vector2:
	return cell_rect(index).get_center()
static func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var c := index % COLS
	var r := floori(index / float(COLS))
	if c > 0: result.append(index - 1)
	if c < COLS - 1: result.append(index + 1)
	if r > 0: result.append(index - COLS)
	if r < ROWS - 1: result.append(index + COLS)
	return result
static func key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]
static func _shuffle(values: Array, rng: RandomNumberGenerator) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = result[i]
		result[i] = result[j]
		result[j] = swap
	return result

static func generate(seed_value: int, depth: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int(seed_value)) * 1000003 + depth * 7919 + 17
	# Spanning tree from the entrance guarantees every room is reachable on foot.
	var visited := {ENTRANCE: true}
	var stack: Array[int] = [ENTRANCE]
	var tree: Array = []
	while not stack.is_empty():
		var current: int = stack.back()
		var options := neighbors(current).filter(func(cell): return not visited.has(cell))
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: int = options[rng.randi_range(0, options.size() - 1)]
		tree.append(key(current, chosen))
		visited[chosen] = true
		stack.append(chosen)
	var spare: Array = []
	for index in COLS * ROWS:
		for other in neighbors(index):
			if other > index and key(index, other) not in tree: spare.append(key(index, other))
	spare = _shuffle(spare, rng)
	var open_loop: String = spare[0] if spare.size() > 0 else ""
	var rubble_loop: String = spare[1] if spare.size() > 1 else ""
	# The keystone room is the farthest room by the walking tree, never right beside the entrance.
	var distance := {ENTRANCE: 0}
	var queue: Array[int] = [ENTRANCE]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for other in neighbors(current):
			if key(current, other) in tree and not distance.has(other):
				distance[other] = distance[current] + 1
				queue.append(other)
	var near := neighbors(ENTRANCE)
	var keystone := -1
	for index in COLS * ROWS:
		if index == ENTRANCE or index in near: continue
		if keystone < 0 or distance[index] > distance[keystone]: keystone = index
	# Walls between rooms, each connection with a door; one loop is choked by rubble.
	var walls: Array[Rect2] = []
	var rubble: Array[Rect2] = []
	var doors := {}
	for index in COLS * ROWS:
		for other in neighbors(index):
			if other < index: continue
			var link := key(index, other)
			var a := cell_rect(index)
			var vertical := other == index + 1
			var start: float = a.position.y if vertical else a.position.x
			var length: float = CELL.y if vertical else CELL.x
			var line: float = a.end.x if vertical else a.end.y
			var connected := link in tree or link == open_loop or link == rubble_loop
			var spans: Array = [[start, start + length]]
			if connected:
				var middle: float = start + length / 2 + rng.randi_range(-50, 50)
				doors[link] = Vector2(line, middle) if vertical else Vector2(middle, line)
				spans = [[start, middle - DOOR / 2], [middle + DOOR / 2, start + length]]
				if link == rubble_loop:
					rubble.append(Rect2(line - THICK / 2, middle - DOOR / 2, THICK, DOOR) if vertical else Rect2(middle - DOOR / 2, line - THICK / 2, DOOR, THICK))
			for span in spans:
				walls.append(Rect2(line - THICK / 2, span[0], THICK, span[1] - span[0]) if vertical else Rect2(span[0], line - THICK / 2, span[1] - span[0], THICK))
	# Room roles, contents and enemies.
	# Rooms beside the entrance stay calm so its camp and exit are genuinely safe.
	var calm: Array = _shuffle(["cache", "cache", "herb", "herb", "quiet", "quiet"], rng)
	var roles := {}
	for index in near: roles[index] = calm.pop_back()
	var far: Array = []
	for index in COLS * ROWS:
		if index != ENTRANCE and index != keystone and index not in near: far.append(index)
	far = _shuffle(far, rng)
	var plan: Array = _shuffle(calm + ["fight", "fight", "fight", "fight"], rng)
	for i in far.size(): roles[far[i]] = plan[i]
	roles[ENTRANCE] = "entrance"
	roles[keystone] = "keystone"
	var pillars: Array[Rect2] = []
	var enemies: Array = []
	var herbs: Array[Vector2] = []
	var chests: Array = []
	var marks: Array[Vector2] = []
	var caches := 0
	for index in COLS * ROWS:
		var center := cell_center(index)
		var role: String = roles[index]
		if role in ["fight", "quiet"] and rng.randf() < 0.5:
			for side in [-1, 1]: pillars.append(Rect2(center + Vector2(side * 110 - 20, -20), Vector2(40, 40)))
		var slots: Array = _shuffle(OFFSETS, rng)
		var take := func() -> Vector2: return center + slots.pop_back()
		var count := 0
		match role:
			"fight": count = rng.randi_range(1, 2) if depth == 1 else 2
			"cache", "herb": count = 0 if depth == 1 or index in near else rng.randi_range(0, 1)
		if role == "cache":
			caches += 1
			var point: Vector2 = take.call()
			chests.append({"id": "delve_cache_%d_%d" % [depth, caches], "point": point, "hidden": true, "items": {"coin": 4 + depth * 2, "herb": 1}})
			marks.append(point)
		if role == "herb": herbs.append(take.call())
		for i in count:
			var pool: Array = KINDS[depth]
			enemies.append(["hollow_%d_e%d" % [depth, enemies.size()], take.call(), pool[rng.randi_range(0, pool.size() - 1)]])
		if role == "keystone":
			var guards: Array = GUARDS[depth]
			var guard_ids: Array = []
			for i in guards.size():
				guard_ids.append("hollow_%d_e%d" % [depth, enemies.size()])
				enemies.append([guard_ids.back(), center + Vector2(-70 if i == 0 else 70, 20), guards[i]])
			var chest := {"id": "delve_keystone_%d" % depth, "point": center + Vector2(0, -80), "items": KEYSTONE_ITEMS[depth].duplicate(), "requires": guard_ids}
			if depth == DEPTHS: chest["gear"] = ["deep_mail"]
			chests.append(chest)
	for entry in enemies:
		if entry[2] == "melee": entry.resize(2)
	var keystone_center := cell_center(keystone)
	var result := {"depth": depth, "tree": tree, "open_loop": open_loop, "rubble_loop": rubble_loop, "doors": doors, "keystone": keystone, "roles": roles,
		"walls": walls, "rubble": rubble, "pillars": pillars, "enemies": enemies, "herbs": herbs, "chests": chests, "marks": marks,
		"note": Vector2(440, 600)}
	if depth < DEPTHS: result["stairs"] = keystone_center + Vector2(0, 95)
	return result
