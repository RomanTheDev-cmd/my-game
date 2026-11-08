extends RefCounted
const PreparationFixture = preload("res://tests/support/preparation_fixture.gd")
static func ready(session: Node, kind: String = "human", choice: String = "public", city: String = "shared") -> bool:
	if not PreparationFixture.configured(session, kind, choice, city): return false
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	return session.preparation_event("prove", Vector2(520, 650), vitals, true) and session.preparation_event("report", Vector2(650, 820), vitals)
static func selected(session: Node, kind: String = "human", method: String = "tools") -> bool:
	if not ready(session, kind): return false
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	return session.rescue_event("accept", Vector2(650, 820), vitals) and session.rescue_event(method, Vector2(1440, 650), vitals)
