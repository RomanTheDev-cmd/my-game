extends RefCounted
const SPELLS := {
	"heal": {"cost": 35.0, "cooldown": 0.8, "healing": 40.0},
	"light": {"cost": 18.0, "cooldown": 0.65, "damage": 24.0},
	"frost": {"cost": 24.0, "cooldown": 0.9, "damage": 12.0},
	"aegis": {"cost": 28.0, "cooldown": 0.8, "shield": 30.0, "duration": 6.0, "recharge": 10.0}
}

static func profile(id: String, skills: Dictionary = {}) -> Dictionary:
	if not SPELLS.has(id): return {}
	for key in ["mending", "frost", "aegis", "light", "ward"]:
		var rank = skills.get(key, 0)
		if not (rank is int or rank is float) or not is_finite(float(rank)) or rank < 0 or rank > (3 if key == "light" else 2) or floorf(rank) != rank: return {}
	var spell: Dictionary = SPELLS[id].duplicate()
	match id:
		"heal":
			spell.cost += 5 * int(skills.get("mending", 0))
			spell.healing += 15 * int(skills.get("mending", 0))
		"light": spell.damage += 6 * int(skills.get("light", 0))
		"frost":
			var rank := int(skills.get("frost", 0))
			spell.cost += 2 * rank
			spell.damage += 6 * rank
			spell["slow_duration"] = 4.0 + rank
			spell["slow_multiplier"] = 0.55 - 0.05 * rank
		"aegis":
			var rank := int(skills.get("aegis", 0))
			spell.cost += 4 * rank
			spell.shield += 12 * rank + 10 * int(skills.get("ward", 0))
			spell.duration += rank
			spell.recharge -= rank
	return spell
static func cast(id: String, health: float, mana: float, cooldown: float, skills: Dictionary = {}) -> Dictionary:
	if not is_finite(health) or not is_finite(mana) or not is_finite(cooldown) or health <= 0 or health > 100 or mana < 0 or mana > 100 or cooldown != 0: return {}
	var spell := profile(id, skills)
	if spell.is_empty() or mana < spell.cost or (id == "heal" and health >= 100): return {}
	var result := spell.duplicate()
	result["mana"] = mana - spell.cost
	result["health"] = minf(100, health + spell.get("healing", 0))
	result["damage"] = spell.get("damage", 0)
	result["shield"] = spell.get("shield", 0)
	return result
