extends Node
const DialogueRules = preload("res://scripts/nature/dialogue_rules.gd")
const DialogueScreen = preload("res://scripts/ui/dialogue_screen.gd")
const Pack = preload("res://scripts/nature/pack_rules.gd")
const PackScreen = preload("res://scripts/ui/pack_screen.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const NatureScreen = preload("res://scripts/ui/nature_screen.gd")
const Trial = preload("res://scripts/quests/trial_rules.gd")
const TrialScreen = preload("res://scripts/ui/trial_screen.gd")
const CommissionScreen = preload("res://scripts/ui/commission_screen.gd")
const World = preload("res://scripts/world/world.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const EncounterRules = preload("res://scripts/world/living/encounter_rules.gd")
const SpellScreen = preload("res://scripts/ui/spell_screen.gd")
const EquipmentScreen = preload("res://scripts/ui/equipment_screen.gd")
const Skills = preload("res://scripts/progression/skill_rules.gd")
const MapView = preload("res://scripts/ui/world_map.gd")
const Store = preload("res://scripts/systems/save_store.gd")
var world: Node2D
var layer: CanvasLayer
var hud: Control
var overlay: Control
var screen: VBoxContainer
var toast: Label
var toast_time := 0.0
var nature_label: Label
var human_label: Label
var shield_label: Label
var boss_panel: VBoxContainer
var boss_title: Label
var boss_bar: ProgressBar
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var mana_bar: ProgressBar
var location_label: Label
var region_label: Label
var quest_label: Label
var prompt: Label
var current_screen := "title"
var text_color := Color("e9e1ce")
var gold := Color("d8ba7c")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_build_theme()
	Session.fresh()
	Session.running = false
	_build_world()
	_build_hud()
	Session.notice.connect(show_notice)
	Session.changed.connect(update_hud)
	show_title()

func _build_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 17
	if ResourceLoader.exists("res://assets/fonts/DejaVuSerif.ttf"):
		theme.default_font = load("res://assets/fonts/DejaVuSerif.ttf")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("253b3d") if state in ["hover", "focus"] else Color("172829")
		style.border_color = gold if state in ["hover", "focus"] else Color("596156")
		style.set_border_width_all(1)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		theme.set_stylebox(state, "Button", style)
		theme.set_color("font_color", "Button", text_color)
		theme.set_color("font_hover_color", "Button", Color("fff1d0"))
		theme.set_color("font_disabled_color", "Button", Color("808d80"))
	theme.set_color("font_color", "Label", text_color)
	layer = CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -350
	toast.offset_right = 350
	toast.offset_top = -52
	toast.offset_bottom = -6
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_color_override("font_color", gold)
	toast.add_theme_color_override("font_shadow_color", Color("122021"))
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)

func _build_world() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)
	world.dialog_requested.connect(show_dialog)
	world.player_died.connect(show_death)
	world.travel_requested.connect(_on_travel)

