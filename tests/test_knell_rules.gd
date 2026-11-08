extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/knell_rules.gd")
const Combat = preload("res://scripts/combat/bell_rules.gd")
const Fixture = preload("res://tests/support/knell_fixture.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const VITALS := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
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
	check(Regions.valid("undercroft") and Regions.exits("crossing").any(func(exit): return exit.destination == "undercroft") and Regions.exits("undercroft").any(func(exit): return exit.destination == "crossing"), "optional crypt is an actual region connected both ways to the crossing")
	var enemies: Array = Regions.get_region("undercroft").enemies
	check(enemies.all(func(entry): return not entry[0].begins_with("knell")) and Regions.herb_id("undercroft", Vector2(420, 1060)).begins_with("undercroft:"), "region enemies/herbs use a namespace distinct from case progress flags")
	session.fresh()
	var fresh: Dictionary = session.snapshot(Vector2(410, 490))
	check(session.Store.validate(fresh) and session.Store.migrate(fresh) == fresh, "old v9 needs no new case fields or reset")
	for corruption in ["accepted", "plaque", "bell", "report", "region", "tongue", "supplies"]:
		var data := fresh.duplicate(true)
		match corruption:
			"accepted": data.gathered.append_array(["knell:accepted", "knell:identity:human"])
			"plaque": data.gathered.append("knell:plaque:hall")
			"bell": data.defeated.append("undercroft_bell")
			"report": data.opened.append_array(["knell_report", "knell_keeper"])
			"region": data.region = "undercroft"
			"tongue":
				data.gear_owned.append("bell_tongue")
			"supplies": data.opened.append("knell_supplies")
		check(not session.Store.validate(data), "unearned case progress cannot enter a save without the actual common decision: " + corruption)
	check(Fixture.ready(session), "actual campaign plus recorded accord forms the case prerequisite")
	var old: Dictionary = session.snapshot(Vector2(520, 490))
	check(session.Store.validate(old) and Rules.stage(old.gathered, old.defeated, old.opened) == 0, "decided world without the case remains valid and untouched")
	var state := snapshot(session)
	for event in ["read_hall", "silence", "keeper", "kept"]: check(act(state, event).is_empty(), "nothing can be skipped before acceptance: " + event)
	var bat := state.duplicate(true)
	bat.nature.form = "battle"
	check(act(bat, "accept").is_empty(), "case is accepted only in an ordinary speaking form")
	state = step(state, "accept")
	check(Rules.recorded(state.flags) == "human" and Rules.can_enter(state.flags) and act(state, "accept").is_empty(), "acceptance records present identity once and unlocks the door")
	check(act(state, "silence", "undercroft").is_empty() and not Rules.armed(state.flags, state.defeated), "bell is dormant until all names are read")
	check(act(state, "read_hall").is_empty() and not act(state, "read_hall", "undercroft").is_empty(), "names can be read only inside the crypt")
	var first := act(state, "read_gallery", "undercroft")
	check(first.xp == 10 and first.vitals == VITALS and first.inventory == state.inventory, "each plaque gives small one-time exploration experience without hidden cost")
	state = step(state, "read_gallery")
	check(act(state, "read_gallery").is_empty() and Rules.read_count(state.flags) == 1, "a plaque cannot be farmed")
	state = step(state, "read_ossuary")
	check(not Rules.armed(state.flags, state.defeated), "two of three plaques do not wake the bell")
	state = step(state, "read_hall")
	check(Rules.armed(state.flags, state.defeated) and Rules.stage(state.flags, state.defeated, state.opened) == 2, "plaques read in any order wake the bell")
	check(act(state, "silence").is_empty(), "victory cannot be recorded away from the bell")
	var win := act(state, "silence", "undercroft")
	check(win.xp == 120 and Rules.BELL in win.defeated, "recorded silence awards boss experience once")
	state = step(state, "silence")
	check(act(state, "silence").is_empty() and act(state, "read_hall").is_empty(), "victory cannot repeat")
	check(act(state, "kept", "undercroft").is_empty(), "the tongue's fate is decided with the keeper, not in the crypt")
	for choice in Rules.CHOICES:
		var result := act(state, choice)
		check(result.xp == 80 and Rules.outcome(result.opened) == choice and Rules.REPORT in result.opened, "each actual choice gives equal experience and a single outcome: " + choice)
		if choice == "keeper": check(result.inventory.coin == state.inventory.coin + 20 and result.trust == {"roadfolk": 1} and Rules.TONGUE not in result.owned, "returned tongue gives coins and trust, not the weapon")
		else: check(Rules.TONGUE in result.owned and result.trust.is_empty() and result.inventory == state.inventory, "kept tongue gives only the unique weapon")
		var done := step(state, choice)
		check(Rules.stage(done.flags, done.defeated, done.opened) == 4 and act(done, "keeper").is_empty() and act(done, "kept").is_empty(), "final choice is unique and cannot be overwritten")
	var rich := state.duplicate(true)
	rich.inventory.coin = 995
	var capped := act(rich, "keeper")
	check(capped.inventory.coin == 999, "full purse never blocks the returned-tongue decision")
	check(Rules.outcome(state.opened) == "", "independent alternatives do not mutate their shared input")
	check(Fixture.silenced(session, "human", "community"), "fixture reaches the report through actual session writes")
	var base: Dictionary = session.snapshot(Vector2(520, 490))
	check(session.Store.validate(base), "real silenced state is a valid save")
	for corruption in ["unknown", "duplicate", "two_identities", "no_identity", "wrong_history", "orphan_bell", "orphan_choice", "two_choices", "report_without_choice", "tongue_without_kept", "wrong_opened", "wrong_defeated", "wrong_gathered", "unknown_enemy", "cache_without_bell", "supplies_wrong_policy", "duplicate_echo"]:
		var data := base.duplicate(true)
		match corruption:
			"unknown": data.gathered.append("knell:unused")
			"duplicate": data.gathered.append("knell:plaque:hall")
			"two_identities": data.gathered.append("knell:identity:oath")
			"no_identity": data.gathered.erase("knell:identity:human")
			"wrong_history": data.gathered = data.gathered.map(func(flag): return "knell:identity:vampire" if flag == "knell:identity:human" else flag)
			"orphan_bell":
				data.gathered.erase("knell:plaque:hall")
			"orphan_choice":
				data.defeated.erase("undercroft_bell")
				data.opened.append_array(["knell_report", "knell_kept"])
				data.gear_owned.append("bell_tongue")
			"two_choices": data.opened.append_array(["knell_report", "knell_kept", "knell_keeper"])
			"report_without_choice": data.opened.append("knell_report")
			"tongue_without_kept": data.gear_owned.append("bell_tongue")
			"wrong_opened": data.opened.append("knell:accepted")
			"wrong_defeated": data.defeated.append("knell_report")
			"wrong_gathered": data.gathered.append("undercroft_bell")
			"unknown_enemy": data.defeated.append("undercroft_shade")
			"cache_without_bell":
				data.defeated.erase("undercroft_bell")
				data.gathered.erase("knell:plaque:hall")
				data.opened.append("knell_cache")
			"supplies_wrong_policy":
				data.opened.append("knell_supplies")
				data.opened.erase("accord_community")
				data.opened.append("accord_renewal")
			"duplicate_echo": data.defeated.append_array(["undercroft_echo_1", "undercroft_echo_1"])
		check(not session.Store.validate(data), "save rejects inconsistent case progress: " + corruption)
	var supplied := base.duplicate(true)
	supplied.opened.append("knell_supplies")
	check(session.Store.validate(supplied), "community decision legitimately permits its undercroft supplies")
	var room := base.duplicate(true)
	room.region = "undercroft"
	room.position = [330.0, 820.0]
	check(session.Store.validate(room), "accepted case permits a checkpoint inside the crypt")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.accepted(session, kind, "release"), "each voluntary nature can accept the case")
		state = snapshot(session)
		check(Rules.recorded(state.flags) == kind, "acceptance records the actual special nature")
		var events := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
		for event in events: check(session.nature_event(event, Vector2(600, 600), VITALS) if kind == "vampire" else session.pack_event(event, Vector2(600, 600), VITALS), "separate full return remains possible mid-case: " + event)
		check(session.Store.validate(session.snapshot(Vector2(520, 490))) and Rules.recorded(session.gathered) == kind, "historical acceptance identity stays valid after return")
		session.region = "undercroft"
		for id in ["hall", "gallery", "ossuary"]: check(session.knell_event("read_" + id, Vector2(330, 820), VITALS), "returned human continues the same case: " + id)
		check(session.knell_event("silence", Vector2(1300, 705), VITALS), "returned human can finish the boss record")
	# Shared combat rules.
	check(Combat.ring_crosses(90, 100, 95) and Combat.ring_crosses(90, 100, 110) and not Combat.ring_crosses(90, 100, 130) and not Combat.ring_crosses(20, 30, 90), "ring strikes only where its front passes")
	check(not Combat.ring_crosses(100, 90, 95) and not Combat.ring_crosses(NAN, 10, 5), "malformed ring data cannot strike")
	check(Combat.attack(1, 0).kind == "toll" and Combat.attack(1, 2).kind == "summon" and Combat.attack(1, 3).kind == "knell" and Combat.attack(2, 0).kind == "peal" and Combat.attack(2, 0).rings == 2, "two phases have distinct readable patterns")
	check(Combat.attack(2, 3).windup < Combat.attack(1, 3).windup and Combat.attack(1, 3).windup >= 2.0, "great knell is always long telegraphed, shorter in phase two")
	check(Combat.bell_multiplier("exposed") > 1.5 and Combat.bell_multiplier("windup") < 1 and Combat.echo_multiplier("fade") == 0 and Combat.echo_multiplier("recover") > 1, "exposure and fading change damage in readable ways")
	check(Combat.spell_multiplier("light") > 1 and Combat.spell_multiplier("frost") == 1 and Combat.spell_multiplier("blood") == 1, "light is the human advantage against tolls")
	check(Combat.phase(230, 460) == 2 and Combat.phase(231, 460) == 1 and Combat.phase(0, 460) == 0, "bell phase threshold is half health")
	print("Knell rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func snapshot(session: Node) -> Dictionary:
	return {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "defeated": session.defeated.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate(), "owned": session.gear_owned.duplicate()}
func act(state: Dictionary, event: String, region: String = "crossing") -> Dictionary:
	return Rules.resolve(state.nature, state.flags, state.defeated, state.opened, state.inventory, state.owned, VITALS, event, region)
func step(state: Dictionary, event: String) -> Dictionary:
	var result := act(state, event, "undercroft" if event.begins_with("read_") or event == "silence" else "crossing")
	check(not result.is_empty(), "valid case transition: " + event)
	var next := state.duplicate(true)
	if not result.is_empty():
		next.flags = result.gathered
		next.defeated = result.defeated
		next.opened = result.opened
		next.inventory = result.inventory
		next.owned = result.owned
	return next
