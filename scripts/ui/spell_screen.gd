extends RefCounted
const Magic = preload("res://scripts/magic/magic_rules.gd")
const KEYS := {"heal": "Q", "light": "F", "frost": "G", "aegis": "R"}

static func show_book(ui: Node) -> void:
	ui.current_screen = "spells"
	ui._page("SPELLBOOK", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 270)
	ui.screen.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for id in Magic.SPELLS:
		var button: Button = ui._button("SPELL_" + id.to_upper(), func():
			ui.resume()
			ui.world.player.cast_magic(id), list)
		button.name = "cast_" + id
		button.text += " [%s] · %s %d" % [KEYS[id], ui.tr("MANA_COST"), int(Magic.SPELLS[id].cost)]
		button.disabled = not ui.world.player.can_cast_magic(id)
		var details: Label = ui._label(list, "SPELL_" + id.to_upper() + "_DESC", 14)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.custom_minimum_size.x = 580
		button.focus_entered.connect(scroll.ensure_control_visible.bind(details), CONNECT_DEFERRED)
	ui._button("BACK", ui.resume)
	ui._focus_first()
