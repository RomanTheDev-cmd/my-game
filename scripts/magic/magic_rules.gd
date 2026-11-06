extends RefCounted
const SPELLS := {
	"heal": {"cost": 35.0, "cooldown": 0.8, "healing": 40.0},
	"light": {"cost": 18.0, "cooldown": 0.65, "damage": 24.0},
	"frost": {"cost": 24.0, "cooldown": 0.9, "damage": 12.0},
	"aegis": {"cost": 28.0, "cooldown": 0.8, "shield": 30.0, "duration": 6.0, "recharge": 10.0}
}

static func cast(id: String, health: float, mana: float, cooldown: float) -> Dictionary:
	if not SPELLS.has(id) or cooldown > 0 or health <= 0:
		return {}
	var spell: Dictionary = SPELLS[id]
	if mana < spell.cost or (id == "heal" and health >= 100):
		return {}
	return {"mana": mana - spell.cost, "health": minf(100, health + spell.get("healing", 0)),
		"cooldown": spell.cooldown, "damage": spell.get("damage", 0), "shield": spell.get("shield", 0)}
