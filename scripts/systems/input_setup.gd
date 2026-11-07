extends RefCounted

static func install() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_J], "dodge": [KEY_SPACE], "block": [KEY_K],
		"frost": [KEY_G], "aegis": [KEY_R], "spellbook": [KEY_B], "cast": [KEY_F], "use_potion": [KEY_H], "heal": [KEY_Q], "interact": [KEY_E], "pause_game": [KEY_ESCAPE],
		"wait": [KEY_T], "equipment": [KEY_I], "skills": [KEY_C], "map": [KEY_M], "journal": [KEY_TAB], "save_game": [KEY_F5], "load_game": [KEY_F9],
		"bat_form": [KEY_Z], "mist_form": [KEY_X], "hybrid_form": [KEY_Y], "nature_power": [KEY_V], "shift_form": [KEY_U], "nature_book": [KEY_N], "fullscreen": [KEY_F11]
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.22)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var buttons := {"attack": JOY_BUTTON_X, "dodge": JOY_BUTTON_A, "block": JOY_BUTTON_LEFT_SHOULDER,
		"cast": JOY_BUTTON_RIGHT_SHOULDER, "heal": JOY_BUTTON_Y, "interact": JOY_BUTTON_B, "pause_game": JOY_BUTTON_START,
		"journal": JOY_BUTTON_BACK}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action, event)
	for binding in [["attack", MOUSE_BUTTON_LEFT], ["block", MOUSE_BUTTON_RIGHT]]:
		var event := InputEventMouseButton.new()
		event.button_index = binding[1]
		InputMap.action_add_event(binding[0], event)
	for binding in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
		["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = binding[1]
		event.axis_value = binding[2]
		InputMap.action_add_event(binding[0], event)
