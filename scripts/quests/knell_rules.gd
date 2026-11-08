extends RefCounted
# Optional undercroft case. Story flags use knell:* / knell_*; the region, its enemies
# and herbs use undercroft* so world identifiers never collide with progress flags.
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Accord = preload("res://scripts/quests/accord_rules.gd")
const REGION := "undercroft"
const ACCEPTED := "knell:accepted"
const PLAQUES := ["hall", "gallery", "ossuary"]
const BELL := "undercroft_bell"
const ECHOES := ["undercroft_echo_1", "undercroft_echo_2", "undercroft_echo_3"]
const REPORT := "knell_report"
const CHOICES := ["keeper", "kept"]
const SUPPLIES := "knell_supplies"
const CACHE := "knell_cache"
const TONGUE := "bell_tongue"
const COINS := 20
const SITES := {"accept": ["crossing", "keeper"], "read_hall": [REGION, "hall"], "read_gallery": [REGION, "gallery"], "read_ossuary": [REGION, "ossuary"], "keeper": ["crossing", "keeper"], "kept": ["crossing", "keeper"]}
static func available(opened: Array) -> bool: return Accord.REPORT in opened
static func can_enter(flags: Array) -> bool: return ACCEPTED in flags
static func read_count(flags: Array) -> int: return PLAQUES.filter(func(id): return "knell:plaque:" + id in flags).size()
static func recorded(flags: Array) -> String:
	for value in Accord.IDENTITIES:
		if "knell:identity:" + value in flags: return value
	return ""
static func outcome(opened: Array) -> String:
	for value in CHOICES:
		if "knell_" + value in opened: return value
	return ""
static func stage(flags: Array, defeated: Array, opened: Array) -> int:
	if REPORT in opened: return 4
	if BELL in defeated: return 3
	if ACCEPTED in flags: return 2 if read_count(flags) == PLAQUES.size() else 1
	return 0
static func armed(flags: Array, defeated: Array) -> bool: return ACCEPTED in flags and read_count(flags) == PLAQUES.size() and BELL not in defeated
static func _local(flag: String) -> bool: return flag.begins_with("undercroft")
static func valid(nature: Dictionary, flags: Array, defeated: Array, opened: Array, owned: Array, region: String) -> bool:
	var known := [ACCEPTED]
	for id in PLAQUES: known.append("knell:plaque:" + id)
	for value in Accord.IDENTITIES: known.append("knell:identity:" + value)
	for flag in flags:
		if flag.begins_with("knell_") or flag in [BELL, SUPPLIES, CACHE] + ECHOES or (_local(flag) and not flag.begins_with("undercroft:herb_")): return false
		if flag.begins_with("knell:") and (flag not in known or flags.count(flag) > 1): return false
	for flag in defeated:
		if flag.begins_with("knell"): return false
		if flag in [BELL] + ECHOES and defeated.count(flag) > 1: return false
		if _local(flag) and flag not in [BELL] + ECHOES: return false
	for flag in opened:
		if flag.begins_with("knell:") or _local(flag): return false
		if flag.begins_with("knell_") and (flag not in [REPORT, SUPPLIES, CACHE, "knell_keeper", "knell_kept"] or opened.count(flag) > 1): return false
	if owned.count(TONGUE) > 1 or (TONGUE in owned and "knell_kept" not in opened): return false
	var started := ACCEPTED in flags
	var local_progress := flags.any(func(flag): return _local(flag)) or defeated.any(func(flag): return _local(flag)) or opened.any(func(flag): return flag in [SUPPLIES, CACHE])
	if not started:
		return not flags.any(func(flag): return flag in known) and not local_progress and not opened.any(func(flag): return flag.begins_with("knell_")) and region != REGION
	if not available(opened): return false
	var identities := flags.filter(func(flag): return flag.begins_with("knell:identity:"))
	if identities.size() != 1: return false
	var tag := recorded(flags)
	if tag in ["vampire", "returned"] and "vampire" not in nature.history: return false
	if tag in ["werewolf", "wild_returned"] and "werewolf" not in nature.history: return false
	if SUPPLIES in opened and "accord_community" not in opened: return false
	if BELL in defeated and read_count(flags) != PLAQUES.size(): return false
	if CACHE in opened and BELL not in defeated: return false
	var choices := opened.filter(func(flag): return flag in ["knell_keeper", "knell_kept"])
	if choices.size() > 1 or (not choices.is_empty() and BELL not in defeated): return false
	return (REPORT in opened) == (choices.size() == 1)
static func resolve(nature: Dictionary, flags: Array, defeated: Array, opened: Array, inventory: Dictionary, owned: Array, vitals: Dictionary, event: String, region: String = "crossing") -> Dictionary:
	if not Nature.valid(nature) or not valid(nature, flags, defeated, opened, owned, region) or not available(opened): return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	var gathered := flags.duplicate()
	var beaten := defeated.duplicate()
	var claimed := opened.duplicate()
	var items := inventory.duplicate()
	var gear := owned.duplicate()
	var xp := 0
	var trust := {}
	var current := stage(flags, defeated, opened)
	if event != "silence" and nature.form != "human": return {}
	# Each step happens only where it physically can: names below the chapel, choices with the keeper.
	if (REGION if event == "silence" else SITES.get(event, [""])[0]) != region: return {}
	match event:
		"accept":
			if current != 0: return {}
			gathered.append_array([ACCEPTED, "knell:identity:" + Accord.identity(nature)])
		"read_hall", "read_gallery", "read_ossuary":
			var flag := "knell:plaque:" + event.trim_prefix("read_")
			if current != 1 or flag in flags: return {}
			gathered.append(flag)
			xp = 10
		"silence":
			if current != 2: return {}
			beaten.append(BELL)
			xp = 120
		"keeper", "kept":
			if current != 3: return {}
			claimed.append_array([REPORT, "knell_" + event])
			xp = 80
			if event == "keeper":
				items["coin"] = mini(999, int(items.get("coin", 0)) + COINS)
				trust = {"roadfolk": 1}
			else:
				gear.append(TONGUE)
		_: return {}
	if not valid(nature, gathered, beaten, claimed, gear, region): return {}
	return {"gathered": gathered, "defeated": beaten, "opened": claimed, "inventory": items, "owned": gear, "vitals": vitals.duplicate(), "xp": xp, "trust": trust}
