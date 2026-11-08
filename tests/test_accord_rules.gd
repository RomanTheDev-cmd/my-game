extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/accord_rules.gd")
const Fixture = preload("res://tests/support/accord_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("Session")
	session.fresh()
	var data: Dictionary = session.snapshot(Vector2(410, 490))
	data.opened.append("accord_report")
	check(not session.Store.validate(data), "unearned final agreement cannot enter a save without lived campaign, identity or actual conversations")
	check(Fixture.ready(session), "actual preceding sequence and aftermath form a valid new common-node fixture")
	var old: Dictionary = session.snapshot(Vector2(600, 600))
	check(session.Store.validate(old) and session.Store.migrate(old) == old, "old v9 needs no new agreement fields or reset")
	var state := snapshot(session)
	for missing in ["report", "aftermath"]:
		var partial := state.duplicate(true)
		if missing == "report": partial.opened.erase("rescue_report")
		else: partial.flags.erase("rescue:rested")
		check(act(partial, "affirm").is_empty(), "each actual lived predecessor is independently required: " + missing)
	check(act(state, "accept").is_empty(), "invitation cannot skip personal present-path conversation")
	state = step(state, "affirm")
	check(Rules.recorded(state.flags) == "human" and act(state, "affirm").is_empty(), "ordinary human has a useful explicit path without forced transformation or repeat reward")
	state = step(state, "accept")
	check(act(state, "renewal").is_empty() and act(state, "accept").is_empty(), "acceptance alone cannot skip participants or repeat")
	state = step(state, "hear_witness")
	check(act(state, "community").is_empty() and act(state, "hear_witness").is_empty(), "one participant cannot stand in for both distinct voices")
	state = step(state, "hear_crafter")
	for choice in ["renewal", "release", "community"]:
		var final := act(state, choice)
		check(final.xp == 100 and final.trust == {"roadfolk": 1, "wardens": 1, "tenders": 1} and final.vitals == {"health": 64.0, "stamina": 100.0, "mana": 90.0}, "each actual choice gives equal one-time experience without hidden healing/resource price")
		var done := step(state, choice)
		check(Rules.outcome(done.opened) == choice and Rules.stage(done.flags, done.opened) == 4 and act(done, "release").is_empty() and act(done, "affirm").is_empty(), "final world outcome is unique and cannot be farmed or overwritten")
	check(Rules.outcome(state.opened) == "", "independent alternatives do not mutate their shared input")
	for corruption in ["unknown", "duplicate", "missing_identity", "two_identities", "orphan_heard", "two_choices", "orphan_report", "unheard_choice", "wrong_history", "wrong_opened", "wrong_defeated", "unearned_cache", "wrong_cache_flags"]:
		data = old.duplicate(true)
		data.gathered.append("accord:identity:human")
		match corruption:
			"unknown": data.gathered.append("accord:unused")
			"duplicate": data.gathered.append("accord:identity:human")
			"missing_identity":
				data.gathered.erase("accord:identity:human")
				data.gathered.append("accord:accepted")
			"two_identities": data.gathered.append("accord:identity:oath")
			"orphan_heard": data.gathered.append("accord:heard:crafter")
			"two_choices": data.opened.append_array(["accord_renewal", "accord_release"])
			"orphan_report": data.opened.append("accord_report")
			"unheard_choice": data.opened.append_array(["accord_report", "accord_community"])
			"wrong_history": data.gathered = data.gathered.filter(func(flag): return flag != "accord:identity:human") + ["accord:identity:vampire"]
			"wrong_opened": data.opened.append("accord:accepted")
			"wrong_defeated": data.defeated.append("accord:accepted")
			"unearned_cache": data.opened.append("commons_terrace_supplies")
			"wrong_cache_flags": data.gathered.append("commons_velshof_supplies")
		check(not session.Store.validate(data), "save rejects inconsistent progress: " + corruption)
	for kind in ["vampire", "werewolf"]:
		check(Fixture.accepted(session, kind), "each actual voluntary nature can reach all three choices")
		state = snapshot(session)
		check(Rules.recorded(state.flags) == kind and not act(state, "community").is_empty(), "present special nature is respected without becoming required")
		var events := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
		for event in events: check(session.nature_event(event, Vector2(600, 600), {"health": 64.0, "stamina": 100.0, "mana": 90.0}) if kind == "vampire" else session.pack_event(event, Vector2(600, 600), {"health": 64.0, "stamina": 100.0, "mana": 90.0}), "genuine separate return remains compatible with recorded past identity")
		state = snapshot(session)
		check(session.Store.validate(session.snapshot(Vector2(600, 600))) and act(state, "release").is_empty(), "historical statement remains a valid save after cure but must be reaffirmed before choice")
		state = step(state, "affirm")
		check(Rules.recorded(state.flags) == ("returned" if kind == "vampire" else "wild_returned") and Rules.HEARD.all(func(flag): return flag in state.flags) and not act(state, "release").is_empty(), "reaffirmation updates present path without erasing heard voices or locking changed-human route")
	print("Accord rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func snapshot(session: Node) -> Dictionary:
	return {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate()}
func act(state: Dictionary, event: String) -> Dictionary:
	return Rules.resolve(state.nature, state.flags, state.opened, state.inventory, {"health": 64.0, "stamina": 100.0, "mana": 90.0}, event)
func step(state: Dictionary, event: String) -> Dictionary:
	var result := act(state, event)
	check(not result.is_empty(), "valid agreement transition: " + event)
	var next := state.duplicate(true)
	if not result.is_empty():
		next.flags = result.gathered
		next.opened = result.opened
	return next
