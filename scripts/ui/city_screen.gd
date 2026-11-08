extends RefCounted
const Accord = preload("res://scripts/quests/accord_rules.gd")
const Rules = preload("res://scripts/quests/city_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
static func show_page(ui: Node, target: String = "crafter", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("CITY_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if Accord.outcome(Session.opened) != "": Text.text(ui, contents, "ACCORD_REGION_CITY_" + Accord.outcome(Session.opened).to_upper(), 16)
	if confirm != "":
		var key := "CITY_CONFIRM_" + (Rules.draft(Session.gathered).to_upper() if confirm == "seal" else confirm.to_upper())
		Text.text(ui, contents, key, 18)
		var button: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		button.name = "city_confirm_" + confirm
		button.disabled = not ui.world.can_city(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var stage := Rules.stage(Session.gathered, Session.opened)
	var dialog := "CITY_DIALOG_" + target.to_upper()
	if stage == 3: dialog += "_DONE"
	elif target in ["crafter", "archivist"] and "city:heard:" + target in Session.gathered: dialog += "_ACTIVE"
	elif target == "press" and Session.gathered.any(func(flag): return flag in Rules.WORK): dialog += "_READY"
	elif target == "archive" and "city:copy" in Session.gathered: dialog += "_READY"
	elif target == "archive" and "city:memory" in Session.gathered: dialog += "_MEMORY"
	Text.text(ui, contents, dialog, 18)
	Text.text(ui, contents, "CITY_HINT_READY" if stage == 0 and "story:accepted" in Session.gathered else "CITY_HINT_%d" % stage, 16)
	var plan := Rules.draft(Session.gathered)
	if "city:accepted" in Session.gathered:
		Text.text(ui, contents, "CITY_PLAN_" + ("NONE" if plan == "" else plan.to_upper()), 17).name = "city_current_plan"
		Text.text(ui, contents, "").text = ui.tr("CITY_SIGNATURES") % [ui.tr("YES" if Rules.SIGNATURES[0] in Session.gathered else "NO"), ui.tr("YES" if Rules.SIGNATURES[1] in Session.gathered else "NO")]
	if stage == 3: Text.text(ui, contents, "CITY_OUTCOME_" + plan.to_upper(), 17).name = "city_outcome_memory"
	if target in ["crafter", "archivist"]:
		Text.text(ui, contents, "CITY_TERMS_" + target.to_upper(), 16)
		if stage in [1, 2] and plan != "" and not Rules.agrees(Session.gathered, target): Text.text(ui, contents, "CITY_COUNTER_" + target.to_upper() + "_" + plan.to_upper(), 17).name = "city_counteroffer"
		if stage == 0: history(ui, contents)
	for event in ["seal"] + Rules.SITES.keys().filter(func(event): return event != "seal"):
		if Rules.SITES[event] != target or stage == 3: continue
		var possible := Rules.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, ui.world.player_vitals(), Session.world_state.minutes, event)
		if event in ["accept", "hear_crafter", "hear_archivist", "sign_crafter", "sign_archivist", "supply", "copy", "memory", "work", "strength"] and possible.is_empty():
			if event not in ["work", "strength", "copy", "memory"] or "city:accepted" not in Session.gathered: continue
			if event == "memory" and (Session.nature.kind != "vampire" or "city:memory" in Session.gathered): continue
			if event == "strength" and (Session.nature.kind != "werewolf" or Session.gathered.any(func(flag): return flag in Rules.WORK)): continue
			if event == "work" and Session.gathered.any(func(flag): return flag in Rules.WORK): continue
			if event == "copy" and "city:copy" in Session.gathered: continue
		if event.begins_with("draft_") and (stage == 0 or plan == event.trim_prefix("draft_")): continue
		if event == "seal" and stage != 2: continue
		var reviewed: bool = event in ["seal", "memory", "supply"] or (event.begins_with("draft_") and Session.gathered.any(func(flag): return flag in Rules.SIGNATURES))
		var action: Callable = show_page.bind(ui, target, event) if reviewed else _act.bind(ui, event, target)
		var button: Button = ui._button("CITY_ACTION_" + event.to_upper(), action, contents)
		button.name = "city_" + event
		button.disabled = not ui.world.can_city(event)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.city_action(event): ui.resume()
	else: show_page(ui, target)
static func history(ui: Node, parent: Node) -> void:
	for flag in ["story:lake:report:share", "story:lake:report:provision", "forest:outcome:commons", "forest:outcome:watch"]:
		if flag in Session.gathered: Text.text(ui, parent, "CITY_PREVIOUS_" + flag.get_slice(":", flag.get_slice_count(":") - 1).to_upper(), 16).name = "city_previous_" + flag.get_slice(":", flag.get_slice_count(":") - 1)
static func journal(ui: Node, parent: Node) -> void:
	if "story:accepted" not in Session.gathered: return
	ui._label(parent, "CITY_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	var stage := Rules.stage(Session.gathered, Session.opened)
	Text.text(ui, parent, "CITY_HINT_READY" if stage == 0 else "CITY_HINT_%d" % stage)
	if Rules.draft(Session.gathered) != "": Text.text(ui, parent, "CITY_PLAN_" + Rules.draft(Session.gathered).to_upper())
