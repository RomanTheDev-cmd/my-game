extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const REPORT := "rescue_report"
const METHODS := ["rescue:method:tools", "rescue:method:blood", "rescue:method:scent"]
const COILS := {"north": Vector2(980, 430), "south": Vector2(980, 870)}
const EXIT := Vector2(280, 650)
const SITES := {"accept": ["rotunda", "mentor"], "tools": ["underhall", "mentor"], "blood": ["underhall", "mentor"], "scent": ["underhall", "mentor"], "free": ["underhall", "mentor"], "safe": ["underhall", "exit"], "report": ["rotunda", "mentor"], "rest": ["crossing", "mentor"], "keep": ["crossing", "mentor"], "release": ["crossing", "mentor"]}
static func method(flags: Array) -> String:
	for value in ["tools", "blood", "scent"]:
		if "rescue:method:" + value in flags: return value
	return ""
static func cut(flags: Array, side: String) -> String:
	for value in ["manual", "light", "claw"]:
		if "rescue:cut:%s:%s" % [side, value] in flags: return value
	return ""
static func disconnected(flags: Array) -> bool: return cut(flags, "north") != "" and cut(flags, "south") != ""
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 5
	if "rescue:safe" in flags: return 4
	if "rescue:freed" in flags: return 3
	if method(flags) != "": return 2
	return 1 if "rescue:accepted" in flags else 0
static func valid(nature: Dictionary, flags: Array, opened: Array) -> bool:
	var known := ["rescue:accepted", "rescue:blood_consent", "rescue:freed", "rescue:safe", "rescue:rested", "rescue:boundary:keep", "rescue:boundary:release"] + METHODS
	for side in COILS:
		for value in ["manual", "light", "claw"]: known.append("rescue:cut:%s:%s" % [side, value])
	for flag in flags:
		if flag.begins_with("rescue_") or (flag.begins_with("rescue:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("rescue:") or (flag.begins_with("rescue_") and (flag != REPORT or opened.count(flag) > 1)): return false
	if not flags.any(func(flag): return flag in known) and REPORT not in opened: return true
	if "preparation_report" not in opened or "rescue:accepted" not in flags or flags.filter(func(flag): return flag in METHODS).size() > 1: return false
	var mode := method(flags)
	if ("rescue:blood_consent" in flags) != (mode == "blood"): return false
	if mode == "blood" and "vampire" not in nature.history: return false
	if mode == "scent" and "werewolf" not in nature.history: return false
	for side in COILS:
		var values := flags.filter(func(flag): return flag.begins_with("rescue:cut:" + side + ":"))
		if values.size() > 1 or (not values.is_empty() and mode == ""): return false
		if cut(flags, side) == "claw" and mode != "scent": return false
	if "rescue:freed" in flags and not disconnected(flags): return false
	if "rescue:safe" in flags and "rescue:freed" not in flags: return false
	if REPORT in opened and "rescue:safe" not in flags: return false
	if "rescue:rested" in flags and REPORT not in opened: return false
	var boundaries := flags.filter(func(flag): return flag in ["rescue:boundary:keep", "rescue:boundary:release"])
	if boundaries.size() > 1 or (not boundaries.is_empty() and (mode != "blood" or "rescue:rested" not in flags)): return false
	return mode != "blood" or ("rescue:rested" in flags) == (boundaries.size() == 1)
static func resolve(nature: Dictionary, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, event: String, calm: bool = false, impact: bool = false, arrived: bool = false) -> Dictionary:
	if not Nature.valid(nature) or not valid(nature, flags, opened) or inventory.get("story_tool", 0) != 1: return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	var parts := event.split("_")
	var cutting: bool = parts.size() == 2 and parts[0] in ["manual", "light", "claw"] and COILS.has(parts[1])
	if not cutting and not SITES.has(event): return {}
	if nature.form != "human" and not (cutting and parts[0] == "claw"): return {}
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var changed := nature.duplicate(true)
	var resources := vitals.duplicate()
	var mode := method(flags)
	var xp := 0
	var trust := {}
	if event == "accept":
		if "preparation_report" not in opened or stage(flags, opened) != 0: return {}
		gathered.append("rescue:accepted")
	elif "rescue:accepted" not in flags: return {}
	elif cutting:
		if stage(flags, opened) != 2 or cut(flags, parts[1]) != "": return {}
		match parts[0]:
			"manual":
				var effort := 10 if mode == "blood" else 18
				if not calm or resources.stamina < effort: return {}
				resources.stamina -= effort
			"light":
				if not impact or not calm or not Nature.can_spell(nature, "light"): return {}
			"claw":
				if not impact or mode != "scent" or nature.kind != "werewolf" or nature.form not in ["wolf", "hybrid"] or nature.resolve < 12: return {}
				changed.resolve -= 12
				if changed.resolve == 0: changed.form = "human"
		gathered.append("rescue:cut:%s:%s" % [parts[1], parts[0]])
	else:
		match event:
			"tools", "blood", "scent":
				if stage(flags, opened) != 1: return {}
				if event == "blood":
					if nature.kind != "vampire" or nature.blood < 20: return {}
					changed.blood -= 20
					gathered.append("rescue:blood_consent")
				if event == "scent" and nature.kind != "werewolf": return {}
				gathered.append("rescue:method:" + event)
			"free":
				if stage(flags, opened) != 2 or not disconnected(flags): return {}
				gathered.append("rescue:freed")
			"safe":
				if stage(flags, opened) != 3 or not arrived: return {}
				gathered.append("rescue:safe")
			"report":
				if stage(flags, opened) != 4: return {}
				claimed.append(REPORT)
				xp = 120
				trust = {"roadfolk": 2, "tenders": 1}
			"rest", "keep", "release":
				if stage(flags, opened) != 5 or "rescue:rested" in flags: return {}
				if (event == "rest") == (mode == "blood"): return {}
				gathered.append("rescue:rested")
				if event != "rest": gathered.append("rescue:boundary:" + event)
	if not Nature.valid(changed) or not valid(changed, gathered, claimed): return {}
	return {"nature": changed, "gathered": gathered, "opened": claimed, "vitals": resources, "xp": xp, "trust": trust}
