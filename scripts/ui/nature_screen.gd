extends RefCounted
const Rules = preload("res://scripts/nature/nature_rules.gd")
static func _text(ui: Node, parent: Node, key: String, size: int = 17) -> Label:
	var text: Label = ui._label(parent, key, size)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 590
	return text
static func show_page(ui: Node, target: String = "status", confirm: String = "") -> void:
	ui.current_screen = "nature"
	ui._page("NATURE_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	var state: Dictionary = Session.nature
	if confirm != "":
		_text(ui, contents, "NATURE_CONFIRM_" + confirm.to_upper(), 18)
		var accept: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		accept.name = "nature_confirm_" + confirm
		accept.disabled = not ui.world.can_nature(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	_text(ui, contents, "NATURE_KIND_" + state.kind.to_upper(), 23).add_theme_color_override("font_color", ui.gold)
	if state.kind == "vampire":
		_text(ui, contents, "").text = ui.tr("NATURE_BLOOD") % state.blood
	_text(ui, contents, "NATURE_GIFT_" + (state.gift.to_upper() if state.gift != "" else "NONE"), 16)
	if target == "status":
		_text(ui, contents, "NATURE_STATUS_" + state.kind.to_upper(), 16)
		if state.gift != "":
			var power: Button = ui._button("NATURE_POWER", _power.bind(ui), contents)
			power.name = "nature_power"
			power.disabled = not ui.world.player.can_nature_power()
		if state.kind == "vampire":
			var shift: Button = ui._button("NATURE_SHIFT", _shift.bind(ui), contents)
			shift.name = "nature_shift"
			shift.disabled = Rules.shift(state).is_empty()
	else:
		_text(ui, contents, "NATURE_DIALOG_" + target.to_upper(), 18)
		_text(ui, contents, hint(state), 16)
		for event in Rules.SITES:
			if Rules.SITES[event][1] != target: continue
			if event == "invite" and state.stage != 0: continue
			if event in ["human", "vampire"] and state.stage != 2: continue
			if event in ["water", "garden"] and state.stage != 1: continue
			if event == "supply" and state.kind != "vampire": continue
			if event == "cure_start" and (state.kind != "vampire" or state.cure != 0): continue
			if event in ["release_water", "release_garden"] and state.cure != 1: continue
			if event == "cure_finish" and (state.kind != "vampire" or state.cure != 2): continue
			var action: Callable = show_page.bind(ui, target, event) if event in ["human", "vampire", "cure_finish"] else _act.bind(ui, event, target)
			var button: Button = ui._button("NATURE_ACTION_" + event.to_upper(), action, contents)
			button.name = "nature_" + event
			button.disabled = not ui.world.can_nature(event)
	var back: Button = ui._button("BACK", ui.resume)
	if target == "status": back.grab_focus()
	else: ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.nature_action(event): ui.resume()
	else: show_page(ui, target)
static func _power(ui: Node) -> void:
	ui.resume()
	ui.world.player.use_nature_power()
static func _shift(ui: Node) -> void:
	ui.world.player.shift_form()
	show_page(ui)
static func journal(ui: Node, contents: Node) -> void:
	if Session.nature.stage == 0: return
	ui._label(contents, "NATURE_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	_text(ui, contents, hint(Session.nature), 16)

static func hint(state: Dictionary) -> String:
	if state.kind == "vampire" and state.cure > 0: return "NATURE_CURE_HINT_%d" % int(state.cure)
	if state.kind == "human" and state.stage == 3: return "NATURE_HINT_HUMAN_3"
	return "NATURE_HINT_%d" % int(state.stage)
