extends RefCounted

# Events are emitted by gameplay; screens never assign quest state or inventory.
const GRAPH := {0: {"accept": 1}, 1: {"found": 2}, 2: {"turn_in": 3}, 3: {}}

static func transition(stage: int, inventory: Dictionary, event: String) -> Dictionary:
	if not GRAPH.has(stage) or not GRAPH[stage].has(event):
		return {}
	if event == "turn_in" and inventory.get("lantern", 0) != 1:
		return {}
	var next_inventory := inventory.duplicate(true)
	if event == "found":
		next_inventory["lantern"] = 1
	elif event == "turn_in":
		next_inventory.erase("lantern")
		next_inventory["coin"] = mini(999, int(next_inventory.get("coin", 0)) + 12)
	return {"stage": GRAPH[stage][event], "inventory": next_inventory}
