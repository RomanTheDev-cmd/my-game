extends RefCounted
const Rules = preload("res://scripts/quests/junction_rules.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Text = preload("res://scripts/ui/campaign_screen.gd")
static func show_page(ui: Node, target: String = "invite", confirm: String = "") -> void:
	ui.current_screen = "dialog"
	ui._page("JOINT_TITLE", 620)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620, 285)
	ui.screen.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	if confirm != "":
		Text.text(ui, contents, "JOINT_CONFIRM_" + confirm.to_upper(), 18)
		var button: Button = ui._button("NATURE_CONFIRM", _act.bind(ui, confirm, target), contents)
		button.name = "joint_confirm_" + confirm
		button.disabled = not ui.world.can_junction(confirm)
		ui._button("BACK", show_page.bind(ui, target))
		ui._focus_first()
		return
	var stage := Rules.stage(Session.gathered, Session.opened)
	var key := "JOINT_DIALOG_" + target.to_upper()
	if target in ["steward", "mentor"] and stage >= 3: key += "_PROVED"
	if not Rules.ready(Session.opened): key = "JOINT_DIALOG_MISSING_" + target.to_upper()
	Text.text(ui, contents, key, 18)
	Text.text(ui, contents, "JOINT_HINT_%d" % stage if Rules.ready(Session.opened) else "JOINT_HINT_MISSING", 16)
	if stage == 4: Text.text(ui, contents, "JOINT_OUTCOME_PUBLIC" if Rules.CHOICES[0] in Session.gathered else "JOINT_OUTCOME_PRIVATE", 17)
	if target in ["steward", "mentor"]: history(ui, contents)
	for event in Rules.SITES:
		var place: String = Rules.SITES[event][1]
		if ("invite" if event == "accept" else place) != target or event == "prove": continue
		var possible := Rules.resolve(Session.nature, Session.skills, Session.gathered, Session.opened, Session.inventory, ui.world.player_vitals(), event, ui.world.player.magic_cooldown, ui.world.player.shield_recharge)
		if possible.is_empty() and event not in ["manual", "aegis"]: continue
		if event in ["manual", "aegis"] and (stage != 2 or Session.gathered.any(func(flag): return flag in Rules.METHODS)): continue
		var review: bool = event in ["public", "private"]
		var action: Callable = show_page.bind(ui, target, event) if review else _act.bind(ui, event, target)
		var button: Button = ui._button("JOINT_ACTION_" + event.to_upper(), action, contents)
		button.name = "joint_" + event
		if event == "aegis": button.text = ui.tr("JOINT_ACTION_AEGIS") % Magic.profile("aegis", Session.skills).cost
		button.disabled = not ui.world.can_junction(event)
	ui._button("BACK", ui.resume)
	ui._focus_first()
static func _act(ui: Node, event: String, target: String) -> void:
	if ui.world.junction_action(event): ui.resume()
	else: show_page(ui, target)
static func history(ui: Node, parent: Node) -> void:
	for flag in ["story:lake:method:manual", "story:lake:method:blood", "story:lake:method:scent", "forest:outcome:commons", "forest:outcome:watch", "city:outcome:shared", "city:outcome:release"]:
		if flag in Session.gathered:
			var part: String = flag.get_slice(":", flag.get_slice_count(":") - 1)
			Text.text(ui, parent, "JOINT_PREVIOUS_" + part.to_upper(), 16).name = "joint_previous_" + part
static func journal(ui: Node, parent: Node) -> void:
	if not Rules.ready(Session.opened): return
	ui._label(parent, "JOINT_TITLE", 23).add_theme_color_override("font_color", ui.gold)
	Text.text(ui, parent, "JOINT_HINT_%d" % Rules.stage(Session.gathered, Session.opened))
	if Rules.stage(Session.gathered, Session.opened) == 2 and Session.gathered.any(func(flag): return flag in Rules.METHODS): Text.text(ui, parent, "JOINT_MEASURE_HELP", 16)
