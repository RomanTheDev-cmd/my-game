extends RefCounted
const Rules = preload("res://scripts/quests/preparation_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
const History = preload("res://scripts/ui/junction_screen.gd")
static func show_page(ui: Node, target: String = "steward", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("PREP_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		Text.text(ui, contents, "PREP_CONFIRM_" + confirm.to_upper(), 18)
		var button: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		button.name = "prep_confirm_" + confirm
		button.disabled = not ui.world.can_preparation(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	Text.text(ui, contents, "PREP_DIALOG_" + target.to_upper(), 18)
	Text.text(ui, contents, "PREP_HINT_%d" % Rules.stage(Session.gathered, Session.opened), 16)
	if target in ["witness", "crafter", "mentor", "steward"]:
		History.history(ui, contents)
		if "junction:choice:private" in Session.gathered: Text.text(ui, contents, "PREP_HISTORY_PRIVATE", 16)
		else: Text.text(ui, contents, "PREP_HISTORY_PUBLIC", 16)
	if target in ["table", "gate", "steward"]: settings(ui, contents)
	if target in ["witness", "crafter"] and Session.region == "rotunda":
		Text.text(ui, contents, "PREP_POST_" + ("WAIT" if Rules.layout(Session.gathered) == "" else ("NORTH" if Rules.post(Session.gathered, target) == Rules.POSTS.north else "SOUTH")), 16)
	for event in Rules.SITES:
		if event == "prove" or Rules.SITES[event][1] != target or Rules.SITES[event][0] != Session.region: continue
		if not ui.world.can_preparation(event): continue
		var reviewed: bool = event.begins_with("invite_") or event == "report"
		var callback: Callable = show_page.bind(ui, target, event) if reviewed else _act.bind(ui, event, target)
		ui._button("PREP_ACTION_" + event.to_upper(), callback, contents).name = "prep_" + event
	if target == "gate" and "prep:tested" not in Session.gathered:
		var start: Button = ui._button("PREP_ACTION_START", _act.bind(ui, "start", target), contents)
		start.name = "prep_start"
		start.disabled = not ui.world.can_rehearse()
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func settings(ui: Node, parent: Node) -> void:
	for side in ["north", "south"]:
		var label: Label = Text.text(ui, parent, "PREP_SETTING_" + side.to_upper(), 16)
		label.text = ui.tr("PREP_SETTING_" + side.to_upper()) % [Rules.angle(Session.gathered, side) + 1, Rules.target(Session.gathered, side) + 1]
	Text.text(ui, parent, "PREP_SETTING_REASON", 16)
static func _act(ui: Node, event: String, target: String) -> void:
	var success: bool = ui.world.start_preparation() if event == "start" else ui.world.preparation_action(event)
	if success: ui.resume()
	else: show_page(ui, target)
static func journal(ui: Node, parent: Node) -> void:
	if "junction_report" not in Session.opened: return
	ui._label(parent, "PREP_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	Text.text(ui, parent, "PREP_HINT_%d" % Rules.stage(Session.gathered, Session.opened))
	if "prep:accepted" not in Session.gathered: return
	for role in ["witness", "crafter"]:
		Text.text(ui, parent, "PREP_RECRUIT_" + role.to_upper() + ("_DONE" if "prep:consent:" + role in Session.gathered else "_WAIT"), 16)
	settings(ui, parent)
	Text.text(ui, parent, "PREP_RETRY_HELP", 16)
