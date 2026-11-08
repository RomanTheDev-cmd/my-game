extends RefCounted
const AccordFixture = preload("res://tests/support/accord_fixture.gd")
const VITALS := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
# The genuine earlier campaign, actual voices and one recorded common decision.
static func ready(session: Node, kind: String = "human", choice: String = "renewal") -> bool:
	if not AccordFixture.accepted(session, kind): return false
	return session.accord_event(choice, Vector2(620, 650), VITALS)
static func accepted(session: Node, kind: String = "human", choice: String = "renewal") -> bool:
	if not ready(session, kind, choice): return false
	session.region = "crossing"
	return session.knell_event("accept", Vector2(520, 490), VITALS)
static func armed(session: Node, kind: String = "human", choice: String = "renewal") -> bool:
	if not accepted(session, kind, choice): return false
	session.region = "undercroft"
	for id in ["hall", "gallery", "ossuary"]:
		if not session.knell_event("read_" + id, Vector2(330, 820), VITALS): return false
	return true
static func silenced(session: Node, kind: String = "human", choice: String = "renewal") -> bool:
	if not armed(session, kind, choice): return false
	if not session.knell_event("silence", Vector2(1300, 705), VITALS): return false
	session.region = "crossing"
	return true
# A human who took the protective oath, then made the common decision as that self.
static func oath_ready(session: Node, choice: String = "renewal") -> bool:
	if not AccordFixture.ready(session, "vampire"): return false
	session.nature.kind = "human"
	session.nature.history = []
	session.nature.blood = 100.0
	session.nature.gift = "oath"
	for event in ["affirm", "accept", "hear_witness", "hear_crafter", choice]:
		if not session.accord_event(event, Vector2(620, 650), VITALS): return false
	return true
