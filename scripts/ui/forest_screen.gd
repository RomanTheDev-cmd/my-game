extends RefCounted
const Rules = preload("res://scripts/quests/forest_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
static func show_page(ui: Node, target: String = "roadkeeper", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("FOREST_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		Text.text(ui, contents, "FOREST_CONFIRM_" + confirm.to_upper(), 18)
		var button: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		button.name = "forest_confirm_" + confirm
		button.disabled = not ui.world.can_forest(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var stage := Rules.stage(Session.gathered, Session.opened)
	Text.text(ui, contents, "FOREST_DIALOG_%d" % stage, 18)
	Text.text(ui, contents, "FOREST_HINT_READY" if stage == 0 and "story:accepted" in Session.gathered else "FOREST_HINT_%d" % stage)
	if target != "roadkeeper": Text.text(ui, contents, "FOREST_SIGN_" + target)
	if target == "roadkeeper": history(ui, contents)
	if stage == 3:
		Text.text(ui, contents, "FOREST_DONE_COMMONS" if Rules.OUTCOMES[0] in Session.gathered else "FOREST_DONE_WATCH", 17).name = "forest_outcome_memory"
	if stage == 1:
		Text.text(ui, contents, "").text = ui.tr("FOREST_PROGRESS") % [Rules.progress(Session.gathered), 3]
		Text.text(ui, contents, "FOREST_ESCORT_HELP", 15)
	for event in ["accept", "aid_brief", "aid_blood", "work", "howl", "commons", "watch"]:
		if event == "accept" and stage != 0: continue
		if event in ["aid_brief", "aid_blood"] and (stage != 1 or target != "roadkeeper" or Rules.progress(Session.gathered) != 0 or Session.gathered.any(func(flag): return flag in Rules.AIDS)): continue
		if event == "aid_blood" and Session.nature.kind != "vampire": continue
		if event in ["work", "howl"] and stage != 1: continue
		if event == "howl" and Session.nature.kind != "werewolf": continue
		if event in ["commons", "watch"] and (stage != 2 or target != "roadkeeper"): continue
		var review: bool = event in ["aid_blood", "commons", "watch"]
		var action: Callable = show_page.bind(ui, target, event) if review else _act.bind(ui, event, target)
		var button: Button = ui._button("FOREST_ACTION_" + event.to_upper(), action, contents)
		button.name = "forest_" + event
		button.disabled = not ui.world.can_forest(event)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.forest_action(event): ui.resume()
	else: show_page(ui, target)
static func history(ui: Node, parent: Node) -> void:
	if "story_lake_report" not in Session.opened:
		Text.text(ui, parent, "FOREST_LAKE_UNREAD", 16)
		return
	for flag in Session.gathered:
		if flag.begins_with("story:lake:method:"):
			Text.text(ui, parent, "FOREST_LAKE_" + flag.get_slice(":", 3).to_upper(), 16).name = "forest_prior_method"
		if flag.begins_with("story:lake:report:"):
			Text.text(ui, parent, "FOREST_LAKE_" + flag.get_slice(":", 3).to_upper(), 16).name = "forest_prior_report"
static func journal(ui: Node, parent: Node) -> void:
	if "story:accepted" not in Session.gathered: return
	ui._label(parent, "FOREST_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	var stage := Rules.stage(Session.gathered, Session.opened)
	Text.text(ui, parent, "FOREST_HINT_READY" if stage == 0 else "FOREST_HINT_%d" % stage)
	if Rules.stage(Session.gathered, Session.opened) == 1: Text.text(ui, parent, "").text = ui.tr("FOREST_PROGRESS") % [Rules.progress(Session.gathered), 3]
