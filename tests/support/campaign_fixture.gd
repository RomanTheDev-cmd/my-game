extends RefCounted
static func ready(session: Node) -> void:
	session.fresh()
	session.quest = 3
	session.xp = 60
	session.inventory = {"coin": 15, "herb": 3, "potion": 1}
