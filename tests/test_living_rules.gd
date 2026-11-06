extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Schedule = preload("res://scripts/world/living/npc_schedule.gd")
const State = preload("res://scripts/world/living/world_state.gd")
const Events = preload("res://scripts/world/living/encounter_rules.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	check(Clock.advance(1439, 2) == 1441 and Clock.hour(1441) == 0, "clock crosses midnight without losing elapsed days")
	check(Clock.advance(100, -5) == 100 and Clock.advance(100, INF) == 100, "invalid elapsed time cannot rewind or corrupt clock")
	check(Clock.time_text(1445) == "00:05", "clock formats next-day time")
	check(Clock.until_morning(360) == 60 and Clock.until_morning(1380) == 480, "rest reaches next morning across midnight")
	check(Clock.daylight(720) > Clock.daylight(0), "daylight exceeds midnight illumination")
	check(Clock.weather(1020, Clock.DEFAULT_SEED) == "clear", "new journey starts in readable clear weather")
	check(Clock.weather(1440, Clock.DEFAULT_SEED) == "rain" and Clock.weather(1860, Clock.DEFAULT_SEED) == "fog", "weather changes deterministically with saved time and seed")
	check(Schedule.shop_open(420) and not Schedule.shop_open(1260), "shop opens and closes at authored hours")
	check(Schedule.destination("crossing", "keeper", 0, 0).distance_to(Vector2(440, 470)) < 150, "essential NPC remains accessible near camp at night")
	check(Schedule.destination("lake", "wayfarer", 1200, 1) == Vector2(480, 620), "unfinished side quest does not move injured NPC away")
	check(Schedule.destination("lake", "wayfarer", 0, 2) == Vector2(420, 610), "helped NPC rests at night, including after midnight")
	check("shelter" in Events.eligible("crossing", 720, "rain", [], 0), "rain enables contextual peaceful event")
	check("shelter" not in Events.eligible("crossing", 720, "clear", [], 0), "wrong weather excludes event")
	check("shelter" not in Events.eligible("crossing", 720, "rain", ["shelter"], 0), "remembered event cannot repeat")
	check(Events.eligible("ruins", 720, "rain", [], 0).is_empty(), "outdoor events do not appear inside unrelated region")
	check("fireflies" in Events.eligible("lake", 30, "fog", [], 0), "night event remains eligible across midnight")
	check(Events.choose("crossing", 1080, 43119, [], 0) == "camp_song" and Events.choose("crossing", 1080, 43118, [], 0) == "lost_pack", "same world state cannot reroll event on load")
	check(Events.resolve("shelter", "herb", {}, 50, 0).is_empty(), "event cannot consume missing resources")
	var help := Events.resolve("shelter", "magic", {"coin": 2}, 50, 0)
	check(help.get("mana") == 25 and help.get("trust") == 1, "noncombat magic choice charges focus and changes trust")
	var quiet := Events.resolve("fireflies", "observe", {}, 95, 0)
	check(quiet.get("mana") == 100, "peaceful restoration respects mana cap")
	check(Events.resolve("lost_pack", "keep", {"coin": 999}, 50, 0).is_empty(), "full purse rejects outcome without erasing encounter")
	check(Trade.quote("iron_sword", false, 3) == 14 and Trade.quote("iron_sword", false, 0) == 15, "trust changes actual merchant prices")
	check(Trade.quote("herb", false, 10) >= Trade.quote("herb", true, 10), "discount cannot create resale profit")
	var state := State.defaults()
	check(State.valid(state), "default living-world state validates")
	for key in ["minutes", "seed", "npcs", "reputation", "seen", "next_event", "active"]:
		var bad := state.duplicate(true)
		bad.erase(key)
		check(not State.valid(bad), "missing world field rejected")
	var bad := state.duplicate(true)
	bad.minutes = INF
	check(not State.valid(bad), "nonfinite world time rejected")
	bad = state.duplicate(true)
	bad.npcs = {"crossing:merchant": [350, 440]}
	check(State.valid(bad), "actual scheduled NPC coordinates validate")
	bad.npcs["ruins:merchant"] = [350, 440]
	check(not State.valid(bad), "NPC cannot be attached to an unrelated region")
	bad = state.duplicate(true)
	bad.active = {"id": "shelter", "region": "crossing", "position": [650, 600]}
	bad.seen = ["shelter"]
	check(not State.valid(bad), "resolved event cannot remain active")
	print("Living world rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
