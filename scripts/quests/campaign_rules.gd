extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const REPORT := "story_lake_report"
const TOOL := "story_tool"
const TARGET := [1, 2, 0]
const METHODS := ["story:lake:method:manual", "story:lake:method:blood", "story:lake:method:scent"]
const REPORTS := ["story:lake:report:share", "story:lake:report:provision"]
const SITES := {"greet": ["workshop", "mentor"], "accept": ["workshop", "mentor"], "report_share": ["workshop", "mentor"], "report_provision": ["workshop", "mentor"],
	"hear": ["terrace", "witness"], "consent": ["terrace", "witness"], "inspect": ["terrace", "marks"], "turn_a": ["terrace", "control"], "turn_b": ["terrace", "control"], "turn_c": ["terrace", "control"],
	"manual": ["terrace", "control"], "blood": ["terrace", "control"], "scent": ["terrace", "shore"]}
static func positions(flags: Array) -> Array:
	var result := [0, 0, 0]
	for i in 3:
		for value in [1, 2]:
			if "story:dial:%s:%d" % [["a", "b", "c"][i], value] in flags: result[i] = value
	return result
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 5
	if flags.any(func(flag): return flag in METHODS): return 4
	if "story:lake:heard" in flags and "story:lake:marks" in flags: return 3
	if "story:accepted" in flags: return 2
	return 1 if "story:met" in flags else 0
static func valid(nature: Dictionary, quest: int, flags: Array, opened: Array, inventory: Dictionary) -> bool:
	var known := ["story:met", "story:accepted", "story:lake:heard", "story:lake:marks", "story:lake:consent"] + METHODS + REPORTS
	for id in ["a", "b", "c"]:
		for value in [1, 2]: known.append("story:dial:%s:%d" % [id, value])
	for flag in flags:
		if flag.begins_with("story_") or (flag.begins_with("story:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("story:") or (flag.begins_with("story_") and (flag != REPORT or opened.count(flag) > 1)): return false
	if (inventory.get(TOOL, 0) != 0 and inventory.get(TOOL, 0) != 1) or (inventory.get(TOOL, 0) == 1) != ("story:met" in flags): return false
	if "story:met" not in flags: return not flags.any(func(flag): return flag in known) and REPORT not in opened
	if quest != 3: return false
	if "story:accepted" not in flags: return flags.filter(func(flag): return flag in known) == ["story:met"] and REPORT not in opened
	var methods := flags.filter(func(flag): return flag in METHODS)
	var reports := flags.filter(func(flag): return flag in REPORTS)
	if methods.size() > 1 or reports.size() > 1: return false
	var prepared := "story:lake:heard" in flags and "story:lake:marks" in flags
	for id in ["a", "b", "c"]:
		var a: bool = "story:dial:%s:1" % id in flags
		var b: bool = "story:dial:%s:2" % id in flags
		if (a and b) or ((a or b) and not prepared): return false
	if "story:lake:consent" in flags and ("story:lake:heard" not in flags or "vampire" not in nature.history): return false
	if METHODS[1] in flags and "story:lake:consent" not in flags: return false
	if not methods.is_empty() and not prepared: return false
	if METHODS[0] in flags and positions(flags) != TARGET: return false
	if METHODS[1] in flags and "vampire" not in nature.history: return false
	if METHODS[2] in flags and "werewolf" not in nature.history: return false
	if not reports.is_empty() and methods.is_empty(): return false
	return (REPORT in opened) == (not reports.is_empty())
static func resolve(nature: Dictionary, quest: int, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, event: String) -> Dictionary:
	if not Nature.valid(nature) or not valid(nature, quest, flags, opened, inventory) or not SITES.has(event): return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	if nature.form != "human" and not (event == "scent" and nature.kind == "werewolf" and nature.form == "wolf"): return {}
	var next := nature.duplicate(true)
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var items := inventory.duplicate()
	var resources := vitals.duplicate()
	var xp := 0
	var trust := 0
	var current := stage(flags, opened)
	match event:
		"greet":
			if current != 0 or quest != 3: return {}
			gathered.append("story:met")
			items[TOOL] = 1
		"accept":
			if current != 1: return {}
			gathered.append("story:accepted")
		"hear", "inspect":
			var flag := "story:lake:" + ("heard" if event == "hear" else "marks")
			if current != 2 or flag in flags: return {}
			gathered.append(flag)
		"consent":
			if current not in [2, 3] or nature.kind != "vampire" or "story:lake:heard" not in flags or "story:lake:consent" in flags: return {}
			gathered.append("story:lake:consent")
		"turn_a", "turn_b", "turn_c":
			if current != 3 or resources.stamina < 2: return {}
			var id := event.trim_prefix("turn_")
			var index: int = ["a", "b", "c"].find(id)
			var value: int = (positions(flags)[index] + 1) % 3
			for old in [1, 2]: gathered.erase("story:dial:%s:%d" % [id, old])
			if value > 0: gathered.append("story:dial:%s:%d" % [id, value])
			resources.stamina -= 2
		"manual", "blood", "scent":
			if current != 3: return {}
			if event == "manual" and positions(flags) != TARGET: return {}
			if event == "blood":
				if nature.kind != "vampire" or "story:lake:consent" not in flags or nature.blood < 30 or resources.mana < 15: return {}
				next.blood -= 20
				resources.mana -= 15
			if event == "scent":
				if nature.kind != "werewolf" or nature.form != "wolf" or nature.resolve < 30: return {}
				next.resolve -= 20
			gathered.append("story:lake:method:" + event)
		"report_share", "report_provision":
			if current != 4: return {}
			if event == "report_provision":
				if int(items.get("coin", 0)) > 987: return {}
				items["coin"] = int(items.get("coin", 0)) + 12
			trust = 2 if event == "report_share" else 1
			gathered.append("story:lake:report:" + event.trim_prefix("report_"))
			claimed.append(REPORT)
			xp = 80
	if not valid(next, quest, gathered, claimed, items): return {}
	return {"nature": next, "gathered": gathered, "opened": claimed, "inventory": items, "vitals": resources, "xp": xp, "trust": trust}
