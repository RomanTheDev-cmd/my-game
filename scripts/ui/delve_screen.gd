extends RefCounted
const Rules = preload("res://scripts/quests/delve_rules.gd")
const Accord = preload("res://scripts/quests/accord_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
# The surveyors' note at each hollow entrance; a different reading for each path of the hero.
static func show_page(ui: Node) -> void:
	ui.current_screen = "dialog"
	ui._page("DELVE_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	var depth := Rules.depth_of(Session.region)
	Text.text(ui, contents, "DELVE_NOTE_TEXT_%d" % maxi(1, depth), 18).name = "delve_note"
	if Session.nature.form != "human": Text.text(ui, contents, "DELVE_SENSE_FORM", 16).name = "delve_sense"
	elif depth == 1: Text.text(ui, contents, "DELVE_SENSE_" + Accord.identity(Session.nature).to_upper(), 16).name = "delve_sense"
	_progress(ui, contents)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _progress(ui: Node, parent: Node) -> void:
	var cleared := Rules.cleared(Session.opened)
	var line: Label = Text.text(ui, parent, "DELVE_PROGRESS", 16)
	line.text = ui.tr("DELVE_PROGRESS") % [cleared, Rules.DEPTHS]
	line.name = "delve_progress"
	Text.text(ui, parent, "DELVE_HINT_%d" % cleared, 16)
static func journal(ui: Node, parent: Node) -> void:
	if Rules.depth_of(Session.region) == 0 and Rules.cleared(Session.opened) == 0 and not Session.defeated.any(func(id): return id.begins_with("hollow_")): return
	ui._label(parent, "DELVE_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	_progress(ui, parent)
