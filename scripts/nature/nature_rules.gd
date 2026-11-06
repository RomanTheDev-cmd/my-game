extends RefCounted
const STUDIES := ["nature:water", "nature:garden"]
const RELEASE := ["nature:release_water", "nature:release_garden"]
const SITES := {"invite": ["lake", "wayfarer"], "water": ["waterworks", "altar"], "garden": ["workshop", "tender"],
	"human": ["lake", "wayfarer"], "vampire": ["lake", "wayfarer"], "supply": ["lake", "wayfarer"],
	"cure_start": ["crossing", "keeper"], "release_water": ["waterworks", "altar"], "release_garden": ["workshop", "tender"], "cure_finish": ["crossing", "keeper"]}
static func defaults() -> Dictionary:
	return {"kind": "human", "form": "human", "blood": 100.0, "stage": 0, "history": [], "cure": 0, "gift": ""}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 7: return false
	if data.get("kind") not in ["human", "vampire"] or data.get("form") not in ["human", "battle"]: return false
	var blood = data.get("blood")
	if not (blood is int or blood is float) or not is_finite(float(blood)) or blood < 0 or blood > 100: return false
	for key in ["stage", "cure"]:
		var value = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > (4 if key == "stage" else 3) or floorf(value) != value: return false
	if not data.get("history") is Array: return false
	if data.stage < 3:
		return data.kind == "human" and data.form == "human" and blood == 100 and data.history.is_empty() and data.cure == 0 and data.get("gift") == ""
	if data.kind == "vampire":
		return data.stage == 3 and data.history == ["vampire"] and data.cure < 3 and data.get("gift") == "blood" and (data.form == "human" or blood > 0)
	if data.form != "human" or blood != 100: return false
	return (data.stage == 3 and data.cure == 0 and data.history.is_empty() and data.get("gift") == "oath") or (data.stage == 4 and data.cure == 3 and data.history == ["vampire"] and data.get("gift") == "scar")
static func quest_valid(data: Dictionary, gathered: Array, opened: Array) -> bool:
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
	return next
static func sunlight(data: Dictionary, daylight: float, indoor: bool) -> float:
	return 1.3 if data.kind == "vampire" and not indoor and daylight > 0.5 else 1.0
static func can_spell(data: Dictionary, id: String) -> bool:
	return data.form == "human" and not (data.kind == "vampire" and id in ["light", "heal"])
static func shift(data: Dictionary) -> Dictionary:
	if not valid(data) or data.kind != "vampire": return {}
	var next := data.duplicate(true)
	if data.form == "battle": next.form = "human"
	else:
		if data.blood < 25: return {}
		next.form = "battle"
		next.blood -= 20
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
			if event == "vampire": trust = {"roadfolk": -1}
			if event == "human": trust = {"wardens": 1}
			if event == "cure_finish": trust = {"roadfolk": 1}
	if next.is_empty() or not valid(next) or not quest_valid(next, flags, opened): return {}
	return {"nature": next, "gathered": flags, "inventory": items, "mana": mana, "xp": xp, "trust": trust}
