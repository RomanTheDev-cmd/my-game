extends RefCounted
const Rules = preload("res://scripts/magic/field_rules.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
static func text(ui: Node, parent: Node, key: String, size: int = 17) -> Label:
	var label: Label = ui._label(parent, key, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 590
	return label
static func show_page(ui: Node, target: String = "host") -> void:
	ui.current_screen = "dialog"
	ui._page("FIELD_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	var stage := Rules.stage(Session.gathered, Session.opened)
	text(ui, contents, "FIELD_DIALOG_HOST_DONE" if target == "host" and stage >= 2 else "FIELD_DIALOG_" + target.to_upper(), 18)
	text(ui, contents, "FIELD_HINT_%d" % stage, 16)
	if target == "host":
		if stage in [0, 2]:
			var event := "accept" if stage == 0 else "report"
			var button: Button = ui._button("FIELD_ACTION_" + event.to_upper(), _act.bind(ui, event, event, target), contents)
			button.name = "field_" + event
			button.disabled = not ui.world.can_field(event, event)
	elif Rules.SPELLS.has(target):
		var progress := Rules.progress(Session.gathered, target)
		text(ui, contents, "").text = ui.tr("FIELD_PROGRESS") % progress
		if progress == 3: text(ui, contents, "FIELD_DONE_" + target.to_upper(), 16)
		if stage == 1 and progress < 3:
			var spell: String = Rules.SPELLS[target]
			var profile := Magic.profile(spell, Session.skills)
			var magic: Button = ui._button("", _act.bind(ui, target, spell, target), contents)
			magic.name = "field_magic"
			magic.text = ui.tr("FIELD_CAST") % [ui.tr("SPELL_" + spell.to_upper()), profile.cost, mini(3 - progress, Rules.power(target, Session.skills))]
			magic.disabled = not ui.world.can_field(target, spell)
			var manual: Button = ui._button("FIELD_MANUAL", _act.bind(ui, target, "manual", target), contents)
			manual.name = "field_manual"
			manual.disabled = not ui.world.can_field(target, "manual")
			text(ui, contents, "FIELD_CONDITIONS", 14)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, id: String, method: String, target: String) -> void:
	if ui.world.field_action(id, method): ui.resume()
	else: show_page(ui, target)
static func entry(ui: Node, parent: Node) -> void:
	if "community_report" in Session.opened:
		ui._button("FIELD_TITLE", show_page.bind(ui, "host"), parent).name = "field_entry"
static func journal(ui: Node, parent: Node) -> void:
	if Rules.START not in Session.gathered: return
	ui._label(parent, "FIELD_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	text(ui, parent, "FIELD_HINT_%d" % Rules.stage(Session.gathered, Session.opened))
	for id in Rules.SPELLS:
		text(ui, parent, "").text = ui.tr("FIELD_SITE_" + id.to_upper()) + " · " + ui.tr("FIELD_PROGRESS") % Rules.progress(Session.gathered, id)
