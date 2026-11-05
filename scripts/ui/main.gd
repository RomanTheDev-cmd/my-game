extends Node
const World = preload("res://scripts/world/world.gd")
const Store = preload("res://scripts/systems/save_store.gd")
var world: Node2D
var layer: CanvasLayer
var hud: Control
var overlay: Control
var screen: VBoxContainer
var toast: Label
var toast_time := 0.0
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
	toast.position = Vector2(-350, -148)
	toast.size = Vector2(700, 46)
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

func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(280, 44)
	button.pressed.connect(action)
	screen.add_child(button)
	return button

func _page(key: String, width: float = 420) -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	get_tree().paused = true
	overlay.show()
	hud.visible = Session.running
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.08, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	for child in screen.get_children():
		if child is Button and not child.disabled:
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
	_button("QUIT", func(): get_tree().quit())
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
	hud.show()
	get_tree().paused = false
	update_hud()

func show_pause() -> void:
	current_screen = "pause"
	_page("PAUSED")
	_button("RESUME", resume)
	_button("SAVE", func():
		world.save_safe())
	_button("LOAD", load_game)
	_button("SETTINGS", show_settings)
	_button("MAIN_MENU", show_title)
	_focus_first()

func show_settings() -> void:
	current_screen = "settings"
	_page("SETTINGS")
	_label(screen, "DIFFICULTY")
	var choice := OptionButton.new()
	for key in ["STORY", "ADVENTURE", "CHALLENGE"]:
		choice.add_item(tr(key))
	choice.select(Session.difficulty)
	choice.item_selected.connect(func(index): Session.difficulty = index)
	screen.add_child(choice)
	var fullscreen := CheckButton.new()
	fullscreen.text = tr("FULLSCREEN")
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED))
	screen.add_child(fullscreen)
	_button("BACK", show_pause if Session.running else show_title)
	choice.grab_focus()

func show_journal() -> void:
	current_screen = "journal"
	_page("JOURNAL", 600)
	var task := _label(screen, "QUEST_%d" % Session.quest, 20)
	task.custom_minimum_size.x = 600
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(screen, "INVENTORY", 23).add_theme_color_override("font_color", gold)
	var entries := 0
	for item in Session.inventory:
		var amount := int(Session.inventory[item])
		if amount > 0:
			_label(screen, "").text = "%s × %d" % [tr(str(item).to_upper()), amount]
			entries += 1
	if entries == 0:
		_label(screen, "EMPTY")
	_button("BACK", resume)
	_focus_first()

func show_dialog() -> void:
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
	_label(stats, "HUMAN", 14)
	health_bar = _bar(stats, Color("b3665a"))
	stamina_bar = _bar(stats, Color("aeab70"))
	mana_bar = _bar(stats, Color("7ca3b1"))
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
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -122
	bottom.offset_bottom = -12
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	prompt = _label(bottom, "", 18)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", gold)
	quest_label = _label(bottom, "QUEST_0", 16)
	quest_label.add_theme_color_override("font_shadow_color", Color("14292a"))
	quest_label.add_theme_constant_override("shadow_offset_x", 2)
	quest_label.add_theme_constant_override("shadow_offset_y", 2)
	_label(bottom, "CONTROLS", 12)
	_label(bottom, "SAVE_HINT", 12)

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
	location_label.text = tr(world.definition.location)
	region_label.text = tr(world.definition.description)
	health_bar.value = world.player.health
	stamina_bar.value = world.player.stamina
	mana_bar.value = world.player.mana
	health_bar.tooltip_text = "%s: %d/100" % [tr("HP"), int(world.player.health)]
	stamina_bar.tooltip_text = "%s: %d/100" % [tr("STAMINA"), int(world.player.stamina)]
	mana_bar.tooltip_text = "%s: %d/100" % [tr("MANA"), int(world.player.mana)]
	quest_label.text = tr("QUEST_%d" % Session.quest)
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
		elif current_screen in ["pause", "dialog", "journal", "settings"] and Session.running:
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
