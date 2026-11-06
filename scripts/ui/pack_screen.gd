extends RefCounted
const Rules = preload("res://scripts/nature/pack_rules.gd")
static func text(ui: Node, parent: Node, key: String, size: int = 17) -> Label:
	var label: Label = ui._label(parent, key, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 590
	return label
static func hint(nature: Dictionary, flags: Array) -> String:
	if "pack:closed" in flags: return "PACK_HINT_CLOSED"
	if nature.kind == "werewolf" and nature.cure > 0: return "PACK_RETURN_HINT_%d" % int(nature.cure)
	if nature.gift == "wild_master": return "PACK_HINT_MASTER"
	if nature.gift == "wild_scar": return "PACK_HINT_RETURNED"
	return "PACK_HINT_%d" % Rules.stage(flags)
static func show_page(ui: Node, target: String = "tracker", confirm: String = "") -> void:
	ui.current_screen = "nature"
	ui._page("PACK_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		text(ui, contents, "PACK_CONFIRM_" + confirm.to_upper(), 18)
		var accept: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		accept.name = "pack_confirm_" + confirm
		accept.disabled = not ui.world.can_pack(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	text(ui, contents, "PACK_DIALOG_OTHER" if target == "tracker" and not Session.nature.history.is_empty() and Rules.stage(Session.gathered) == 0 else "PACK_DIALOG_" + target.to_upper(), 18)
	text(ui, contents, hint(Session.nature, Session.gathered), 16)
	if Session.nature.kind == "werewolf":
		text(ui, contents, "").text = ui.tr("PACK_RESOLVE") % Session.nature.resolve
	for event in Rules.SITES:
		if Rules.SITES[event][1] != target: continue
		if Rules.resolve(Session.nature, Session.gathered, Session.opened, ui.world.player.mana, event).is_empty(): continue
		var action: Callable = show_page.bind(ui, target, event) if event in ["accept", "decline", "return_finish"] else _act.bind(ui, event, target)
		var button: Button = ui._button("PACK_ACTION_" + event.to_upper(), action, contents)
		button.name = "pack_" + event
		button.disabled = not ui.world.can_pack(event)
	if target == "tracker" and Session.nature.kind == "werewolf":
		ui._button("NATURE_TITLE", ui.show_nature, contents)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.pack_action(event): ui.resume()
	else: show_page(ui, target)
static func journal(ui: Node, contents: Node) -> void:
	if Rules.stage(Session.gathered) == 0: return
	ui._label(contents, "PACK_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	text(ui, contents, hint(Session.nature, Session.gathered), 16)
