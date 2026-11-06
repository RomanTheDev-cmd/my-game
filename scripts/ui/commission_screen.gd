extends RefCounted
const Items = preload("res://scripts/items/inventory_rules.gd")
const Rules = preload("res://scripts/quests/commission_rules.gd")
const Factions = preload("res://scripts/factions/faction_rules.gd")
const EquipmentScreen = preload("res://scripts/ui/equipment_screen.gd")

static func show_dialog(ui: Node, target: String) -> void:
	var state: Dictionary = Session.world_state.commission
	ui.current_screen = "dialog"
	var names := {"keeper": "KEEPER_NAME", "warden": "WARDEN_NAME", "wright": "WRIGHT_NAME", "tender": "TENDER_NAME"}
	ui._page(names.get(target, "COMMISSION_" + target.to_upper()), 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var text: Label = ui._label(content, "COMM_" + target.to_upper() + "_" + str(int(state.stage)), 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 590
	if target == "keeper" and state.stage == 5 and int(Session.inventory.get("coin", 0)) + Rules.REWARD_COINS > 999:
		var capacity: Label = ui._label(content, "", 15)
		capacity.text = ui.tr("COMMISSION_REWARD_FULL") % Rules.REWARD_COINS
		capacity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if state.stage >= 5 and target in ["warden", "tender"]:
		var reaction: Label = ui._label(content, "COMM_REACTION_" + target.to_upper() + "_" + state.settlement.to_upper(), 16)
		reaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for event in Rules.choices(state, target, Session.region):
		var action: Button = ui._button("COMM_ACTION_" + event.to_upper(), _act.bind(ui, event, target), content)
		action.name = "commission_" + event
		action.disabled = not ui.world.can_commission(event)
	if target == "wright" and state.stage == 6:
		ui._button("TRIAL_TITLE", ui.show_trial.bind("wright"), content).name = "trial_assignment"
	if target == "warden" and "pack:invited" in Session.gathered:
		ui._button("PACK_TITLE", ui.show_pack.bind("warden"), content).name = "pack_warden"
	if target == "warden":
		var help: Label = ui._label(content, "WARDEN_TRADE_HELP", 14)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var shop: Button = ui._button("WARDEN_TRADE", EquipmentScreen.shop.bind(ui), content)
		shop.name = "warden_shop"
		shop.disabled = not Factions.trusted(Session.world_state.reputation, "wardens")
	if target == "tender" and (Session.nature.stage in [1, 2] or Session.nature.cure in [1, 2]):
		ui._button("NATURE_TITLE", ui.show_nature.bind("tender"), content).name = "nature_garden"
	if target == "tender":
		var cost := Items.TENDER_HERBS
		var help: Label = ui._label(content, "TENDER_BREW_HELP", 14)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var brew: Button = ui._button("TENDER_BREW", _brew.bind(ui), content)
		brew.text = ui.tr("TENDER_BREW") % cost
		brew.name = "tender_brew"
		brew.disabled = not ui.world.can_brew_with_tender()
	ui._button("BACK", ui.resume)
	ui._focus_first()

static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.commission_action(event):
		ui.resume()
	else:
		show_dialog(ui, target)

static func _brew(ui: Node) -> void:
	ui.world.brew_with_tender()
	show_dialog(ui, "tender")

static func journal(ui: Node, contents: Node) -> void:
	var state: Dictionary = Session.world_state.commission
	if state.stage > 0:
		ui._label(contents, "COMMISSION_TITLE", 23).add_theme_color_override("font_color", ui.gold)
		var task: Label = ui._label(contents, "COMMISSION_JOURNAL_" + str(int(state.stage)), 17)
		task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if state.stage in [1, 2]:
			ui._label(contents, "").text = ui.tr("COMMISSION_PROGRESS") % [state.survey.size(), state.heard.size()]
	ui._label(contents, "RELATIONSHIPS", 23).add_theme_color_override("font_color", ui.gold)
	for group in Factions.GROUPS:
		ui._label(contents, "", 16).text = "%s: %d" % [ui.tr("FACTION_" + group.to_upper()), int(Session.world_state.reputation[group])]
