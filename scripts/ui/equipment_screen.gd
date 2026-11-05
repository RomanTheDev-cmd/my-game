extends RefCounted
const Gear = preload("res://scripts/items/equipment_rules.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")

static func content(ui: Node, height: float = 280) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, height)
	ui.screen.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return box

static func equipment(ui: Node) -> void:
	ui.current_screen = "equipment"
	ui._page("EQUIPMENT", 620)
	var summary: Label = ui._label(ui.screen, "", 15)
	summary.text = "%s: %d · %s: %d%% · %s: %d%%" % [ui.tr("DAMAGE"), Gear.weapon(Session.equipped).damage + 4 * int(Session.skills.get("sword", 0)), ui.tr("ARMOR_PROTECTION"), Gear.reduction(Session.equipped) * 100, ui.tr("BLOCK_PROTECTION"), (1.0 - Gear.block(Session.equipped)) * 100]
	var box := content(ui, 250)
	for slot in ["weapon", "armor", "shield"]:
		var id: String = Session.equipped[slot]
		ui._label(box, "").text = "%s: %s" % [ui.tr("SLOT_" + slot.to_upper()), ui.tr(id.to_upper()) if id != "" else ui.tr("NOT_EQUIPPED")]
	for id in Session.gear_owned:
		var definition: Dictionary = Gear.ITEMS[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		ui._label(details, id.to_upper(), 16)
		var description: Label = ui._label(details, id.to_upper() + "_DESC", 12)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = 380
		var worn: bool = id in Session.equipped.values()
		var action: Button = ui._button("UNEQUIP" if worn else "EQUIP", _equip.bind(ui, id, worn), row)
		action.name = "equip_" + id
		action.custom_minimum_size.x = 130
		action.disabled = not worn and Gear.equip(id, Session.gear_owned, Session.equipped).is_empty()
	ui._button("BACK", ui.resume)
	ui._focus_first()

static func _equip(ui: Node, id: String, worn: bool) -> void:
	if worn:
		Session.unequip_slot(Gear.ITEMS[id].slot)
	else:
		Session.equip_item(id)
	if ui.world.safe_to_rest():
		ui.world.save_safe()
	equipment(ui)

static func shop(ui: Node, selling: bool = false) -> void:
	ui.current_screen = "shop"
	ui._page("MERCHANT_NAME", 620)
	var purse: Label = ui._label(ui.screen, "", 17)
	purse.text = "%s: %d" % [ui.tr("COIN"), int(Session.inventory.get("coin", 0))]
	var tabs := HBoxContainer.new()
	ui.screen.add_child(tabs)
	var buy_tab: Button = ui._button("BUY_MODE", shop.bind(ui, false), tabs)
	var sell_tab: Button = ui._button("SELL_MODE", shop.bind(ui, true), tabs)
	for tab in [buy_tab, sell_tab]:
		tab.toggle_mode = true
		tab.add_theme_stylebox_override("pressed", ui.screen.get_theme_stylebox("hover", "Button"))
	buy_tab.button_pressed = not selling
	sell_tab.button_pressed = selling
	if selling:
		ui._label(ui.screen, "SELL_EQUIPPED_HINT", 12)
	var box := content(ui, 220 if selling else 240)
	for id in Trade.stock():
		var definition: Dictionary = Gear.ITEMS.get(id, Trade.CONSUMABLES.get(id, {}))
		if selling and id not in Session.gear_owned and int(Session.inventory.get(id, 0)) < 1:
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var label: Label = ui._label(details, "", 16)
		label.text = "%s · %d" % [ui.tr(id.to_upper()), definition.sell if selling else definition.price]
		var description: Label = ui._label(details, id.to_upper() + "_DESC", 12)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = 380
		var button: Button = ui._button("SELL" if selling else "BUY", _trade.bind(ui, id, selling), row)
		button.name = "trade_" + id
		button.custom_minimum_size.x = 130
		var result := Trade.sell(id, Session.inventory, Session.gear_owned, Session.equipped) if selling else Trade.buy(id, Session.inventory, Session.gear_owned)
		button.disabled = result.is_empty()
	ui._button("BACK", ui.resume)
	(sell_tab if selling else buy_tab).grab_focus()

static func _trade(ui: Node, id: String, selling: bool) -> void:
	ui.world.trade(id, selling)
	shop(ui, selling)
