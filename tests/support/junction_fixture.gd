extends RefCounted
const ForestFixture = preload("res://tests/support/forest_fixture.gd")
static func ready(session: Node, kind: String = "human", lake_method: String = "manual", forest_outcome: String = "commons", city_outcome: String = "shared") -> bool:
	if not ForestFixture.ready(session, kind, true, "share", lake_method): return false
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	for event in ["accept", "work", "work", "work", forest_outcome]:
		if not session.forest_event(event, Vector2(410, 490), vitals): return false
	for event in ["accept", "hear_crafter", "hear_archivist", "draft_" + city_outcome, "work", "copy", "sign_crafter", "sign_archivist", "seal"]:
		if session.city_event(event, Vector2(410, 490), vitals).is_empty(): return false
	return true
