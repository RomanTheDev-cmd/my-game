extends RefCounted
const JunctionFixture = preload("res://tests/support/junction_fixture.gd")
static func ready(session: Node, kind: String = "human", choice: String = "public", city: String = "shared") -> bool:
	if not JunctionFixture.ready(session, kind, "manual", "commons", city): return false
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	for event in ["accept", "hear", "map", "manual", "prove", "explain", choice]:
		if session.junction_event(event, Vector2(650, 820), vitals, 0, 0, 3).is_empty(): return false
	return true
static func configured(session: Node, kind: String = "human", choice: String = "public", city: String = "shared", layout: String = "lake") -> bool:
	if not ready(session, kind, choice, city): return false
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	for event in ["accept", "invite_witness", "invite_crafter", "layout_" + layout, "tune_north", "tune_south"]:
		if not session.preparation_event(event, Vector2(1580, 650), vitals): return false
	if choice == "private" and not session.preparation_event("tune_north", Vector2(1580, 650), vitals): return false
	if city == "release" and not session.preparation_event("tune_south", Vector2(1580, 650), vitals): return false
	return true
