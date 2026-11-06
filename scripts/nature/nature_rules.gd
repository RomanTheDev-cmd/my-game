extends RefCounted
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Pack = preload("res://scripts/nature/pack_rules.gd")
const STUDIES := ["nature:water", "nature:garden"]
const RELEASE := ["nature:release_water", "nature:release_garden"]
const SITES := {"invite": ["lake", "wayfarer"], "water": ["waterworks", "altar"], "garden": ["workshop", "tender"],
	"human": ["lake", "wayfarer"], "vampire": ["lake", "wayfarer"], "supply": ["lake", "wayfarer"],
	"cure_start": ["crossing", "keeper"], "release_water": ["waterworks", "altar"], "release_garden": ["workshop", "tender"], "cure_finish": ["crossing", "keeper"]}
static func defaults() -> Dictionary:
	return {"kind": "human", "form": "human", "blood": 100.0, "resolve": 100.0, "stage": 0, "history": [], "cure": 0, "gift": ""}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 8: return false
	if data.get("kind") not in ["human", "vampire", "werewolf"] or data.get("form") not in ["human", "battle", "wolf", "hybrid"]: return false
	var blood = data.get("blood")
	if not (blood is int or blood is float) or not is_finite(float(blood)) or blood < 0 or blood > 100: return false
	var resolve = data.get("resolve")
	if not (resolve is int or resolve is float) or not is_finite(float(resolve)) or resolve < 0 or resolve > 100: return false
	if data.kind != "werewolf" and resolve != 100: return false
	for key in ["stage", "cure"]:
		var value = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > (4 if key == "stage" else 3) or floorf(value) != value: return false
	if not data.get("history") is Array: return false
	if data.stage < 3:
		return data.kind == "human" and data.form == "human" and blood == 100 and data.history.is_empty() and data.cure == 0 and data.get("gift") == ""
	if data.kind == "vampire":
		return data.stage == 3 and data.history == ["vampire"] and data.cure < 3 and data.get("gift") == "blood" and data.form in ["human", "battle"] and (data.form == "human" or blood > 0)
	if data.kind == "werewolf":
		return data.stage == 3 and blood == 100 and data.history == ["werewolf"] and data.cure < 3 and data.get("gift") in ["wild", "wild_master"] and data.form in ["human", "wolf", "hybrid"] and (data.form == "human" or resolve > 0) and (data.form != "hybrid" or data.gift == "wild_master")
	if data.form != "human" or blood != 100: return false
	return (data.stage == 3 and data.cure == 0 and data.history.is_empty() and data.get("gift") in ["oath", "trail_oath"]) or (data.stage == 4 and data.cure == 3 and ((data.history == ["vampire"] and data.get("gift") == "scar") or (data.history == ["werewolf"] and data.get("gift") == "wild_scar")))
static func quest_valid(data: Dictionary, gathered: Array, opened: Array) -> bool:
	if not Pack.valid(data, gathered, opened): return false
	if "werewolf" in data.history or data.gift == "trail_oath": return true
	if data.stage > 0 and "waterworks_report" not in opened: return false
	for flag in STUDIES + RELEASE:
		if gathered.count(flag) > 1: return false
	if data.stage == 0 and (STUDIES[0] in gathered or STUDIES[1] in gathered): return false
	if data.stage >= 2 and (STUDIES[0] not in gathered or STUDIES[1] not in gathered): return false
	if data.cure == 0 and (RELEASE[0] in gathered or RELEASE[1] in gathered): return false
	return data.cure < 2 or (RELEASE[0] in gathered and RELEASE[1] in gathered)
static func transition(data: Dictionary, event: String, prepared: bool) -> Dictionary:
	if not valid(data): return {}
	var next := data.duplicate(true)
	match event:
		"invite":
			if data.stage != 0 or not prepared: return {}
			next.stage = 1
		"prepare":
			if data.stage != 1 or not prepared: return {}
			next.stage = 2
		"human", "vampire":
			if data.stage != 2 or not prepared: return {}
			next.stage = 3
			next.kind = event
			next.gift = "oath" if event == "human" else "blood"
			if event == "vampire": next.history = ["vampire"]
		"cure_start":
			if data.kind != "vampire" or data.cure != 0 or data.form != "human": return {}
			next.cure = 1
		"cure_prepare":
			if data.kind != "vampire" or data.cure != 1 or not prepared: return {}
			next.cure = 2
		"cure_finish":
			if data.kind != "vampire" or data.cure != 2 or not prepared or data.form != "human": return {}
			next.kind = "human"
			next.form = "human"
			next.blood = 100.0
			next.stage = 4
			next.cure = 3
			next.gift = "scar"
		_: return {}
	return next
