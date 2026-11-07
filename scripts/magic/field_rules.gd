extends RefCounted
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const SPELLS := {"sluice": "frost", "garden": "heal", "relay": "aegis"}
const REPORT := "field_report"
const START := "field:accepted"
static func progress(flags: Array, id: String) -> int:
	var count := 0
	for step in range(1, 4):
		if "field:%s:step:%d" % [id, step] in flags: count += 1
	return count
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 3
	if START not in flags: return 0
	return 2 if SPELLS.keys().all(func(id): return progress(flags, id) == 3) else 1
static func valid(flags: Array, opened: Array) -> bool:
	var known := [START, "field:reported"]
	var doors := [REPORT, "field_garden_supplies"]
	for id in SPELLS:
		doors.append("field_" + id)
		for step in range(1, 4): known.append("field:%s:step:%d" % [id, step])
		for method in ["manual", SPELLS[id]]: known.append("field:%s:method:%s" % [id, method])
	for flag in flags:
		if flag.begins_with("field_") or (flag.begins_with("field:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("field:") or (flag.begins_with("field_") and (flag not in doors or opened.count(flag) > 1)): return false
	if START not in flags: return not flags.any(func(flag): return flag in known) and not opened.any(func(flag): return flag in doors)
	if "community_report" not in opened: return false
	for id in SPELLS:
		var amount := progress(flags, id)
		for step in range(1, amount + 1):
			if "field:%s:step:%d" % [id, step] not in flags: return false
		var has_method: bool = ("field:%s:method:manual" % id in flags) or ("field:%s:method:%s" % [id, SPELLS[id]] in flags)
		if "field:%s:method:manual" % id in flags and amount != 3: return false
		if has_method != (amount > 0) or ("field_" + id in opened) != (amount == 3): return false
	if "field_garden_supplies" in opened and "field_garden" not in opened: return false
	if ("field:reported" in flags) != (REPORT in opened): return false
	return REPORT not in opened or SPELLS.keys().all(func(id): return progress(flags, id) == 3)
static func power(id: String, skills: Dictionary) -> int:
	if not SPELLS.has(id): return 0
	var spell := Magic.profile(SPELLS[id], skills)
	if spell.is_empty(): return 0
	var amount: float = {"sluice": spell.get("damage", 0), "garden": spell.get("healing", 0), "relay": spell.get("shield", 0)}[id]
	return clampi(1 + floori((amount - {"sluice": 12, "garden": 40, "relay": 30}[id]) / {"sluice": 6.0, "garden": 15.0, "relay": 12.0}[id]), 1, 3)
static func resolve(nature: Dictionary, skills: Dictionary, flags: Array, opened: Array, vitals: Dictionary, minutes: float, id: String, method: String, cooldown: float = 0, recharge: float = 0) -> Dictionary:
	if not Nature.valid(nature) or not valid(flags, opened) or nature.form != "human": return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	for value in [minutes, cooldown, recharge]:
		if not is_finite(value) or value < 0: return {}
	var next := nature.duplicate(true)
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var resources := vitals.duplicate()
	var elapsed := 0.0
	var spent_cooldown := 0.0
	var spent_recharge := 0.0
	var xp := 0
	match id:
		"accept":
			if method != "accept" or stage(flags, opened) != 0 or "community_report" not in opened: return {}
			gathered.append(START)
		"report":
			if method != "report" or stage(flags, opened) != 2: return {}
			gathered.append("field:reported")
			claimed.append(REPORT)
			xp = 80
		_:
			if not SPELLS.has(id) or stage(flags, opened) != 1 or progress(flags, id) >= 3: return {}
			var strength := 3
			if method == "manual":
				if resources.stamina < 30: return {}
				resources.stamina -= 30
				elapsed = 10.0
				minutes = Clock.advance(minutes, elapsed)
				next = Nature.advance(nature, 10)
			else:
				if method != SPELLS[id] or not Nature.can_spell(nature, method) or cooldown > 0 or (method == "aegis" and recharge > 0): return {}
				var spell := Magic.profile(method, skills)
				if spell.is_empty() or resources.mana < spell.cost: return {}
				resources.mana -= spell.cost
				strength = power(id, skills)
				spent_cooldown = spell.cooldown
				if method == "aegis": spent_recharge = spell.recharge
			var marker := "field:%s:method:%s" % [id, method]
			if marker not in gathered: gathered.append(marker)
			var total := mini(3, progress(flags, id) + strength)
			for step in range(progress(flags, id) + 1, total + 1): gathered.append("field:%s:step:%d" % [id, step])
			if total == 3: claimed.append("field_" + id)
	if next.is_empty() or not valid(gathered, claimed): return {}
	return {"nature": next, "gathered": gathered, "opened": claimed, "vitals": resources, "minutes": minutes, "elapsed": elapsed, "cooldown": spent_cooldown, "recharge": spent_recharge, "xp": xp}
