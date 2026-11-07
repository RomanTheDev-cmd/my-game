extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const REPORT := "preparation_report"
const RECRUITS := ["prep:consent:witness", "prep:consent:crafter"]
const LAYOUTS := ["prep:layout:lake_north", "prep:layout:city_north"]
const SITES := {"accept": ["rotunda", "steward"], "invite_witness": ["terrace", "witness"], "invite_crafter": ["velshof", "crafter"], "layout_lake": ["rotunda", "table"], "layout_city": ["rotunda", "table"], "tune_north": ["rotunda", "north"], "tune_south": ["rotunda", "south"], "prove": ["rotunda", "finish"], "report": ["rotunda", "mentor"]}
const CONTROLS := {"north": Vector2(1050, 430), "south": Vector2(1050, 870), "gate": Vector2(1580, 650), "finish": Vector2(520, 650)}
const POSTS := {"north": Vector2(1170, 430), "south": Vector2(1170, 870)}
const ROUTE := [Vector2(1420, 650), Vector2(1080, 650), Vector2(780, 650), Vector2(520, 650)]
static func angle(flags: Array, side: String) -> int:
	for value in 3:
		if "prep:%s:%d" % [side, value] in flags: return value
	return 0
static func target(flags: Array, side: String) -> int:
	if side == "north": return 2 if "junction:choice:private" in flags else 1
	return 2 if "city:outcome:release" in flags else 1
static func layout(flags: Array) -> String:
	if LAYOUTS[0] in flags: return "lake"
	if LAYOUTS[1] in flags: return "city"
	return ""
static func post(flags: Array, role: String) -> Vector2:
	if layout(flags) == "": return Vector2(480, 430) if role == "witness" else Vector2(480, 940)
	return POSTS.north if (role == "witness") == (layout(flags) == "lake") else POSTS.south
static func configured(flags: Array) -> bool:
	return RECRUITS.all(func(flag): return flag in flags) and layout(flags) != "" and angle(flags, "north") == target(flags, "north") and angle(flags, "south") == target(flags, "south")
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 4
	if "prep:tested" in flags: return 3
	if RECRUITS.all(func(flag): return flag in flags): return 2
	return 1 if "prep:accepted" in flags else 0
static func valid(flags: Array, opened: Array) -> bool:
	var known := ["prep:accepted", "prep:tested"] + RECRUITS + LAYOUTS
	for side in ["north", "south"]:
		for value in 3: known.append("prep:%s:%d" % [side, value])
	for flag in flags:
		if flag.begins_with("preparation_") or (flag.begins_with("prep:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("prep:") or (flag.begins_with("preparation_") and (flag != REPORT or opened.count(flag) > 1)): return false
	if not flags.any(func(flag): return flag in known) and REPORT not in opened: return true
	if "junction_report" not in opened or "prep:accepted" not in flags: return false
	if flags.filter(func(flag): return flag in LAYOUTS).size() > 1: return false
	if layout(flags) != "" and not RECRUITS.all(func(flag): return flag in flags): return false
	for side in ["north", "south"]:
		if flags.filter(func(flag): return flag.begins_with("prep:" + side + ":")).size() > 1: return false
	if "prep:tested" in flags and not configured(flags): return false
	return REPORT not in opened or "prep:tested" in flags
static func resolve(nature: Dictionary, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, event: String, rehearsed: bool = false) -> Dictionary:
	if not Nature.valid(nature) or nature.form != "human" or not valid(flags, opened) or not SITES.has(event) or inventory.get("story_tool", 0) != 1 or stage(flags, opened) == 4: return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var xp := 0
	var trust := {}
	if event == "accept":
		if "junction_report" not in opened or "prep:accepted" in flags: return {}
		gathered.append("prep:accepted")
	else:
		if "prep:accepted" not in flags: return {}
		match event:
			"invite_witness", "invite_crafter":
				var flag := "prep:consent:" + event.trim_prefix("invite_")
				if flag in flags or "prep:tested" in flags: return {}
				gathered.append(flag)
			"layout_lake", "layout_city":
				var chosen := event.trim_prefix("layout_")
				if not RECRUITS.all(func(flag): return flag in flags) or "prep:tested" in flags or layout(flags) == chosen: return {}
				for flag in LAYOUTS: gathered.erase(flag)
				gathered.append("prep:layout:" + chosen + "_north")
			"tune_north", "tune_south":
				if "prep:tested" in flags: return {}
				var side := event.trim_prefix("tune_")
				for value in 3: gathered.erase("prep:%s:%d" % [side, value])
				gathered.append("prep:%s:%d" % [side, (angle(flags, side) + 1) % 3])
			"prove":
				if not rehearsed or "prep:tested" in flags or not configured(flags): return {}
				gathered.append("prep:tested")
			"report":
				if "prep:tested" not in flags: return {}
				claimed.append(REPORT)
				xp = 60
				trust = {"roadfolk": 1, "wardens": 1}
	if not valid(gathered, claimed): return {}
	return {"gathered": gathered, "opened": claimed, "vitals": vitals.duplicate(), "xp": xp, "trust": trust}
