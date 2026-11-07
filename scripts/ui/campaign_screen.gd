extends RefCounted
const Rules = preload("res://scripts/quests/campaign_rules.gd")
static func text(ui: Node, parent: Node, key: String, size: int = 17) -> Label:
	var label: Label = ui._label(parent, key, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 590
	return label
static func show_page(ui: Node, target: String = "mentor", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("STORY_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		text(ui, contents, "STORY_CONFIRM_" + confirm.to_upper(), 18)
		var accept: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		accept.name = "story_confirm_" + confirm
		accept.disabled = not ui.world.can_campaign(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var stage := Rules.stage(Session.gathered, Session.opened)
	var dialog_key := "STORY_DIALOG_" + target.to_upper()
	if target == "mentor" and stage > 0:
		dialog_key = "STORY_DIALOG_MENTOR_DONE" if stage == 5 else ("STORY_DIALOG_MENTOR_REPORT" if stage == 4 else "STORY_DIALOG_MENTOR_MET")
	text(ui, contents, dialog_key, 18)
	text(ui, contents, "STORY_HINT_%d" % stage, 16)
	if target == "mentor" and "story:accepted" in Session.gathered:
		text(ui, contents, "FOREST_MENTOR_DONE" if "forest_report" in Session.opened else "FOREST_MENTOR_NEXT", 16)
		if "forest_report" in Session.opened:
			text(ui, contents, "FOREST_MENTOR_COMMONS" if "forest:outcome:commons" in Session.gathered else "FOREST_MENTOR_WATCH", 16)
	if target == "control":
		var settings := Rules.positions(Session.gathered)
		text(ui, contents, "").text = ui.tr("STORY_SETTINGS") % settings
	if target == "mentor" and stage == 4 and int(Session.inventory.get("coin", 0)) > 987: text(ui, contents, "STORY_WALLET_FULL", 15)
	for event in Rules.SITES:
		if Rules.SITES[event][1] != target: continue
		var available := Rules.resolve(Session.nature, Session.quest, Session.gathered, Session.opened, Session.inventory, ui.world.player_vitals(), event)
		if event in ["greet", "accept", "hear", "inspect", "consent"] and available.is_empty(): continue
		if event.begins_with("turn_") and stage != 3: continue
		if event in ["manual", "blood", "scent"] and stage != 3: continue
		if event == "blood" and Session.nature.kind != "vampire": continue
		if event == "scent" and Session.nature.kind != "werewolf": continue
		if event.begins_with("report_") and stage != 4: continue
		var reviewed: bool = event == "blood" or event.begins_with("report_")
		var action: Callable = show_page.bind(ui, target, event) if reviewed else _act.bind(ui, event, target)
		var button: Button = ui._button("STORY_ACTION_" + event.to_upper(), action, contents)
		button.name = "story_" + event
		button.disabled = not ui.world.can_campaign(event)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.campaign_action(event):
		if event.begins_with("turn_"):
			show_page(ui, target)
			var selected: Button = ui.screen.find_child("story_" + event, true, false)
			if selected != null and not selected.disabled:
				selected.grab_focus()
				ui._reveal_focus(selected)
		else: ui.resume()
	else: show_page(ui, target)
static func journal(ui: Node, parent: Node) -> void:
	if "story:met" not in Session.gathered: return
	ui._label(parent, "STORY_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	text(ui, parent, "STORY_HINT_%d" % Rules.stage(Session.gathered, Session.opened))
static func entry(ui: Node, parent: Node) -> void:
	if Session.quest == 3: ui._button("STORY_TITLE", show_page.bind(ui, "overview"), parent).name = "story_entry"
