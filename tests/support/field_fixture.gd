extends RefCounted
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
static func ready(session: Node, kind: String = "human") -> void:
	if kind == "vampire": NatureFixture.vampire(session)
	elif kind == "werewolf": PackFixture.wolf(session)
	else: NatureFixture.completed_episode(session)
	var guild: String = {"human": "watch", "vampire": "circle", "werewolf": "pack"}[kind]
	session.gathered.append_array(["community:join:" + guild, "community:seen:supply", "community:seen:route", "community:aid:craft", "community:report:share"])
	session.opened.append("community_report")
	session.gear_owned.append("relay_cloak")
	session.world_state.reputation = {"roadfolk": 2, "wardens": 2, "tenders": 2}
	session.inventory = {"coin": 24, "herb": 1, "potion": 1}
	session.xp = 240
