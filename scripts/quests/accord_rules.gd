extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const REPORT := "accord_report"
const CHOICES := ["renewal", "release", "community"]
const IDENTITIES := ["human", "oath", "vampire", "werewolf", "returned", "wild_returned"]
const HEARD := ["accord:heard:witness", "accord:heard:crafter"]
const SITES := {"affirm": ["crossing", "mentor"], "accept": ["rotunda", "steward"], "hear_witness": ["rotunda", "witness"], "hear_crafter": ["rotunda", "crafter"], "renewal": ["rotunda", "table"], "release": ["rotunda", "table"], "community": ["rotunda", "table"]}
const CAMPS := {"terrace": Vector2(1380, 790), "woodroad": Vector2(1190, 620), "velshof": Vector2(1100, 880)}
const CACHES := {"terrace": {"id": "commons_terrace_supplies", "point": Vector2(1380, 790)}, "woodroad": {"id": "commons_woodroad_supplies", "point": Vector2(1190, 620)}, "velshof": {"id": "commons_velshof_supplies", "point": Vector2(1100, 880)}}
static func identity(nature: Dictionary) -> String:
	if nature.kind == "vampire": return "vampire"
	if nature.kind == "werewolf": return "werewolf"
	if "vampire" in nature.history: return "returned"
	if "werewolf" in nature.history: return "wild_returned"
	return "oath" if nature.gift in ["oath", "trail_oath"] else "human"
static func recorded(flags: Array) -> String:
	for value in IDENTITIES:
		if "accord:identity:" + value in flags: return value
	return ""
static func outcome(opened: Array) -> String:
	for value in CHOICES:
		if "accord_" + value in opened: return value
	return ""
static func ready(flags: Array, opened: Array) -> bool: return "rescue_report" in opened and "rescue:rested" in flags
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 4
	if "accord:accepted" in flags: return 3 if HEARD.all(func(flag): return flag in flags) else 2
	return 1 if recorded(flags) != "" else 0
static func valid(nature: Dictionary, flags: Array, opened: Array) -> bool:
	var known := ["accord:accepted"] + HEARD
	for value in IDENTITIES: known.append("accord:identity:" + value)
	var cache_ids: Array = CACHES.values().map(func(entry): return entry.id)
	for flag in flags:
		if flag in cache_ids or flag.begins_with("accord_") or (flag.begins_with("accord:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag in cache_ids and ("accord_community" not in opened or opened.count(flag) > 1): return false
		if flag.begins_with("accord:") or (flag.begins_with("accord_") and (flag not in [REPORT, "accord_renewal", "accord_release", "accord_community"] or opened.count(flag) > 1)): return false
	if not flags.any(func(flag): return flag in known) and REPORT not in opened and outcome(opened) == "": return true
	if not ready(flags, opened) or recorded(flags) == "": return false
	if flags.filter(func(flag): return flag.begins_with("accord:identity:")).size() != 1: return false
	var tag := recorded(flags)
	if tag in ["vampire", "returned"] and "vampire" not in nature.history: return false
	if tag in ["werewolf", "wild_returned"] and "werewolf" not in nature.history: return false
	if flags.any(func(flag): return flag in HEARD) and "accord:accepted" not in flags: return false
	var choices := opened.filter(func(flag): return flag in ["accord_renewal", "accord_release", "accord_community"])
	if choices.size() > 1 or (not choices.is_empty() and ("accord:accepted" not in flags or not HEARD.all(func(flag): return flag in flags))): return false
	return (REPORT in opened) == (choices.size() == 1)
static func resolve(nature: Dictionary, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, event: String) -> Dictionary:
	if not Nature.valid(nature) or nature.form != "human" or not valid(nature, flags, opened) or not ready(flags, opened) or not SITES.has(event) or REPORT in opened or inventory.get("story_tool", 0) != 1: return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var xp := 0
	var trust := {}
	match event:
		"affirm":
			if recorded(flags) == identity(nature): return {}
			for value in IDENTITIES: gathered.erase("accord:identity:" + value)
			gathered.append("accord:identity:" + identity(nature))
		"accept":
			if stage(flags, opened) != 1 or recorded(flags) != identity(nature): return {}
			gathered.append("accord:accepted")
		"hear_witness", "hear_crafter":
			var flag := "accord:heard:" + event.trim_prefix("hear_")
			if "accord:accepted" not in flags or flag in flags: return {}
			gathered.append(flag)
		"renewal", "release", "community":
			if stage(flags, opened) != 3 or recorded(flags) != identity(nature): return {}
			claimed.append_array([REPORT, "accord_" + event])
			xp = 100
			trust = {"roadfolk": 1, "wardens": 1, "tenders": 1}
	if not valid(nature, gathered, claimed): return {}
	return {"gathered": gathered, "opened": claimed, "vitals": vitals.duplicate(), "xp": xp, "trust": trust}
