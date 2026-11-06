extends RefCounted
const DEFAULT_OWNED := ["road_sword", "cloth", "wood_shield"]
const DEFAULT_EQUIPPED := {"weapon": "road_sword", "armor": "cloth", "shield": "wood_shield"}
const ITEMS := {
	"road_sword": {"slot": "weapon", "damage": 28.0, "reach": 49.0, "cooldown": 0.42, "price": 6, "sell": 2},
	"dagger": {"slot": "weapon", "damage": 22.0, "reach": 42.0, "cooldown": 0.28, "price": 9, "sell": 3},
	"iron_sword": {"slot": "weapon", "damage": 36.0, "reach": 52.0, "cooldown": 0.48, "price": 15, "sell": 5},
	"watch_spear": {"slot": "weapon", "damage": 32.0, "reach": 86.0, "cooldown": 0.6, "two_handed": true, "price": 19, "sell": 6, "vendor": "wardens"},
	"polearm": {"slot": "weapon", "damage": 44.0, "reach": 70.0, "cooldown": 0.7, "two_handed": true, "price": 20, "sell": 7},
	"cloth": {"slot": "armor", "reduction": 0.0, "price": 4, "sell": 1},
	"quilted": {"slot": "armor", "reduction": 0.12, "price": 10, "sell": 3},
	"chain": {"slot": "armor", "reduction": 0.24, "price": 20, "sell": 7},
	"wood_shield": {"slot": "shield", "block": 0.25, "price": 5, "sell": 1},
	"iron_shield": {"slot": "shield", "block": 0.15, "price": 12, "sell": 4}
}

static func valid(owned: Variant, equipped: Variant) -> bool:
	if not owned is Array or not equipped is Dictionary or equipped.size() != 3:
		return false
	var seen := {}
	for id in owned:
		if not id is String or not ITEMS.has(id) or seen.has(id):
			return false
		seen[id] = true
	for slot in ["weapon", "armor", "shield"]:
		var id = equipped.get(slot)
		if not id is String:
			return false
		if id != "" and (not seen.has(id) or ITEMS[id].slot != slot):
			return false
	var weapon: String = equipped.weapon
	return weapon == "" or not ITEMS[weapon].get("two_handed", false) or equipped.shield == ""

static func equip(id: String, owned: Array, equipped: Dictionary) -> Dictionary:
	if not valid(owned, equipped) or id not in owned:
		return {}
	var slot: String = ITEMS[id].slot
	if slot == "shield" and ITEMS.get(equipped.weapon, {}).get("two_handed", false):
		return {}
	var result := equipped.duplicate()
	result[slot] = id
	if ITEMS[id].get("two_handed", false):
		result.shield = ""
	return result

static func weapon(equipped: Dictionary) -> Dictionary:
	return ITEMS.get(equipped.get("weapon", ""), {"damage": 10.0, "reach": 35.0, "cooldown": 0.4})

static func reduction(equipped: Dictionary) -> float:
	return float(ITEMS.get(equipped.get("armor", ""), {}).get("reduction", 0))

static func block(equipped: Dictionary) -> float:
	return float(ITEMS.get(equipped.get("shield", ""), {}).get("block", 0.65))
