extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var vampire := Nature.defaults()
	vampire.kind = "vampire"
	vampire.stage = 3
	vampire.history = ["vampire"]
	vampire.gift = "blood_bat"
	check(Nature.valid(vampire), "later training unlocks bat without replacing permanent nature")
	check(Nature.shift(vampire, "bat").is_empty(), "mobile form requires a known safe landing anchor")
	var anchor := {"region": "waterworks", "position": [1500.0, 430.0]}
	var bat := Nature.shift(vampire, "bat", anchor)
	check(bat.form == "bat" and bat.blood == 88 and bat.landing == anchor, "flight has an actual entry cost and a preserved anchor")
	check(Nature.shift(bat, "battle").is_empty(), "mobile form must land before entering a full battle body")
	check(Nature.valid(bat) and not Nature.can_spell(bat, "fire"), "bat is a valid noncasting exploration shape")
	check(Nature.shift(vampire, "mist", anchor).is_empty(), "first lesson cannot skip the second form")
	check(Nature.shift(bat).form == "human", "free return preserves permanent nature")
	var spent := Nature.advance(bat, 100)
	check(spent.form == "human" and spent.blood == 0 and spent.landing == anchor, "depletion retains anchor until physics resolves landing")
	var low := vampire.duplicate(true)
	low.blood = 16
	check(Nature.shift(low, "bat", anchor).is_empty(), "entry needs reserve after transformation cost")
	var flags := Nature.STUDIES.duplicate()
	var opened := ["waterworks_report"]
	vampire.gift = "blood"
	check(Nature.resolve(vampire, flags, opened, {}, 19, "learn_bat").is_empty(), "learning requires its mana price")
	var lesson := Nature.resolve(vampire, flags, opened, {}, 70, "learn_bat")
	check(not lesson.is_empty() and lesson.nature.gift == "blood_bat" and lesson.mana == 50 and lesson.xp == 20, "first lesson records actual price and single reward")
	check(Nature.resolve(lesson.nature, lesson.gathered, opened, {}, 70, "learn_bat").is_empty(), "lessons cannot farm rewards")
	check(Nature.resolve(lesson.nature, lesson.gathered, opened, {}, 70, "learn_mist").is_empty(), "second lesson requires real exploration")
	opened.append("waterworks_flight")
	var second := Nature.resolve(lesson.nature, lesson.gathered, opened, {}, 70, "learn_mist")
	check(not second.is_empty() and second.nature.gift == "blood_mist" and second.mana == 50, "second lesson follows the authored flight challenge")
	var mist := Nature.shift(second.nature, "mist", anchor)
	check(mist.form == "mist" and Nature.valid(mist) and Nature.advance(mist, 10).blood == 48, "mist has a separate faster drain")
	check(not Nature.quest_valid(second.nature, lesson.gathered, opened), "missing second lesson history rejects damaged saves")
	vampire.gift = "blood_bat"
	for invalid in [{}, {"region": "unknown", "position": [30, 30]}, {"region": "lake", "position": [NAN, 30]}, {"region": "lake", "position": [1, 30]}]:
		check(Nature.shift(vampire, "bat", invalid).is_empty(), "invalid anchors cannot enter mobile forms")
	print("Flight rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
