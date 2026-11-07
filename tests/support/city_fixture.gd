extends RefCounted
const ForestFixture = preload("res://tests/support/forest_fixture.gd")
static func ready(session: Node, kind: String = "human") -> bool:
	return ForestFixture.ready(session, kind, false)
