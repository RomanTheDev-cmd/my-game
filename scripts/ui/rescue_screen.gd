extends RefCounted
const Rules = preload("res://scripts/quests/rescue_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
const History = preload("res://scripts/ui/junction_screen.gd")
static func show_page(ui: Node, _target: String = "mentor", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("RESCUE_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		Text.text(ui, contents, "RESCUE_CONFIRM_" + confirm.to_upper(), 18)
		var button: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm), contents)
		button.name = "rescue_confirm_" + confirm
		button.disabled = not ui.world.can_rescue(confirm)
		ui._button("BACK", show_page.bind(ui))
		ui._focus_first()
		return
	var stage := Rules.stage(Session.gathered, Session.opened)
	Text.text(ui, contents, "RESCUE_DIALOG_%d" % stage, 18)
	if stage == 5:
		Text.text(ui, contents, "RESCUE_AFTER_" + Rules.method(Session.gathered).to_upper(), 17).name = "rescue_outcome"
		if "rescue:rested" in Session.gathered: Text.text(ui, contents, "RESCUE_RESTED", 16)
	History.history(ui, contents)
	if "werewolf" in Session.nature.history or "vampire" in Session.nature.history:
		Text.text(ui, contents, "RESCUE_HISTORY_" + ("RETURNED" if Session.nature.kind == "human" else Session.nature.kind.to_upper()), 16)
	Text.text(ui, contents, "RESCUE_HINT_%d" % stage, 16)
	for event in Rules.SITES:
		if event == "safe" or not ui.world.can_rescue(event): continue
		var reviewed: bool = event in ["blood", "scent", "free", "report", "keep", "release"]
		ui._button("RESCUE_ACTION_" + event.to_upper(), show_page.bind(ui, "mentor", event) if reviewed else _act.bind(ui, event), contents).name = "rescue_" + event
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String) -> void:
	if ui.world.rescue_action(event): ui.resume()
	else: show_page(ui)
static func journal(ui: Node, parent: Node) -> void:
	if "preparation_report" not in Session.opened: return
	ui._label(parent, "RESCUE_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	Text.text(ui, parent, "RESCUE_HINT_%d" % Rules.stage(Session.gathered, Session.opened))
	if Rules.method(Session.gathered) != "": Text.text(ui, parent, "RESCUE_METHOD_" + Rules.method(Session.gathered).to_upper(), 16)
	for side in Rules.COILS:
		if Rules.cut(Session.gathered, side) != "": Text.text(ui, parent, "RESCUE_DONE_" + side.to_upper(), 16)
	Text.text(ui, parent, "RESCUE_RETRY_HELP", 16)
