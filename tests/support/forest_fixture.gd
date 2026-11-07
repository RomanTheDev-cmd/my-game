extends RefCounted
const CampaignFixture = preload("res://tests/support/campaign_fixture.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
static func ready(session: Node, kind: String = "human", lake: bool = true, outcome: String = "share", method: String = "manual") -> bool:
	if kind == "vampire": NatureFixture.vampire(session)
	elif kind == "werewolf": PackFixture.wolf(session)
	else: CampaignFixture.ready(session)
	var events := ["greet", "accept"]
	if lake:
		events.append_array(["hear", "inspect"])
		if method == "manual": events.append_array(["turn_a", "turn_b", "turn_b", "manual"])
		elif method == "blood": events.append_array(["consent", "blood"])
		else: events.append("scent")
		events.append("report_" + outcome)
	for event in events:
		if event == "scent": session.nature.form = "wolf"
		if event.begins_with("report_"): session.nature.form = "human"
		if not session.campaign_event(event, Vector2(410, 490), {"health": 64.0, "mana": 90.0, "stamina": 100.0}): return false
	return true
