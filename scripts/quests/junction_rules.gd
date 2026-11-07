extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
const RECORDS := ["story_lake_report", "forest_report", "city_report"]
const REPORT := "junction_report"
const METHODS := ["junction:isolation:manual", "junction:isolation:aegis"]
const CHOICES := ["junction:choice:public", "junction:choice:private"]
const SITES := {"accept": ["workshop", "mentor"], "hear": ["rotunda", "steward"], "map": ["rotunda", "table"], "manual": ["rotunda", "console"], "aegis": ["rotunda", "console"], "prove": ["rotunda", "console"], "explain": ["rotunda", "steward"], "public": ["rotunda", "mentor"], "private": ["rotunda", "mentor"]}
static func ready(opened: Array) -> bool: return RECORDS.all(func(flag): return flag in opened)
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 4
	if "junction:proof" in flags: return 3
	if "junction:mapped" in flags: return 2
	return 1 if "junction:accepted" in flags else 0
static func valid(flags: Array, opened: Array) -> bool:
	var known := ["junction:accepted", "junction:heard", "junction:mapped", "junction:proof", "junction:explained"] + METHODS + CHOICES
	for flag in flags:
		if flag.begins_with("junction_") or (flag.begins_with("junction:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("junction:") or (flag.begins_with("junction_") and (flag != REPORT or opened.count(flag) > 1)): return false
	if not flags.any(func(flag): return flag in known) and REPORT not in opened: return true
	if not ready(opened) or "junction:accepted" not in flags: return false
	if "junction:mapped" in flags and "junction:heard" not in flags: return false
	var methods := flags.filter(func(flag): return flag in METHODS)
	if methods.size() > 1 or (not methods.is_empty() and "junction:mapped" not in flags): return false
	if "junction:proof" in flags and methods.size() != 1: return false
	if "junction:explained" in flags and "junction:proof" not in flags: return false
	var choices := flags.filter(func(flag): return flag in CHOICES)
	if choices.size() > 1 or (not choices.is_empty() and "junction:explained" not in flags): return false
	return (REPORT in opened) == (choices.size() == 1)
static func resolve(nature: Dictionary, skills: Dictionary, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, event: String, cooldown: float = 0, recharge: float = 0, measured: float = 0) -> Dictionary:
	if not Nature.valid(nature) or nature.form != "human" or not valid(flags, opened) or not SITES.has(event) or inventory.get("story_tool", 0) != 1: return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	for value in [cooldown, recharge, measured]:
		if not is_finite(value) or value < 0: return {}
	var current := stage(flags, opened)
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var resources := vitals.duplicate()
	var spent_cooldown := 0.0
	var spent_recharge := 0.0
	var xp := 0
	var trust := {}
	match event:
		"accept":
			if current != 0 or not ready(opened): return {}
			gathered.append("junction:accepted")
		"hear":
			if current != 1 or "junction:heard" in flags: return {}
			gathered.append("junction:heard")
		"map":
			if current != 1 or "junction:heard" not in flags: return {}
			gathered.append("junction:mapped")
		"manual", "aegis":
			if current != 2 or flags.any(func(flag): return flag in METHODS): return {}
			if event == "manual":
				if resources.stamina < 20: return {}
				resources.stamina -= 20
			else:
				if not Nature.can_spell(nature, "aegis") or cooldown > 0 or recharge > 0: return {}
				var spell := Magic.profile("aegis", skills)
				if spell.is_empty() or resources.mana < spell.cost: return {}
				resources.mana -= spell.cost
				spent_cooldown = spell.cooldown
				spent_recharge = spell.recharge
			gathered.append("junction:isolation:" + event)
		"prove":
			if current != 2 or not flags.any(func(flag): return flag in METHODS) or measured < 3: return {}
			gathered.append("junction:proof")
		"explain":
			if current != 3 or "junction:explained" in flags: return {}
			gathered.append("junction:explained")
		"public", "private":
			if current != 3 or "junction:explained" not in flags: return {}
			gathered.append("junction:choice:" + event)
			claimed.append(REPORT)
			xp = 80
			trust = {"roadfolk": 2} if event == "public" else {"wardens": 2}
	if not valid(gathered, claimed): return {}
	return {"gathered": gathered, "opened": claimed, "vitals": resources, "cooldown": spent_cooldown, "recharge": spent_recharge, "xp": xp, "trust": trust}
