extends RefCounted
const Rules = preload("res://scripts/nature/dialogue_rules.gd")
const NAMES := {"keeper": "KEEPER_NAME", "merchant": "MERCHANT_NAME", "wayfarer": "AID_NAME", "warden": "WARDEN_NAME", "wright": "WRIGHT_NAME", "tender": "TENDER_NAME", "tracker": "TRACKER_NAME"}
static func show_page(ui: Node, kind: String, original: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page(NAMES.get(kind, "DIALOGUE_TITLE"), 620)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 285)
	scroll.follow_focus = true
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	var reaction: Label = ui._label(contents, Rules.reaction(Session.nature, kind), 18)
	reaction.name = "nature_reaction"
	reaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reaction.custom_minimum_size.x = 590
	var current := Rules.context(Session.nature)
	var remembered := Rules.memory(Session.gathered, kind, current)
	if remembered != "":
		var text: Label = ui._label(contents, "DIALOGUE_MEMORY_" + remembered.to_upper(), 16)
		text.name = "dialogue_memory"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif current == "wild_returned" and Rules.memory(Session.gathered, kind, "werewolf") != "":
		var previous: Label = ui._label(contents, "DIALOGUE_PACK_PREVIOUS", 16)
		previous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif current == "returned" and Rules.memory(Session.gathered, kind, "vampire") != "":
		var previous: Label = ui._label(contents, "DIALOGUE_PREVIOUS", 16)
		previous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for answer in Rules.ANSWERS.get(current, []):
		if remembered != "": break
		var label: String = "DIALOGUE_ANSWER_" + (kind.to_upper() + "_" if answer in ["honest", "explain", "pledge", "pack_word", "remember_pack"] else "") + answer.to_upper()
		var button: Button = ui._button(label, _answer.bind(ui, kind, answer, original), contents)
		button.name = "dialogue_" + answer
		button.disabled = not ui.world.can_dialogue(kind, answer)
	if current in ["form", "wild_form"]:
		var return_button: Button = ui._button("NATURE_SHIFT", _return_form.bind(ui, kind, original), contents)
		return_button.name = "dialogue_return_form"
	else:
		var continuation := original if original != "" else ("commission:" + kind if kind in ["warden", "wright", "tender"] else kind)
		ui._button("DIALOGUE_CONTINUE", ui.show_dialog.bind(continuation, true), contents).name = "dialogue_continue"
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _answer(ui: Node, kind: String, answer: String, original: String) -> void:
	ui.world.dialogue_action(kind, answer)
	show_page(ui, kind, original)
static func _return_form(ui: Node, kind: String, original: String) -> void:
	ui.world.player.shift_form()
	show_page(ui, kind, original)
