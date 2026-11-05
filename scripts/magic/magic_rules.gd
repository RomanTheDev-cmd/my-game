extends RefCounted
const SPELLS := {
	"heal": {"cost": 35.0, "cooldown": 0.8, "healing": 40.0},
	"light": {"cost": 18.0, "cooldown": 0.65, "damage": 24.0}
}

static func cast(id: String, health: float, mana: float, cooldown: float) -> Dictionary:
	if not SPELLS.has(id) or cooldown > 0 or health <= 0:
		return {}
	var spell: Dictionary = SPELLS[id]
	if mana < spell.cost or (id == "heal" and health >= 100):
		return {}
	return {"mana": mana - spell.cost, "health": minf(100, health + spell.get("healing", 0)),
		"cooldown": spell.cooldown, "damage": spell.get("damage", 0)}
