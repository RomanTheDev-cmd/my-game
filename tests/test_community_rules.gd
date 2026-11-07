extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/factions/community_rules.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func act(state: Dictionary, event: String) -> Dictionary:
	return Rules.resolve(state.nature, state.gathered, state.opened, state.inventory, state.owned, state.reputation, state.mana, event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Regions.valid("haven") and Regions.exits("lake").any(func(exit): return exit.destination == "haven"), "new community location is connected to existing world")
	var session := root.get_node("Session")
	session.fresh()
	var bad: Dictionary = session.snapshot(Vector2(410, 490))
	bad.gathered.append("community:seen:supply")
	check(not session.Store.validate(bad), "orphaned community progress cannot enter a save")
	for id in ["watch", "circle", "pack"]:
		if id == "watch": Fixture.completed_episode(session)
		elif id == "circle": Fixture.vampire(session)
		else: PackFixture.wolf(session)
		var state := {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": {"herb": 3, "potion": 2, "coin": 24}, "owned": session.gear_owned.duplicate(), "reputation": session.world_state.reputation.duplicate(), "mana": 70.0}
		var before := state.duplicate(true)
		var joined := act(state, "join_" + id)
		check(not joined.is_empty() and Rules.guild(joined.gathered) == id and joined.nature == state.nature, "voluntary membership preserves permanent nature")
		check(state == before, "rules never mutate caller state")
		check(act(joined, "join_" + id).is_empty() and act(joined, "aid_craft").is_empty(), "membership and preparation cannot be repeated or skipped")
		var supply := act(joined, "seen_supply")
		var prepared := act(supply, "seen_route")
		check(Rules.stage(prepared.gathered) == 2 and act(supply, "seen_supply").is_empty(), "two independent observations prepare help without duplicate farming")
		var aided := act(prepared, "aid_craft")
		check(not aided.is_empty() and aided.inventory.herb == 1 and aided.inventory.potion == 1 and aided.mana == 70, "all three natures retain the useful craft alternative with its actual price")
		check(act(aided, "aid_craft").is_empty(), "one delivered help cannot consume or award twice")
		var report := act(aided, "report_share")
		check(Rules.stage(report.gathered) == 4 and report.xp == 60 and report.inventory.coin == 24 and "relay_cloak" in report.owned, "shared outcome awards experience and usable gear without currency")
		check(report.reputation == {"roadfolk": 2, "wardens": 2, "tenders": 2} and act(report, "report_provision").is_empty(), "shared outcome changes all relationships once and excludes the other reward")
		var provision := act(aided, "report_provision")
		check(provision.inventory.coin == 36 and provision.reputation[Rules.GROUPS[id]] == 1, "road provision has its separate explained currency and group consequence")
		var full := aided.duplicate(true)
		full.inventory.coin = 999
		check(act(full, "report_provision").is_empty() and not act(full, "report_share").is_empty(), "full wallet retains an alternative and the unclaimed help")
		if id == "circle":
			var blood := act(prepared, "aid_blood")
			check(blood.nature.blood == 60 and blood.mana == 55 and blood.inventory == prepared.inventory, "blood aid pays blood and magic rather than herbs")
			prepared.nature.blood = 29
			check(act(prepared, "aid_blood").is_empty(), "blood aid requires the advertised remaining reserve")
		if id == "pack":
			check(act(prepared, "aid_track").is_empty(), "tracking help needs actual wolf form")
			prepared.nature.form = "wolf"
			var track := act(prepared, "aid_track")
			check(track.nature.resolve == 60 and track.inventory == prepared.inventory and track.mana == 70, "tracking pays independent reserve without mixing blood or crafting costs")
			prepared.nature.resolve = 29
			check(act(prepared, "aid_track").is_empty(), "tracking keeps the advertised reserve threshold")
		var damaged: Array = prepared.gathered.duplicate()
		damaged.append("community:join:" + ("circle" if id != "circle" else "watch"))
		check(not Rules.valid(prepared.nature, damaged, prepared.opened), "multiple memberships reject ambiguous saves")
		damaged = joined.gathered.duplicate()
		damaged.append("community:aid:craft")
		check(not Rules.valid(joined.nature, damaged, joined.opened), "help without observations rejects a damaged save")
	for flag in ["community:typo", "community:report:share", "community:join:pack"]:
		bad = session.snapshot(Vector2(410, 490))
		bad.gathered = [flag]
		check(not session.Store.validate(bad), "unknown orphan or wrong-history community progress cannot enter a save")
	Fixture.completed_episode(session)
	for misplaced in [["community:unknown"], ["community:join:watch"], ["community:seen:route", "community:seen:route"]]:
		bad = session.snapshot(Vector2(410, 490))
		bad.opened.append_array(misplaced)
		check(not session.Store.validate(bad), "reserved community progress cannot bypass checks in the wrong save collection")
	for misplaced in [["community_report"], ["community_report", "community_report"]]:
		bad = session.snapshot(Vector2(410, 490))
		bad.gathered.append_array(misplaced)
		check(not session.Store.validate(bad), "completion marker cannot bypass checks in the wrong save collection")
	print("Community rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
