extends RefCounted
const Factions = preload("res://scripts/factions/faction_rules.gd")
const REWARD_COINS := 16
const SURVEYS := ["wheel", "archive"]
const HEARD := ["wardens", "tenders"]
const SITES := {
	"accept": ["crossing", "keeper"], "report": ["crossing", "keeper"],
	"inspect_wheel": ["workshop", "wheel"], "inspect_archive": ["workshop", "archive"],
	"hear_wardens": ["workshop", "warden"], "hear_tenders": ["workshop", "tender"],
	"supply_purchase": ["workshop", "wright"], "supply_craft": ["workshop", "workbench"],
	"supply_recover": ["workshop", "cache"],
	"restore_shared": ["workshop", "wheel"], "restore_wardens": ["workshop", "wheel"], "restore_tenders": ["workshop", "wheel"]}

static func defaults() -> Dictionary:
	return {"stage": 0, "survey": [], "heard": [], "supply": "", "settlement": ""}

static func _flags(value: Variant, known: Array) -> bool:
	if not value is Array:
		return false
	var seen := []
	for flag in value:
		if not flag is String or flag not in known or flag in seen:
			return false
		seen.append(flag)
	return true

static func valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var stage = data.get("stage")
	if not (stage is int or stage is float) or not is_finite(float(stage)) or stage < 0 or stage > 6 or floorf(stage) != stage:
		return false
	if not _flags(data.get("survey"), SURVEYS) or not _flags(data.get("heard"), HEARD):
		return false
	if not data.get("supply") is String or data.supply not in ["", "purchase", "craft", "recover"]:
		return false
	if not data.get("settlement") is String or data.settlement not in ["", "shared", "wardens", "tenders"]:
		return false
	if (stage == 0 and not data.survey.is_empty()) or (stage == 1 and data.survey.size() >= 2) or (stage >= 2 and data.survey.size() != 2):
		return false
	if (stage < 2 and not data.heard.is_empty()) or (stage == 2 and data.heard.size() >= 2) or (stage >= 3 and data.heard.size() != 2):
		return false
	if (stage < 4) != data.supply.is_empty() or (stage < 5) != data.settlement.is_empty():
		return false
	return true

static func transition(state: Dictionary, inventory: Dictionary, mana: float, reputation: Dictionary, event: String, main_stage: int, defeated: Array) -> Dictionary:
	if not valid(state) or not Factions.valid(reputation) or not SITES.has(event) or not is_finite(mana) or mana < 0 or mana > 100:
		return {}
	var next := state.duplicate(true)
	var items := inventory.duplicate()
	var changes := {}
	var xp := 0
	match int(state.stage):
		0:
			if event != "accept" or main_stage != 3:
				return {}
			next.stage = 1
		1:
			if not event.begins_with("inspect_"):
				return {}
			var site := event.trim_prefix("inspect_")
			if site not in SURVEYS or site in next.survey:
				return {}
			next.survey.append(site)
			if next.survey.size() == 2:
				next.stage = 2
		2:
			if not event.begins_with("hear_"):
				return {}
			var group := event.trim_prefix("hear_")
			if group not in HEARD or group in next.heard:
				return {}
			next.heard.append(group)
			if next.heard.size() == 2:
				next.stage = 3
		3:
			if event == "supply_purchase":
				if int(items.get("coin", 0)) < 8:
					return {}
				items.coin = int(items.coin) - 8
			elif event == "supply_craft":
				if int(items.get("scrap", 0)) < 3:
					return {}
				items.scrap = int(items.scrap) - 3
			elif event == "supply_recover":
				for id in ["workshop_1", "workshop_archer"]:
					if id not in defeated:
						return {}
			else:
				return {}
			next.supply = event.trim_prefix("supply_")
			next.stage = 4
		4:
			match event:
				"restore_shared":
					if reputation.wardens < 0 or reputation.tenders < 0:
						return {}
					changes = {"roadfolk": 2, "wardens": 2, "tenders": 2}
				"restore_wardens": changes = {"roadfolk": 1, "wardens": 3, "tenders": -1}
				"restore_tenders": changes = {"roadfolk": 1, "wardens": -1, "tenders": 3}
				_: return {}
			next.settlement = event.trim_prefix("restore_")
			next.stage = 5
		5:
			if event != "report" or int(items.get("coin", 0)) > 999 - REWARD_COINS:
				return {}
			items.coin = int(items.get("coin", 0)) + REWARD_COINS
			xp = 80
			next.stage = 6
		_: return {}
	return {"commission": next, "inventory": items, "mana": mana, "reputation": Factions.change(reputation, changes), "xp": xp}

static func choices(state: Dictionary, target: String, region: String) -> Array[String]:
	var by_stage := {0: ["accept"], 1: ["inspect_wheel", "inspect_archive"], 2: ["hear_wardens", "hear_tenders"],
		3: ["supply_purchase", "supply_craft", "supply_recover"], 4: ["restore_shared", "restore_wardens", "restore_tenders"], 5: ["report"]}
	var result: Array[String] = []
	for event in by_stage.get(int(state.stage), []):
		if SITES[event][0] == region and SITES[event][1] == target:
			result.append(event)
	return result
