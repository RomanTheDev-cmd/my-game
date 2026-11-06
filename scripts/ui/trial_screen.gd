extends RefCounted
const Rules = preload("res://scripts/quests/trial_rules.gd")
static func show_dialog(ui: Node, target: String) -> void:
	var stage := Rules.stage(Session.gathered, Session.defeated, Session.opened)
	ui.current_screen = "dialog"
	ui._page("TRIAL_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 285)
	scroll.follow_focus = true
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	var text: Label = ui._label(contents, "TRIAL_DIALOG_" + target.to_upper(), 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 590
	var status: Label = ui._label(contents, "TRIAL_HINT_%d" % stage, 16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if target == "wright" and stage == 4 and int(Session.inventory.get("coin", 0)) > 999 - Rules.COINS:
		var capacity: Label = ui._label(contents, "", 15)
		capacity.text = ui.tr("COMMISSION_REWARD_FULL") % Rules.COINS
		capacity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for event in ["accept", "north", "south", "awaken", "report"]:
		if Rules.SITES[event][1] != target: continue
		if event == "accept" and stage != 0: continue
		if event == "report" and stage != 4: continue
		var button: Button = ui._button("TRIAL_ACTION_" + event.to_upper(), _act.bind(ui, event, target), contents)
		button.name = "trial_" + event
		button.disabled = not ui.world.can_trial(event)
	if target == "altar" and (Session.nature.stage in [1, 2] or Session.nature.cure in [1, 2]):
		ui._button("NATURE_TITLE", ui.show_nature.bind("altar"), contents).name = "nature_water"
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.trial_action(event): ui.resume()
	else: show_dialog(ui, target)
static func journal(ui: Node, contents: Node) -> void:
	var stage := Rules.stage(Session.gathered, Session.defeated, Session.opened)
	if stage == 0: return
	ui._label(contents, "TRIAL_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	var task: Label = ui._label(contents, "TRIAL_HINT_%d" % stage, 17)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
