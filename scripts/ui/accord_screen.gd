extends RefCounted
const Rules = preload("res://scripts/quests/accord_rules.gd")
const Knell = preload("res://scripts/quests/knell_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
const History = preload("res://scripts/ui/junction_screen.gd")
static func show_page(ui: Node, target: String = "mentor", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("ACCORD_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		Text.text(ui, contents, "ACCORD_CONFIRM_" + confirm.to_upper(), 18)
		var button: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		button.name = "accord_confirm_" + confirm
		button.disabled = not ui.world.can_accord(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var outcome := Rules.outcome(Session.opened)
	if outcome != "":
		Text.text(ui, contents, "ACCORD_EPILOGUE_" + outcome.to_upper(), 18).name = "accord_epilogue"
		Text.text(ui, contents, "ACCORD_EFFECT_" + outcome.to_upper(), 16)
		if target == "mentor" and Knell.outcome(Session.opened) != "": Text.text(ui, contents, "KNELL_MENTOR_" + Knell.outcome(Session.opened).to_upper(), 16).name = "knell_mentor"
	else:
		Text.text(ui, contents, "ACCORD_DIALOG_" + target.to_upper(), 18)
		if target == "mentor":
			Text.text(ui, contents, "ACCORD_IDENTITY_" + Rules.identity(Session.nature).to_upper(), 17).name = "accord_identity"
			if Session.nature.kind in ["vampire", "werewolf"]: ui._button("ACCORD_RETURN_INFO", ui.show_nature.bind("status"), contents).name = "accord_return_info"
		if target in ["steward", "table"]:
			for choice in Rules.CHOICES: Text.text(ui, contents, "ACCORD_EFFECT_" + choice.to_upper(), 16)
		if Rules.recorded(Session.gathered) != "" and Rules.recorded(Session.gathered) != Rules.identity(Session.nature): Text.text(ui, contents, "ACCORD_REAFFIRM", 16)
	History.history(ui, contents)
	Text.text(ui, contents, "ACCORD_HINT_%d" % Rules.stage(Session.gathered, Session.opened), 16)
	for event in Rules.SITES:
		if Rules.SITES[event][1] != target or not ui.world.can_accord(event): continue
		var reviewed: bool = event == "affirm" or event in Rules.CHOICES
		var callback: Callable = show_page.bind(ui, target, event) if reviewed else _act.bind(ui, event, target)
		ui._button("ACCORD_ACTION_" + event.to_upper(), callback, contents).name = "accord_" + event
	ui._button("ACCORD_CONTINUE" if outcome != "" else "BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.accord_action(event):
		if event in Rules.CHOICES: show_page(ui, target)
		else: ui.resume()
	else: show_page(ui, target)
static func journal(ui: Node, parent: Node) -> void:
	if not Rules.ready(Session.gathered, Session.opened): return
	ui._label(parent, "ACCORD_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	Text.text(ui, parent, "ACCORD_HINT_%d" % Rules.stage(Session.gathered, Session.opened))
	var outcome := Rules.outcome(Session.opened)
	if outcome != "": Text.text(ui, parent, "ACCORD_EFFECT_" + outcome.to_upper(), 16)
	elif Rules.recorded(Session.gathered) != "" and Rules.recorded(Session.gathered) != Rules.identity(Session.nature): Text.text(ui, parent, "ACCORD_REAFFIRM", 16)
