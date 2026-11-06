extends RefCounted
const CACHES := ["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"]
const TRAILS := ["pack:trail_0", "pack:trail_1", "pack:trail_2"]
const KNOWN := ["pack:closed", "pack:invited", "pack:heard", "pack:accepted", "pack:declined", "pack:mastery", "pack:return_started", "pack:release_den", "pack:release_word", "pack:returned", "pack:trail_0", "pack:trail_1", "pack:trail_2"]
const SITES := {"invite": ["thicket", "tracker"], "trail_0": ["thicket", "trail_0"], "trail_1": ["thicket", "trail_1"], "trail_2": ["thicket", "trail_2"],
	"hear": ["workshop", "warden"], "accept": ["thicket", "tracker"], "decline": ["thicket", "tracker"], "return_start": ["thicket", "tracker"],
	"release_den": ["thicket", "den"], "release_word": ["crossing", "keeper"], "return_finish": ["thicket", "tracker"]}
static func moon(minutes: float) -> float:
	return (1.0 - cos(fposmod(minutes, 11520) / 11520 * TAU)) * 0.5 if is_finite(minutes) else 0.0
static func prepared(flags: Array) -> bool:
	return "pack:heard" in flags and TRAILS.all(func(id): return id in flags)
static func stage(flags: Array) -> int:
	if "pack:returned" in flags or "pack:declined" in flags or "pack:closed" in flags: return 4
	if "pack:accepted" in flags: return 3
	if prepared(flags): return 2
	return 1 if "pack:invited" in flags else 0
static func valid(nature: Dictionary, flags: Array, opened: Array) -> bool:
	var present := false
	for id in flags:
		if not id is String: return false
		if not id.begins_with("pack:"): continue
		present = true
		if id not in KNOWN or flags.count(id) != 1: return false
	if not present: return nature.kind != "werewolf" and "werewolf" not in nature.history and nature.gift != "trail_oath"
	if "pack:invited" not in flags or "waterworks_report" not in opened: return false
	if nature.kind == "vampire" or "vampire" in nature.history:
		if "pack:closed" not in flags: return false
	var accepted := "pack:accepted" in flags
	var declined := "pack:declined" in flags
	if (accepted or declined) and not prepared(flags): return false
	if accepted and declined: return false
	if "pack:closed" in flags and (accepted or declined or (nature.kind == "human" and nature.history.is_empty())): return false
	if accepted and "werewolf" not in nature.history: return false
	if (nature.kind == "werewolf" or "werewolf" in nature.history) and not accepted: return false
	if nature.gift == "trail_oath" and not declined: return false
	if "pack:mastery" in flags and (not accepted or not CACHES.all(func(id): return id in opened)): return false
	if nature.kind == "werewolf" and CACHES.all(func(id): return id in opened) and "pack:mastery" not in flags: return false
	if nature.kind == "werewolf" and "pack:mastery" in flags and nature.gift != "wild_master": return false
	if nature.gift == "wild_master" and "pack:mastery" not in flags: return false
	if "pack:return_started" in flags and not accepted: return false
	if "pack:release_den" in flags or "pack:release_word" in flags:
		if "pack:return_started" not in flags: return false
	if "pack:returned" in flags:
		if nature.kind != "human" or nature.gift != "wild_scar" or nature.cure != 3: return false
		if "pack:release_den" not in flags or "pack:release_word" not in flags: return false
	if nature.kind == "werewolf":
		if nature.cure == 0 and "pack:return_started" in flags: return false
		if nature.cure > 0 and "pack:return_started" not in flags: return false
		if nature.cure == 1 and "pack:release_den" in flags and "pack:release_word" in flags: return false
		if nature.cure == 2 and ("pack:release_den" not in flags or "pack:release_word" not in flags): return false
	return nature.gift != "wild_scar" or "pack:returned" in flags
static func mastery(data: Dictionary, flags: Array, opened: Array) -> Dictionary:
	var next := data.duplicate(true)
	var remembered := flags.duplicate()
	var xp := 0
	if data.kind == "werewolf" and "pack:mastery" not in flags and CACHES.all(func(id): return id in opened):
		next.gift = "wild_master"
		remembered.append("pack:mastery")
		xp = 60
	return {"nature": next, "gathered": remembered, "xp": xp}
static func resolve(nature: Dictionary, flags: Array, opened: Array, mana: float, event: String) -> Dictionary:
	if not valid(nature, flags, opened) or nature.form != "human" or not is_finite(mana) or mana < 0 or mana > 100: return {}
	var next := nature.duplicate(true)
	var remembered := flags.duplicate()
	var xp := 0
	var trust := {}
	var current := stage(flags)
	match event:
		"invite":
			if current != 0 or nature.kind != "human" or not nature.history.is_empty() or "waterworks_report" not in opened: return {}
			remembered.append("pack:invited")
		"trail_0", "trail_1", "trail_2", "hear":
			var flag := "pack:" + ("heard" if event == "hear" else event)
			if current != 1 or flag in flags: return {}
			remembered.append(flag)
		"accept", "decline":
			if current != 2 or nature.kind != "human" or not nature.history.is_empty(): return {}
			remembered.append("pack:accepted" if event == "accept" else "pack:declined")
			xp = 40
			if event == "accept":
				next.kind = "werewolf"
				next.stage = 3
				next.gift = "wild"
				next.blood = 100.0
				next.resolve = 100.0
				next.history = ["werewolf"]
				trust = {"tenders": 1}
			else:
				if nature.gift != "oath": next.gift = "trail_oath"
				next.stage = 3
				trust = {"wardens": 1}
		"return_start":
			if nature.kind != "werewolf" or nature.cure != 0: return {}
			next.cure = 1
			remembered.append("pack:return_started")
		"release_den", "release_word":
			var flag := "pack:" + event
			if nature.kind != "werewolf" or nature.cure != 1 or flag in flags: return {}
			remembered.append(flag)
			if "pack:release_den" in remembered and "pack:release_word" in remembered: next.cure = 2
		"return_finish":
			if nature.kind != "werewolf" or nature.cure != 2 or mana < 30: return {}
			next.kind = "human"
			next.form = "human"
			next.stage = 4
			next.cure = 3
			next.gift = "wild_scar"
			next.resolve = 100.0
			mana -= 30
			xp = 40
			remembered.append("pack:returned")
		_: return {}
	var trained := mastery(next, remembered, opened)
	return {"nature": trained.nature, "gathered": trained.gathered, "mana": mana, "xp": xp + trained.xp, "trust": trust}
