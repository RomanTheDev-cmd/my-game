extends RefCounted
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
static func prepared(session: Node) -> void:
	NatureFixture.completed_episode(session)
	session.gathered.append_array(["pack:invited", "pack:trail_0", "pack:trail_1", "pack:trail_2", "pack:heard"])
static func wolf(session: Node, mastered: bool = false) -> void:
	prepared(session)
	session.gathered.append("pack:accepted")
	session.nature = {"kind": "werewolf", "form": "human", "blood": 100.0, "resolve": 80.0, "stage": 3, "history": ["werewolf"], "cure": 0, "gift": "wild_master" if mastered else "wild"}
	if mastered:
		session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		session.gathered.append("pack:mastery")
