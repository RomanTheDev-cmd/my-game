extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/city_rules.gd")
const CityFixture = preload("res://tests/support/city_fixture.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Regions.valid("velshof"), "third regional campaign section exists as an actual living city")
	var session := root.get_node("Session")
	Fixture.ready(session)
	var bad: Dictionary = session.snapshot(Vector2(410, 490))
	bad.gathered.append("city:signature:crafter")
	check(not session.Store.validate(bad), "orphan agreement cannot enter a valid save")
	check(CityFixture.ready(session), "main commitment starts independently of both other regional reports")
	var old: Dictionary = session.snapshot(Vector2(410, 490))
	check(session.Store.validate(old) and session.Store.migrate(old) == old and session.opened.is_empty(), "old v9 data needs neither mandatory city fields nor other regional completion")
	var state := state_for(session)
	var accepted := act(state, "accept")
	check("city:accepted" in accepted.gathered and "city:accepted" not in state.gathered, "separate acceptance does not mutate caller or force nature")
	check(act(accepted, "accept").is_empty() and act(state, "draft_shared").is_empty(), "acceptance cannot repeat or be skipped")
	var heard := act(act(accepted, "hear_archivist"), "hear_crafter")
	check(Rules.heard(heard.gathered) and not act(act(accepted, "hear_crafter"), "hear_archivist").is_empty(), "both actual viewpoints can be recorded in either order")
	var shared := act(heard, "draft_shared")
	check(Rules.draft(shared.gathered) == "shared" and act(shared, "sign_crafter").is_empty() and act(shared, "sign_archivist").is_empty(), "a draft alone does not manufacture either NPC consent")
	var supplied := act(shared, "supply")
	check(supplied.inventory.potion == 0 and shared.inventory.potion == 1 and supplied.vitals.health == 64, "actual personal aid consumes one item without silently healing hero")
	check(act(supplied, "supply").is_empty() and not act(supplied, "sign_crafter").is_empty(), "supply grants only its appropriate one-time agreement route")
	var copied := act(supplied, "copy")
	check(copied.vitals.stamina == 80 and copied.vitals.mana == 90 and copied.vitals.health == 64 and copied.minutes == 1030 and copied.elapsed == 10, "public copy spends its advertised time/effort and never refills magic or wounds")
	var signed := act(act(copied, "sign_crafter"), "sign_archivist")
	check(Rules.stage(signed.gathered, signed.opened) == 2 and act(signed, "sign_archivist").is_empty(), "two distinct independent consents permit review without farming signatures")
	var revised := act(signed, "draft_release")
	check(Rules.stage(revised.gathered, revised.opened) == 1 and not revised.gathered.any(func(flag): return flag in Rules.SIGNATURES) and "city:copy" in revised.gathered and "city:supply" in revised.gathered, "revision explicitly withdraws both signatures while preserving already paid aid and copy")
	check(act(revised, "sign_crafter").is_empty() and not act(revised, "sign_archivist").is_empty(), "counteroffers differ for revised terms rather than reusing stale consent")
	var worked := act(revised, "work")
	check(worked.vitals.stamina == 60 and worked.minutes == 1050 and worked.vitals.health == 64, "common workshop guarantee remains reachable after earlier supply with its real price")
	var final_release := act(act(act(worked, "sign_crafter"), "sign_archivist"), "seal")
	check(final_release.xp == 100 and final_release.trust.roadfolk == 1 and final_release.trust.wardens == 2 and Rules.stage(final_release.gathered, final_release.opened) == 3, "revised agreement has its own one-time outcome and actual relation consequences")
	var final_shared := act(signed, "seal")
	check(final_shared.xp == 100 and final_shared.trust.roadfolk == 2 and final_shared.trust.wardens == 1, "original accepted agreement keeps distinct consequences")
	for event in ["draft_shared", "work", "copy", "sign_crafter", "seal"]: check(act(final_release, event).is_empty(), "final record cannot be revised or farmed: " + event)
	signed.inventory.coin = 999
	check(not act(signed, "seal").is_empty(), "full wallet does not block a campaign agreement")
	for kind in ["vampire", "werewolf"]:
		check(CityFixture.ready(session, kind), "nature fixture is compatible with accepted main commitment")
		state = state_for(session)
		heard = act(act(act(state, "accept"), "hear_crafter"), "hear_archivist")
		check(not act(heard, "work").is_empty() and not act(heard, "copy").is_empty(), "every nature retains ordinary workshop and public copy alternatives")
		if kind == "vampire":
			var memory := act(act(heard, "draft_shared"), "memory")
			check(memory.nature.blood == 60 and memory.vitals.mana == 80 and memory.minutes == 1020 and Rules.agrees(memory.gathered, "archivist"), "consented own-blood memory has distinct resource cost and agreement scope")
			check(not Rules.agrees(act(memory, "draft_release").gathered, "archivist"), "private memory cannot silently substitute for revised public record")
			var labor := act(heard, "work")
			check(is_equal_approx(labor.nature.blood, 79.2) and labor.vitals.mana == 90, "ordinary working time advances hunger without magic regeneration")
		else:
			check(act(heard, "strength").is_empty(), "ordinary or wolf body cannot bypass mastered hybrid requirement")
			heard.nature.gift = "wild_master"
			heard.nature.form = "hybrid"
			heard.gathered.append("pack:mastery")
			var strength := act(heard, "strength")
			check(strength.nature.resolve == 62 and strength.vitals.stamina == 100 and strength.minutes == 1020, "actual mastered hybrid has its own finite effort price and no fake elapsed work time")
	check(CityFixture.ready(session), "old-state fixture remains valid")
	for corruption in ["unknown", "orphan_heard", "two_drafts", "unearned_signature", "wrong_history", "skipped_hearing", "double_work", "premature_final", "inconsistent_final", "wrong_opened", "wrong_defeated", "duplicate", "orphan_supply", "supply_in_gathered", "supply_in_defeated"]:
		bad = session.snapshot(Vector2(410, 490))
		bad.gathered.append("city:accepted")
		match corruption:
			"unknown": bad.gathered.append("city:unknown")
			"orphan_heard":
				bad.gathered.erase("city:accepted")
				bad.gathered.append("city:heard:crafter")
			"two_drafts": bad.gathered.append_array(Rules.DRAFTS)
			"unearned_signature": bad.gathered.append_array(["city:draft:shared", "city:signature:crafter"])
			"wrong_history": bad.gathered.append_array(["city:heard:archivist", "city:memory"])
			"skipped_hearing": bad.gathered.append("city:work:manual")
			"double_work": bad.gathered.append_array(["city:heard:crafter", "city:work:manual", "city:work:strength"])
			"premature_final": bad.opened.append(Rules.REPORT)
			"inconsistent_final": bad.gathered.append("city:outcome:shared")
			"wrong_opened": bad.opened.append("city:accepted")
			"wrong_defeated": bad.defeated.append(Rules.REPORT)
			"duplicate": bad.gathered.append("city:accepted")
			"orphan_supply": bad.opened.append("courtyard_supplies")
			"supply_in_gathered": bad.gathered.append("courtyard_supplies")
			"supply_in_defeated": bad.defeated.append("courtyard_supplies")
		check(not session.Store.validate(bad), "unreachable city agreement state rejected: " + corruption)
	print("City rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func state_for(session: Node) -> Dictionary:
	return {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate(), "vitals": {"health": 64.0, "stamina": 100.0, "mana": 90.0}, "minutes": 1020.0}
func act(state: Dictionary, event: String) -> Dictionary:
	return Rules.resolve(state.nature, state.gathered, state.opened, state.inventory, state.vitals, state.minutes, event)
