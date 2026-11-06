extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Pack = preload("res://scripts/nature/pack_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var wolf := {"kind": "werewolf", "form": "human", "blood": 100.0, "resolve": 80.0, "stage": 3, "history": ["werewolf"], "cure": 0, "gift": "wild"}
	check(Nature.valid(wolf), "independent lycanthropy has a coherent persistent state")
	var shifted := Nature.shift(wolf)
	check(shifted.get("form") == "wolf" and shifted.get("resolve") == 70, "wolf shape pays its own resource without touching blood")
	check(is_equal_approx(Pack.moon(5760), 1) and is_equal_approx(Pack.moon(0), 0), "moon follows an eight-day cycle with a distinct full phase")
	var initial := Nature.defaults()
	check(Pack.resolve(initial, [], [], 100, "invite").is_empty(), "new path cannot skip the completed introductory episode")
	check(not Pack.resolve(initial, [], ["waterworks_report"], 100, "invite").is_empty(), "completed episode opens another voluntary offer without changing human nature")
	check(Pack.resolve(wolf, [], ["waterworks_report"], 100, "accept").is_empty(), "acceptance cannot be repeated or used as nature switch")
	check(Nature.shift(wolf, "hybrid").is_empty(), "hybrid does not unlock with the first form")
	wolf.gift = "wild_master"
	var hybrid := Nature.shift(wolf, "hybrid")
	check(hybrid.form == "hybrid" and hybrid.resolve == 60 and hybrid.blood == 100, "mastered hybrid spends resolve without changing blood")
	wolf.form = "wolf"
	wolf.resolve = 8
	var long_wait := Nature.advance(wolf, 20)
	var stepped := wolf.duplicate(true)
	for i in 20: stepped = Nature.advance(stepped, 1)
	check(long_wait.form == "human" and is_equal_approx(long_wait.resolve, 8) and is_equal_approx(stepped.resolve, long_wait.resolve), "long elapsed time matches depletion followed by human recovery")
	wolf.form = "human"
	wolf.resolve = 0
	check(Nature.advance(wolf, 200).resolve == 100, "human shape recovers a bounded reserve without refilling blood")
	var flags := ["pack:invited", "pack:trail_0", "pack:trail_1", "pack:trail_2", "pack:heard"]
	var accepted := Pack.resolve(Nature.defaults(), flags, ["waterworks_report"], 100, "accept")
	check(accepted.nature.kind == "werewolf" and accepted.nature.form == "human" and accepted.nature.history == ["werewolf"], "prepared explicit choice changes only permanent nature and records history")
	var refusal := Pack.resolve(Nature.defaults(), flags, ["waterworks_report"], 100, "decline")
	check(refusal.nature.kind == "human" and refusal.nature.gift == "trail_oath" and refusal.nature.history.is_empty(), "declining offers a useful lasting human alternative")
	var caches := ["waterworks_report", "thicket_cache_0", "thicket_cache_1", "thicket_cache_2"]
	var early := Pack.resolve(Nature.defaults(), flags, caches, 100, "accept")
	check(early.nature.gift == "wild_master" and early.xp == 100 and "pack:mastery" in early.gathered, "collecting caches as a human never softlocks later mastery")
	check(Pack.mastery(early.nature, early.gathered, caches).xp == 0, "mastery cannot award experience twice")
	var bad: Array = early.gathered.duplicate()
	bad.append("pack:declined")
	check(not Pack.valid(early.nature, bad, caches), "accepted and declined flags cannot coexist")
	var comparing := Nature.defaults()
	comparing.stage = 2
	var considered: Array = flags + ["nature:water", "nature:garden"]
	var other := Nature.resolve(comparing, considered, ["waterworks_report"], {}, 100, "vampire")
	check(not other.is_empty() and Pack.stage(other.gathered) == 4 and other.nature.kind == "vampire", "choosing another permanent path closes incompatible pending offer without losing observations")
	var corrupted: Dictionary = accepted.nature.duplicate(true)
	corrupted.cure = 1
	var returning: Array = accepted.gathered + ["pack:return_started", "pack:release_den", "pack:release_word"]
	check(not Pack.valid(corrupted, returning, ["waterworks_report"]), "incomplete return stage cannot contain both final preparations")
	corrupted = Nature.defaults()
	corrupted.kind = "vampire"
	corrupted.stage = 3
	corrupted.gift = "blood"
	corrupted.history = ["vampire"]
	check(not Pack.valid(corrupted, flags, ["waterworks_report"]), "incompatible permanent nature cannot leave an impossible pending offer")
	check(not Pack.valid(accepted.nature, accepted.gathered, caches), "all three found caches cannot leave mastery permanently unawarded")
	var mismatched: Dictionary = early.nature.duplicate(true)
	mismatched.gift = "wild"
	check(not Pack.valid(mismatched, early.gathered, caches), "mastery memory cannot coexist with a permanently locked hybrid gift")
	print("Pack rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
