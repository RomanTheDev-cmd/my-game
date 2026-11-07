extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Campaign = preload("res://scripts/quests/campaign_rules.gd")
const PASSAGE := "forest_passage"
const REPORT := "forest_report"
const POINTS := [Vector2(700, 620), Vector2(1020, 780), Vector2(1380, 620)]
const OUTCOMES := ["forest:outcome:commons", "forest:outcome:watch"]
const AIDS := ["forest:aid:brief", "forest:aid:blood"]
static func progress(flags: Array) -> int:
	var count := 0
	for i in 3:
		if "forest:step:%d:work" % i in flags or "forest:step:%d:howl" % i in flags: count += 1
	return count
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 3
	if progress(flags) == 3: return 2
	return 1 if "forest:accepted" in flags else 0
static func valid(nature: Dictionary, flags: Array, opened: Array) -> bool:
	var known := ["forest:accepted"] + OUTCOMES + AIDS
	for i in 3:
		for method in ["work", "howl"]: known.append("forest:step:%d:%s" % [i, method])
	for flag in flags:
		if flag.begins_with("forest_") or (flag.begins_with("forest:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("forest:") or (flag.begins_with("forest_") and (flag not in [PASSAGE, REPORT] or opened.count(flag) > 1)): return false
	var present := flags.any(func(flag): return flag in known) or PASSAGE in opened or REPORT in opened
	if not present: return true
	if "forest:accepted" not in flags or "story:accepted" not in flags: return false
	if flags.filter(func(flag): return flag in AIDS).size() > 1: return false
	if AIDS[1] in flags and "vampire" not in nature.history: return false
	var steps := progress(flags)
	for i in 3:
		var work: bool = "forest:step:%d:work" % i in flags
		var howl: bool = "forest:step:%d:howl" % i in flags
		if (work and howl) or ((work or howl) != (i < steps)): return false
		if howl and "werewolf" not in nature.history: return false
	if (PASSAGE in opened) != (steps == 3): return false
	var outcomes := flags.filter(func(flag): return flag in OUTCOMES)
	if outcomes.size() > 1 or (not outcomes.is_empty() and steps != 3): return false
	return (REPORT in opened) == (outcomes.size() == 1)
static func resolve(nature: Dictionary, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, event: String) -> Dictionary:
	if not Nature.valid(nature) or not valid(nature, flags, opened) or inventory.get(Campaign.TOOL, 0) != 1: return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	if nature.form != "human" and not (event == "howl" and nature.kind == "werewolf" and nature.form == "wolf"): return {}
	var next := nature.duplicate(true)
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var resources := vitals.duplicate()
	var trust := {}
	var xp := 0
	var current := stage(flags, opened)
	match event:
		"accept":
			if current != 0 or "story:accepted" not in flags: return {}
			gathered.append("forest:accepted")
		"aid_brief", "aid_blood":
			if current != 1 or progress(flags) != 0 or flags.any(func(flag): return flag in AIDS): return {}
			if event == "aid_blood":
				if nature.kind != "vampire" or nature.blood < 25 or resources.mana < 10: return {}
				next.blood -= 15
				resources.mana -= 10
			else:
				if resources.stamina < 15: return {}
				resources.stamina -= 15
			gathered.append("forest:aid:" + event.trim_prefix("aid_"))
		"work", "howl":
			if current != 1: return {}
			if event == "howl":
				if nature.kind != "werewolf" or nature.form != "wolf" or nature.resolve < 22: return {}
				next.resolve -= 12
			else:
				if resources.stamina < 12: return {}
				resources.stamina -= 12
			gathered.append("forest:step:%d:%s" % [progress(flags), event])
			if progress(gathered) == 3: claimed.append(PASSAGE)
		"commons", "watch":
			if current != 2: return {}
			gathered.append("forest:outcome:" + event)
			claimed.append(REPORT)
			xp = 90
			trust = {"tenders": 2} if event == "commons" else {"tenders": 1, "wardens": 1}
		_: return {}
	if not valid(next, gathered, claimed): return {}
	return {"nature": next, "gathered": gathered, "opened": claimed, "vitals": resources, "xp": xp, "trust": trust}
