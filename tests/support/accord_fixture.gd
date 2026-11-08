extends RefCounted
const RescueFixture = preload("res://tests/support/rescue_fixture.gd")
static func ready(session: Node, kind: String = "human", choice: String = "public", city: String = "shared") -> bool:
	if not RescueFixture.ready(session, kind, choice, city): return false
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	for event in ["accept", "tools", "manual_north", "manual_south", "free", "safe", "report", "rest"]:
		if not session.rescue_event(event, Vector2(600, 600), vitals, true, false, true): return false
	return true
static func accepted(session: Node, kind: String = "human") -> bool:
	if not ready(session, kind): return false
	for event in ["affirm", "accept", "hear_witness", "hear_crafter"]:
		if not session.accord_event(event, Vector2(620, 650), {"health": 64.0, "stamina": 100.0, "mana": 90.0}): return false
	return true