static func advance(data: Dictionary, seconds: float) -> Dictionary:
	if not valid(data) or not is_finite(seconds) or seconds < 0: return {}
	var next := data.duplicate(true)
	if data.kind == "vampire":
		next.blood = maxf(0, data.blood - seconds * (3.04 if data.form == "battle" else 0.04))
		if next.blood == 0: next.form = "human"
	if data.kind == "werewolf":
		if data.form == "human": next.resolve = minf(100, data.resolve + seconds * 0.8)
		else:
			var drain := 0.8 if data.form == "wolf" else 2.2
			var duration: float = data.resolve / drain
			if seconds >= duration:
				next.form = "human"
				next.resolve = minf(100, (seconds - duration) * 0.8)
			else: next.resolve = data.resolve - seconds * drain
	return next
static func sunlight(data: Dictionary, daylight: float, indoor: bool) -> float:
	return 1.3 if data.kind == "vampire" and not indoor and daylight > 0.5 else 1.0
static func can_spell(data: Dictionary, id: String) -> bool:
	return data.form == "human" and not (data.kind == "vampire" and id in ["light", "heal"])
static func shift(data: Dictionary, requested: String = "") -> Dictionary:
	if not valid(data) or data.kind == "human": return {}
	var next := data.duplicate(true)
	if requested == "" and data.form != "human":
		next.form = "human"
		return next
	var selected := requested if requested != "" else ("wolf" if data.kind == "werewolf" else "battle")
	if selected == data.form:
		next.form = "human"
		return next
	if data.kind == "vampire":
		if selected != "battle" or data.blood < 25: return {}
		next.blood -= 20
	else:
		if selected not in ["wolf", "hybrid"] or (selected == "hybrid" and data.gift != "wild_master"): return {}
		var cost := 10 if selected == "wolf" else 20
		if data.resolve < cost + 5: return {}
		next.resolve -= cost
	next.form = selected
	return next
static func resolve(data: Dictionary, gathered: Array, opened: Array, inventory: Dictionary, mana: float, event: String) -> Dictionary:
	if not valid(data) or not quest_valid(data, gathered, opened) or data.form != "human" or not is_finite(mana) or mana < 0 or mana > 100: return {}
	var next := data.duplicate(true)
	var flags := gathered.duplicate()
	var items := inventory.duplicate()
	var xp := 0
	var trust := {}
	match event:
		"water", "garden":
			var flag := "nature:" + event
			if data.stage != 1 or flag in flags: return {}
			flags.append(flag)
			if STUDIES[0] in flags and STUDIES[1] in flags: next = transition(data, "prepare", true)
		"release_water", "release_garden":
			var flag := "nature:" + event
			if data.kind != "vampire" or data.cure != 1 or flag in flags: return {}
			flags.append(flag)
			if RELEASE[0] in flags and RELEASE[1] in flags: next = transition(data, "cure_prepare", true)
		"supply":
			if data.kind != "vampire" or data.blood >= 80 or int(items.get("coin", 0)) < 6: return {}
			items.coin -= 6
			next.blood = minf(100, data.blood + 40)
		_:
			if event == "cure_finish":
				if mana < 30: return {}
				mana -= 30
			next = transition(data, event, "waterworks_report" in opened)
			if next.is_empty(): return {}
			if event in ["human", "vampire", "cure_finish"]: xp = 40
			if event == "vampire":
				trust = {"roadfolk": -1}
				if "pack:invited" in flags and "pack:closed" not in flags: flags.append("pack:closed")
			if event == "human": trust = {"wardens": 1}
			if event == "cure_finish": trust = {"roadfolk": 1}
	if next.is_empty() or not valid(next) or not quest_valid(next, flags, opened): return {}
	return {"nature": next, "gathered": flags, "inventory": items, "mana": mana, "xp": xp, "trust": trust}

static func regeneration(data: Dictionary, minutes: float) -> float:
	var night := Clock.daylight(minutes) < 0.5
	if data.kind == "vampire": return 1.5 if data.blood > 20 and night else 0.0
	if data.kind == "werewolf" and data.form != "human" and data.resolve > 20:
		return 0.5 + (Pack.moon(minutes) * 0.8 if night else 0.0)
	return 0.0