func _label(parent: Node, key: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(key: String, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(280, 44)
	button.pressed.connect(func(): Sound.play_ui())
	button.pressed.connect(action)
	(parent if parent != null else screen).add_child(button)
	return button

func _page(key: String, width: float = 420) -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	get_tree().paused = true
	_position_toast(true)
	overlay.show()
	hud.visible = Session.running
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.08, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 8
	center.offset_bottom = -64
	overlay.add_child(center)
	screen = VBoxContainer.new()
	screen.custom_minimum_size.x = width
	screen.add_theme_constant_override("separation", 10)
	center.add_child(screen)
	var title := _label(screen, key, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", gold)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	screen.add_child(spacer)

func _focus_first() -> void:
	for child in screen.find_children("*", "Button", true, false):
		if not child.disabled:
			child.grab_focus()
			break

func show_title() -> void:
	Session.running = false
	current_screen = "title"
	_page("TITLE")
	var subtitle := _label(screen, "SUBTITLE", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("CONTINUE", load_game).disabled = Store.load_game().is_empty()
	_button("NEW_GAME", confirm_new)
	_button("SETTINGS", show_settings)
	_button("QUIT", _quit_game)
	var stage := _label(screen, "EARLY_BUILD", 13)
	stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_first()

func confirm_new() -> void:
	if Store.load_game().is_empty():
		new_game()
		return
	current_screen = "confirm"
	_page("NEW_GAME", 520)
	var warning := _label(screen, "RESTART_WARNING")
	warning.custom_minimum_size.x = 520
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("CONFIRM_NEW", new_game)
	_button("CANCEL", show_title)
	_focus_first()

func new_game() -> void:
	Session.fresh()
	_build_world()
	resume()

func load_game() -> void:
	if Session.load_saved():
		_build_world()
		resume()

func resume() -> void:
	current_screen = "game"
	overlay.hide()
	_position_toast(false)
	hud.show()
	get_tree().paused = false
	update_hud()

func show_pause() -> void:
	current_screen = "pause"
	_page("PAUSED", 600)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	screen.add_child(grid)
	for entry in [["NATURE_TITLE", show_nature], ["RESUME", resume], ["MAP", show_map], ["SPELLBOOK", show_spells], ["SKILLS", show_skills], ["EQUIPMENT", show_equipment],
		["WAIT", show_wait], ["SAVE", world.save_safe], ["LOAD", load_game], ["SETTINGS", show_settings], ["MAIN_MENU", show_title]]:
		var action := _button(entry[0], entry[1], grid)
		if entry[0] == "WAIT":
			action.disabled = not world.can_wait()
	_focus_first()

func show_settings() -> void:
	current_screen = "settings"
	_page("SETTINGS", 600)
	_label(screen, "DIFFICULTY")
	var choice := OptionButton.new()
	for key in ["STORY", "ADVENTURE", "CHALLENGE"]:
		choice.add_item(tr(key))
	choice.select(Session.difficulty)
	choice.item_selected.connect(func(index):
		if not Session.set_difficulty(index):
			choice.select(Session.difficulty))
	screen.add_child(choice)
	var fullscreen := CheckButton.new()
	fullscreen.text = tr("FULLSCREEN")
	fullscreen.button_pressed = Session.fullscreen
	fullscreen.toggled.connect(func(enabled):
		if not Session.set_fullscreen(enabled):
			fullscreen.set_pressed_no_signal(Session.fullscreen))
	screen.add_child(fullscreen)
	for channel in ["master", "effects", "ambience"]:
		_volume_slider(channel)
	_button("BACK", show_pause if Session.running else show_title)
	choice.grab_focus()

func _volume_slider(channel: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	screen.add_child(row)
	var label := _label(row, "VOLUME_" + channel.to_upper(), 16)
	label.custom_minimum_size.x = 220
	var slider := HSlider.new()
	slider.name = "volume_" + channel
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = Session.audio[channel]
	slider.custom_minimum_size = Vector2(230, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = label.text
	row.add_child(slider)
	var amount := _label(row, "", 15)
	amount.custom_minimum_size.x = 50
	amount.text = "%d%%" % roundi(slider.value * 100)
	slider.value_changed.connect(func(value):
		if not Session.set_volume(channel, value):
			slider.set_value_no_signal(Session.audio[channel])
		amount.text = "%d%%" % roundi(slider.value * 100))

func show_journal() -> void:
	current_screen = "journal"
	_page("JOURNAL", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 290)
	screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	var task := _label(contents, "QUEST_%d" % Session.quest, 18)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Session.aid_quest > 0:
		var side := _label(contents, "AID_QUEST_%d" % Session.aid_quest, 18)
		side.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PackScreen.journal(self, contents)
	NatureScreen.journal(self, contents)
	TrialScreen.journal(self, contents)
	CommissionScreen.journal(self, contents)
	_label(contents, "INVENTORY", 23).add_theme_color_override("font_color", gold)
	var entries := 0
	for item in Session.inventory:
		var amount := int(Session.inventory[item])
		if amount > 0:
			_label(contents, "").text = "%s × %d" % [tr(str(item).to_upper()), amount]
			entries += 1
	if entries == 0:
		_label(contents, "EMPTY")
	_button("CRAFT_POTION", func():
		Session.craft_item("potion")
		show_journal(), contents).disabled = int(Session.inventory.get("herb", 0)) < 3
	_button("DRINK_POTION", func():
		world.player.drink_potion()
		show_journal(), contents).disabled = int(Session.inventory.get("potion", 0)) < 1 or world.player.health >= 100
	_button("BACK", resume).grab_focus()

func show_dialog(kind: String = "keeper", bypass_reaction: bool = false) -> void:
	var role := kind.trim_prefix("commission:").trim_prefix("reaction:")
	if kind == "merchant_closed": role = "merchant"
	if not bypass_reaction and DialogueRules.GROUPS.has(role) and DialogueRules.context(Session.nature) != "":
		DialogueScreen.show_page(self, role, kind if not kind.begins_with("reaction:") else "")
		return
	if kind == "tracker" or kind.begins_with("pack:"):
		show_pack("tracker" if kind == "tracker" else kind.trim_prefix("pack:"))
		return
	if kind.begins_with("trial:"):
		show_trial(kind.trim_prefix("trial:"))
		return
	if kind.begins_with("commission:"):
		show_commission(kind.trim_prefix("commission:"))
		return
	if kind == "merchant_closed":
		current_screen = "dialog"
		_page("MERCHANT_CLOSED", 580)
		_label(screen, "SHOP_HOURS", 17)
		_button("BACK", resume)
		_focus_first()
		return
	if kind == "encounter":
		show_encounter()
		return
	if kind == "merchant":
		EquipmentScreen.shop(self)
		return
	if kind == "wayfarer":
		show_aid_dialog()
		return
	current_screen = "dialog"
	_page("KEEPER_NAME", 580)
	var dialog := _label(screen, "DIALOG_%d" % Session.quest, 21)
	dialog.custom_minimum_size.x = 580
	dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Session.quest == 0:
		_button("ACCEPT", func():
			Session.advance_quest("accept")
			world.save_safe()
			resume())
	elif Session.quest == 2:
		_button("GIVE_LANTERN", func():
			Session.advance_quest("turn_in")
			world.save_safe()
			show_dialog())
	if Session.quest == 3:
		_button("COMMISSION_TITLE", show_commission.bind("keeper"))
	if Session.nature.kind == "vampire" or "vampire" in Session.nature.history:
		_button("NATURE_CURE_TITLE", show_nature.bind("keeper")).name = "nature_keeper"
	if "werewolf" in Session.nature.history:
		_button("PACK_TITLE", show_pack.bind("keeper")).name = "pack_keeper"
	_button("LATER" if Session.quest == 0 else "CLOSE", resume)
	_focus_first()

func show_death() -> void:
	current_screen = "death"
	_page("DEATH_TITLE", 520)
	_label(screen, "DEATH")
	_button("RETRY", func():
		Session.restore_checkpoint()
		_build_world()
		resume())
	_focus_first()

func _build_hud() -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_top", 18)
	top.add_theme_constant_override("margin_right", 24)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 220
	row.add_child(stats)
	human_label = _label(stats, "HUMAN", 14)
	nature_label = _label(stats, "", 11)
	health_bar = _bar(stats, Color("b3665a"))
	stamina_bar = _bar(stats, Color("aeab70"))
	mana_bar = _bar(stats, Color("7ca3b1"))
	shield_label = _label(stats, "", 12)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(space)
	var location := VBoxContainer.new()
	row.add_child(location)
	location_label = _label(location, "LOCATION", 25)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	region_label = _label(location, "REGION", 13)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_panel = VBoxContainer.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -170
	boss_panel.offset_right = 170
	boss_panel.offset_top = 80
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_panel)
	boss_title = _label(boss_panel, "TRIAL_BOSS", 15)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = _bar(boss_panel, Color("c09b69"))
	boss_panel.hide()
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -145
	bottom.offset_bottom = -12
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	prompt = _label(bottom, "", 18)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", gold)
	quest_label = _label(bottom, "QUEST_0", 16)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.add_theme_color_override("font_shadow_color", Color("14292a"))
	quest_label.add_theme_constant_override("shadow_offset_x", 2)
	quest_label.add_theme_constant_override("shadow_offset_y", 2)
	_label(bottom, "CONTROLS", 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(bottom, "SAVE_HINT", 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 9)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("172d30")
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func update_hud() -> void:
	if not is_instance_valid(world) or health_bar == null:
		return
	human_label.text = "%s · %s %d" % [tr("NATURE_KIND_" + Session.nature.kind.to_upper()), tr("LEVEL"), Skills.level(Session.xp)]
	nature_label.text = tr("NATURE_BLOOD") % Session.nature.blood + " · U / V / N" if Session.nature.kind == "vampire" else (tr("NATURE_KEYS") if Session.nature.gift != "" else "")
	if Session.nature.kind == "werewolf": nature_label.text = tr("PACK_RESOLVE") % Session.nature.resolve + " · U/Y/V/N"
	location_label.text = tr(world.definition.location)
	var minutes: float = Session.world_state.minutes
	var weather := Clock.weather(minutes, int(Session.world_state.seed))
	region_label.text = "%s · %s %d · %s" % [tr(world.definition.description), tr("DAY"), floori(minutes / 1440) + 1, Clock.time_text(minutes)]
	if not world.definition.get("indoor", false):
		region_label.text += " · " + tr("WEATHER_" + weather.to_upper())
	shield_label.text = tr("AEGIS_STATUS") % [roundi(world.player.shield_strength), world.player.shield_time] if world.player.shield_time > 0 and world.player.shield_strength > 0 else ""
	health_bar.value = world.player.health
	stamina_bar.value = world.player.stamina
	mana_bar.value = world.player.mana
	health_bar.tooltip_text = "%s: %d/100" % [tr("HP"), int(world.player.health)]
	stamina_bar.tooltip_text = "%s: %d/100" % [tr("STAMINA"), int(world.player.stamina)]
	mana_bar.tooltip_text = "%s: %d/100" % [tr("MANA"), int(world.player.mana)]
	boss_panel.visible = is_instance_valid(world.boss) and world.boss.armed and world.boss.position.distance_to(world.player.position) < 620
	if boss_panel.visible:
		boss_bar.value = 100.0 * world.boss.health / world.boss.max_health
		boss_title.text = tr("TRIAL_RECORD" if world.boss.awaiting_record else "TRIAL_BOSS_PHASE_%d" % world.boss.phase)
	var commission_stage := int(Session.world_state.commission.stage)
	if commission_stage > 0 and (commission_stage < 6 or Session.aid_quest != 1):
		quest_label.text = tr("COMMISSION_HINT_%d" % commission_stage)
	else:
		quest_label.text = tr("AID_QUEST_1") if Session.aid_quest == 1 else tr("QUEST_%d" % Session.quest)
	var trial_stage := Trial.stage(Session.gathered, Session.defeated, Session.opened)
	if trial_stage > 0 and trial_stage < 5:
		quest_label.text = tr("TRIAL_HINT_%d" % trial_stage)
	if Session.nature.stage in [1, 2] or (Session.nature.kind == "vampire" and Session.nature.cure in [1, 2]):
		quest_label.text = tr(NatureScreen.hint(Session.nature))
	if Pack.stage(Session.gathered) in [1, 2] or (Session.nature.kind == "werewolf" and (Session.nature.cure > 0 or Session.nature.gift == "wild")):
		quest_label.text = tr(PackScreen.hint(Session.nature, Session.gathered))
	if is_instance_valid(world.boss) and world.boss.awaiting_record:
		quest_label.text = tr("TRIAL_RECORD_HELP")
	var near: String = world.nearby_key()
	prompt.text = tr("INTERACT") + " · " + tr(near) if near != "" else ""

func show_notice(key: String) -> void:
	toast.text = tr(key)
	toast_time = 4
	toast.show()

func _process(delta: float) -> void:
	if current_screen == "game":
		update_hud()
	toast_time = maxf(0, toast_time - delta)
	toast.visible = toast_time > 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if current_screen == "game":
			show_pause()
		elif current_screen in ["pause", "dialog", "journal", "settings", "map", "skills", "equipment", "shop", "wait", "spells", "nature"] and Session.running:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("nature_book") and current_screen in ["game", "nature"]:
		if current_screen == "game": show_nature()
		else: resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spellbook") and current_screen in ["game", "spells"]:
		if current_screen == "game":
			show_spells()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("wait") and current_screen == "game":
		show_wait()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("equipment") and current_screen in ["game", "equipment"]:
		if current_screen == "game":
			show_equipment()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skills") and current_screen in ["game", "skills"]:
		if current_screen == "game":
			show_skills()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and current_screen in ["game", "map"]:
		if current_screen == "game":
			show_map()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and current_screen in ["game", "journal"]:
		if current_screen == "game":
			show_journal()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load_game") and current_screen == "game":
		load_game()
		get_viewport().set_input_as_handled()

func _on_travel(destination: String, position: Vector2) -> void:
	if current_screen != "game" or not world.safe_to_rest():
		Session.notice.emit("CHECKPOINT_UNSAFE")
		return
	if Session.travel(destination, position, world.player_vitals()):
		# Do not free the source world inside its own interaction callback.
		call_deferred("_finish_travel")

func _finish_travel() -> void:
	_build_world()
	resume()
	Session.notice.emit("TRAVEL_SAVED")

func show_map() -> void:
	current_screen = "map"
	_page("MAP", 700)
	var name_label := _label(screen, world.definition.location, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map := MapView.new()
	map.name = "WorldMap"
	map.region = Session.region
	map.player_position = world.player.position
	map.facing = world.player.facing
	map.obstacles = world.navigation.obstacles
	for npc in world.npcs.values():
		if npc.visible:
			map.npcs[npc.kind] = npc.position
	screen.add_child(map)
	var legend := _label(screen, "MAP_LEGEND", 13)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("BACK", resume)
	_focus_first()

func show_skills() -> void:
	current_screen = "skills"
	_page("SKILLS", 620)
	var summary := _label(screen, "", 16)
	summary.text = "%s %d · %s: %d · %s: %d" % [tr("LEVEL"), Skills.level(Session.xp), tr("EXPERIENCE"), Session.xp, tr("SKILL_POINTS"), Skills.points(Session.xp, Session.skills)]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for id in Skills.SKILLS:
		var definition: Dictionary = Skills.SKILLS[id]
		var button := _button(definition.name, _learn_skill.bind(id))
		button.text += "  %d/%d" % [int(Session.skills.get(id, 0)), definition.max]
		button.tooltip_text = tr(definition.description)
		button.disabled = Skills.learn(Session.xp, Session.skills, id).is_empty()
		var description := _label(screen, definition.description, 13)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = 620
	_button("BACK", resume)
	_focus_first()

func _learn_skill(id: String) -> void:
	Session.learn_skill(id)
	show_skills()

func show_aid_dialog() -> void:
	current_screen = "dialog"
	_page("AID_NAME", 620)
	var dialog := _label(screen, "AID_DIALOG_%d" % Session.aid_quest, 19)
	dialog.custom_minimum_size.x = 620
	dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Session.aid_quest == 0:
		_button("AID_ACCEPT", _aid_action.bind("accept"))
	elif Session.aid_quest == 1:
		_button("AID_HERBS", _aid_action.bind("herbs")).disabled = int(Session.inventory.get("herb", 0)) < 3
		_button("AID_COINS", _aid_action.bind("coins")).disabled = int(Session.inventory.get("coin", 0)) < 8
		_button("AID_MAGIC", _aid_action.bind("magic")).disabled = world.player.mana < 35 or not Nature.can_spell(Session.nature, "heal")
	if "waterworks_report" in Session.opened and "werewolf" not in Session.nature.history:
		_button("NATURE_TITLE", show_nature.bind("wayfarer")).name = "nature_invitation"
	_button("CLOSE", resume)
	_focus_first()

func _aid_action(event: String) -> void:
	world.aid_choice(event)
	show_aid_dialog()

func _position_toast(in_overlay: bool) -> void:
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM if in_overlay else Control.PRESET_CENTER_TOP)
	toast.offset_left = -350
	toast.offset_right = 350
	toast.offset_top = -52 if in_overlay else 110
	toast.offset_bottom = -6 if in_overlay else 156

func show_equipment() -> void:
	EquipmentScreen.equipment(self)

func show_wait() -> void:
	if not world.can_wait():
		show_notice("WAIT_UNAVAILABLE")
		return
	current_screen = "wait"
	_page("WAIT", 580)
	_label(screen, "WAIT_HELP", 16)
	_button("WAIT_HOUR", _wait_for.bind(60.0))
	_button("WAIT_MORNING", _wait_for.bind(Clock.until_morning(Session.world_state.minutes)))
	_button("BACK", resume)
	_focus_first()

func _wait_for(minutes: float) -> void:
	if world.wait(minutes):
		resume()

func show_encounter() -> void:
	if Session.world_state.active.is_empty():
		resume()
		return
	var id: String = Session.world_state.active.id
	current_screen = "dialog"
	_page("EVENT_TITLE_" + id.to_upper(), 620)
	var text := _label(screen, "EVENT_TEXT_" + id.to_upper(), 18)
	text.custom_minimum_size.x = 620
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for choice in EncounterRules.ENTRIES[id].choices:
		var button := _button("EVENT_CHOICE_" + str(choice).to_upper(), _event_choice.bind(choice))
		button.disabled = EncounterRules.resolve(id, choice, Session.inventory, world.player.mana, int(Session.world_state.reputation.roadfolk)).is_empty()
	_focus_first()

func _event_choice(choice: String) -> void:
	if world.resolve_encounter(choice):
		resume()
	else:
		show_encounter()

func show_spells() -> void:
	SpellScreen.show_book(self)

func _quit_game() -> void:
	get_tree().paused = true
	await Sound.shutdown()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()

func show_commission(target: String) -> void:
	CommissionScreen.show_dialog(self, target)

func show_trial(target: String) -> void:
	TrialScreen.show_dialog(self, target)

func show_nature(target: String = "status") -> void:
	NatureScreen.show_page(self, target)

func show_pack(target: String = "tracker") -> void:
	PackScreen.show_page(self, target)
