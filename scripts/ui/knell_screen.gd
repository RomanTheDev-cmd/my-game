extends RefCounted
const Rules = preload("res://scripts/quests/knell_rules.gd")
const Accord = preload("res://scripts/quests/accord_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
static func entry(ui: Node, parent: Node) -> void:
	if Rules.available(Session.opened): ui._button("KNELL_TITLE", ui.show_dialog.bind("knell:keeper", true), parent).name = "knell_entry"
static func show_page(ui: Node, target: String = "keeper", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("KNELL_PLAQUE_TITLE" if target.begins_with("plaque_") else "KNELL_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	# Actions sit below the text so keyboard focus never scrolls the start of a reply out of view.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	ui.screen.add_child(actions)
	if confirm != "":
		Text.text(ui, contents, "KNELL_CONFIRM_" + confirm.to_upper(), 18)
		var button: Button = _action(ui, "NATURE_CONFIRM", _act.bind(ui, confirm, target), actions)
		button.name = "knell_confirm_" + confirm
		button.disabled = not ui.world.can_knell(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var stage := Rules.stage(Session.gathered, Session.defeated, Session.opened)
	var identity := Accord.identity(Session.nature)
	if target.begins_with("plaque_"):
		var id := target.trim_prefix("plaque_")
		Text.text(ui, contents, "KNELL_TEXT_" + id.to_upper(), 18).name = "knell_inscription"
		if id == "ossuary": Text.text(ui, contents, "KNELL_SENSE_" + identity.to_upper(), 16).name = "knell_sense"
		if "knell:plaque:" + id in Session.gathered: Text.text(ui, contents, "KNELL_PLAQUE_READ", 16)
		elif ui.world.can_knell("read_" + id): _action(ui, "KNELL_ACTION_READ", _act.bind(ui, "read_" + id, target), actions).name = "knell_read"
		elif stage == 1 and not ui.world.safe_to_rest(): Text.text(ui, contents, "KNELL_PLAQUE_UNSAFE", 16).name = "knell_unsafe"
		_hint(ui, contents, stage)
		ui._button("BACK", ui.resume)
		ui._focus_first()
		return
	match stage:
		0:
			Text.text(ui, contents, "KNELL_REQUEST", 18).name = "knell_request"
			Text.text(ui, contents, "KNELL_REQUEST_" + identity.to_upper(), 16).name = "knell_identity"
			Text.text(ui, contents, "KNELL_ACCORD_" + Accord.outcome(Session.opened).to_upper(), 16).name = "knell_accord"
		3:
			Text.text(ui, contents, "KNELL_REPORT_" + identity.to_upper(), 18).name = "knell_report"
			for choice in Rules.CHOICES: Text.text(ui, contents, "KNELL_EFFECT_" + choice.to_upper(), 16)
		4:
			Text.text(ui, contents, "KNELL_EPILOGUE_" + Rules.outcome(Session.opened).to_upper(), 18).name = "knell_epilogue"
			Text.text(ui, contents, "KNELL_AFTER_" + Accord.outcome(Session.opened).to_upper(), 16)
		_:
			Text.text(ui, contents, "KNELL_WAITING", 18).name = "knell_waiting"
	var recorded := Rules.recorded(Session.gathered)
	if recorded != "" and recorded != identity and stage < 4: Text.text(ui, contents, "KNELL_CHANGED", 16).name = "knell_changed"
	_hint(ui, contents, stage)
	for event in ["accept"] + Rules.CHOICES:
		if not ui.world.can_knell(event): continue
		var callback: Callable = _act.bind(ui, event, target) if event == "accept" else show_page.bind(ui, target, event)
		_action(ui, "KNELL_ACTION_" + event.to_upper(), callback, actions).name = "knell_" + event
	_action(ui, "KNELL_OTHER", ui.show_dialog.bind("keeper", true), actions).name = "knell_other"
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _action(ui: Node, key: String, callback: Callable, parent: Node) -> Button:
	var button: Button = ui._button(key, callback, parent)
	button.custom_minimum_size.x = 190
	return button
static func _hint(ui: Node, parent: Node, stage: int) -> void:
	var hint: Label = Text.text(ui, parent, "KNELL_HINT_%d" % stage, 16)
	if stage == 1: hint.text = ui.tr("KNELL_HINT_1") % [Rules.read_count(Session.gathered), Rules.PLAQUES.size()]
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.knell_action(event):
		if event == "accept": ui.resume()
		else: show_page(ui, target)
	else: show_page(ui, target)
static func journal(ui: Node, parent: Node) -> void:
	if not Rules.available(Session.opened): return
	ui._label(parent, "KNELL_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	var stage := Rules.stage(Session.gathered, Session.defeated, Session.opened)
	_hint(ui, parent, stage)
	if stage == 4: Text.text(ui, parent, "KNELL_EFFECT_" + Rules.outcome(Session.opened).to_upper(), 16)
static func hud(stage: int) -> String:
	return "KNELL_HUD_%d" % stage
