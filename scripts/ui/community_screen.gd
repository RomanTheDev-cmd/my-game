extends RefCounted
const FieldScreen = preload("res://scripts/ui/field_screen.gd")
const Rules = preload("res://scripts/factions/community_rules.gd")
static func text(ui: Node, parent: Node, key: String, size: int = 17) -> Label:
	var label: Label = ui._label(parent, key, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 590
	return label
static func entry(ui: Node, role: String, parent: Node) -> void:
	if "waterworks_report" not in Session.opened: return
	var guild := Rules.guild(Session.gathered)
	var expected: String = Rules.HOSTS[guild] if guild != "" else {"human": "keeper", "vampire": "wayfarer", "werewolf": "tracker"}[Session.nature.kind]
	if role == expected: ui._button("COMMUNITY_TITLE", show_page.bind(ui, role), parent).name = "community_entry"
static func show_page(ui: Node, target: String = "host", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("COMMUNITY_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		text(ui, contents, "COMMUNITY_CONFIRM_" + confirm.to_upper(), 18)
		var accept: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		accept.name = "community_confirm_" + confirm
		accept.disabled = not ui.world.can_community(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var guild := Rules.guild(Session.gathered)
	if guild != "":
		text(ui, contents, "COMMUNITY_GUILD_" + guild.to_upper(), 21)
		text(ui, contents, "COMMUNITY_STANDING_2" if Rules.stage(Session.gathered) == 4 else "COMMUNITY_STANDING_1", 15)
	var dialog_key := "COMMUNITY_DIALOG_" + target.to_upper()
	if target == "host" and Rules.stage(Session.gathered) >= 3: dialog_key += "_DONE"
	if target == "supply" and Rules.stage(Session.gathered) >= 3: dialog_key += "_DONE"
	text(ui, contents, dialog_key, 18)
	if target == "host" and Rules.stage(Session.gathered) == 4:
		text(ui, contents, "COMMUNITY_RESULT_SHARE" if "community:report:share" in Session.gathered else "COMMUNITY_RESULT_PROVISION", 16)
	text(ui, contents, "COMMUNITY_HINT_%d" % Rules.stage(Session.gathered), 16)
	if target == "host" and Rules.stage(Session.gathered) == 3 and int(Session.inventory.get("coin", 0)) > 987: text(ui, contents, "COMMUNITY_WALLET_FULL", 16)
	for event in Rules.SITES:
		if Rules.SITES[event][1] != target: continue
		var available := Rules.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, Session.gear_owned, Session.world_state.reputation, ui.world.player.mana, event)
		if event.begins_with("join_") and available.is_empty(): continue
		if event.begins_with("seen_") and Rules.stage(Session.gathered) != 1: continue
		if event.begins_with("aid_") and Rules.stage(Session.gathered) != 2: continue
		if event == "aid_blood" and Session.nature.kind != "vampire": continue
		if event.begins_with("report_") and Rules.stage(Session.gathered) != 3: continue
		var reviewed: bool = event.begins_with("join_") or event.begins_with("report_") or event == "aid_blood"
		var button: Button = ui._button("COMMUNITY_ACTION_" + event.to_upper(), show_page.bind(ui, target, event) if reviewed else _act.bind(ui, event, target), contents)
		button.name = "community_" + event
		button.disabled = not ui.world.can_community(event)
	if target == "host": FieldScreen.entry(ui, contents)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.community_action(event): ui.resume()
	else: show_page(ui, target)
static func journal(ui: Node, parent: Node) -> void:
	if Rules.guild(Session.gathered) == "": return
	ui._label(parent, "COMMUNITY_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	text(ui, parent, "COMMUNITY_GUILD_" + Rules.guild(Session.gathered).to_upper())
	text(ui, parent, "COMMUNITY_HINT_%d" % Rules.stage(Session.gathered))
