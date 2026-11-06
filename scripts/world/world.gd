extends Node2D
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
const Pack = preload("res://scripts/nature/pack_rules.gd")
const Thicket = preload("res://scripts/world/thicket_landscape.gd")
const TrackingCue = preload("res://scripts/world/tracking_cue.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Trial = preload("res://scripts/quests/trial_rules.gd")
const BossEnemy = preload("res://scripts/actors/boss_enemy.gd")
const Waterworks = preload("res://scripts/world/waterworks_landscape.gd")
const Factions = preload("res://scripts/factions/faction_rules.gd")
const Items = preload("res://scripts/items/inventory_rules.gd")
const Commission = preload("res://scripts/quests/commission_rules.gd")
const CommissionMarker = preload("res://scripts/world/commission_marker.gd")
const Workshop = preload("res://scripts/world/workshop_landscape.gd")
const Schedule = preload("res://scripts/world/living/npc_schedule.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Encounters = preload("res://scripts/world/living/encounter_rules.gd")
const ScheduledNpc = preload("res://scripts/actors/scheduled_npc.gd")
const WorldAmbience = preload("res://scripts/world/living/world_environment.gd")
const EncounterMarker = preload("res://scripts/world/living/encounter_marker.gd")
const Gear = preload("res://scripts/items/equipment_rules.gd")
const Bolt = preload("res://scripts/magic/spell_bolt.gd")
const Player = preload("res://scripts/actors/player.gd")
const RangedEnemy = preload("res://scripts/actors/ranged_enemy.gd")
const HeavyEnemy = preload("res://scripts/actors/heavy_enemy.gd")
const Enemy = preload("res://scripts/actors/enemy.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Navigator = preload("res://scripts/world/navigation_grid.gd")
const Landscape = preload("res://scripts/world/landscape.gd")
signal dialog_requested(kind: String)
signal travel_requested(destination: String, position: Vector2)
signal player_died
var pack_markers: Dictionary = {}
var tracking_cue: Node2D
var boss: CharacterBody2D
var trial_markers: Dictionary = {}
var npcs: Dictionary = {}
var commission_markers: Dictionary = {}
var salvage_markers: Array[Node2D] = []
var commission_gate: StaticBody2D
var landscape: Node2D
var merchant: CharacterBody2D
var player: CharacterBody2D
var wayfarer: CharacterBody2D
var keeper: CharacterBody2D
var lantern: Sprite2D
var herbs: Array[Sprite2D] = []
var chests: Array[Sprite2D] = []
var time := 0.0
var definition: Dictionary = {}
var navigation: RefCounted
var encounter_timer := 0.0
var event_timer := 1.0
var event_marker: Node2D
var encounter_checkpoints: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	definition = Regions.get_region(Session.region)
	landscape = Thicket.new() if Session.region == "thicket" else (Waterworks.new() if Session.region == "waterworks" else (Workshop.new() if Session.region == "workshop" else Landscape.new()))
	landscape.region = Session.region
	landscape.z_index = -2
	add_child(landscape)
	_build_commission_objects()
	for kind in definition.get("pack_sites", {}):
		var marker := CommissionMarker.new()
		marker.kind = "scrap" if kind.begins_with("trail_") else "archive"
		marker.position = definition.pack_sites[kind]
		add_child(marker)
		pack_markers[kind] = marker
	for kind in definition.get("trial_sites", {}):
		var marker := CommissionMarker.new()
		marker.kind = "wheel" if kind == "altar" else "archive"
		marker.position = definition.trial_sites[kind]
		add_child(marker)
		trial_markers[kind] = marker
	navigation = Navigator.new()
	navigation.configure(self)
	for kind in Schedule.KINDS:
		npcs[kind] = _spawn_npc(kind)
	merchant = npcs.merchant
	merchant.modulate = Color("c2ad9b")
	keeper = npcs.keeper
	wayfarer = npcs.wayfarer
	event_marker = EncounterMarker.new()
	event_marker.hide()
	add_child(event_marker)
	lantern = Sprite2D.new()
	lantern.texture = preload("res://assets/sprites/lantern.png")
	lantern.position = Vector2(1240, 420)
	lantern.visible = Session.region == "crossing" and Session.quest < 2
	add_child(lantern)
	for point in definition.herbs:
		var herb := Sprite2D.new()
		herb.texture = preload("res://assets/sprites/herb.png")
		herb.position = point
		herb.set_meta("id", Regions.herb_id(Session.region, point))
		herb.visible = herb.get_meta("id") not in Session.gathered
		add_child(herb)
		herbs.append(herb)
	for entry in definition.get("chests", []):
		var chest := Sprite2D.new()
		chest.texture = preload("res://assets/sprites/chest.png")
		chest.position = entry.point
		chest.set_meta("definition", entry)
		chest.modulate = Color("6d7770") if entry.id in Session.opened else Color.WHITE
		add_child(chest)
		chests.append(chest)
	player = Player.new()
	player.position = Session.arrival
	player.health = Session.vitals.health
	player.stamina = Session.vitals.stamina
	player.mana = Session.vitals.mana
	add_child(player)
	player.died.connect(func(): player_died.emit())
	player.strike.connect(_on_strike)
	player.cast_spell.connect(_on_cast_spell)
	player.howled.connect(_on_howl)
	tracking_cue = TrackingCue.new()
	tracking_cue.hide()
	tracking_cue.z_index = 4
	add_child(tracking_cue)
	for entry in definition.enemies:
		if entry[0] in Session.defeated:
			continue
		var kind: String = entry[2] if entry.size() > 2 else "melee"
		var enemy = BossEnemy.new() if kind == "boss" else (RangedEnemy.new() if kind == "ranged" else (HeavyEnemy.new() if kind == "heavy" else Enemy.new()))
		enemy.id = entry[0]
		enemy.position = entry[1]
		enemy.target = player
		enemy.navigation = navigation
		if kind == "boss":
			boss = enemy
			boss.armed = "waterworks:awakened" in Session.gathered
			boss.victory_requested.connect(record_boss_victory)
		else:
			enemy.defeated.connect(_on_defeated)
		add_child(enemy)

	var environment := WorldAmbience.new()
	environment.region = Session.region
	environment.player = player
	add_child(environment)
	_update_npcs()
	_update_event_marker()
	_sync_context()
	Session.changed.connect(_update_pack_environment)
	Session.changed.connect(_update_trial_environment)
	Session.changed.connect(_update_commission_environment)
	_update_commission_environment()
	_update_trial_environment()
	_update_pack_environment()

func _process(delta: float) -> void:
	time += delta
	_update_tracking()
	if Session.running and player.health > 0:
		Session.advance_world(delta)
	_update_npcs()
	_sync_context()
	event_timer -= delta
	if event_timer <= 0:
		event_timer = 1
		_poll_encounter()
	_update_event_marker()
	encounter_timer -= delta
	if encounter_timer <= 0:
		encounter_timer = 0.1
		_checkpoint_before_encounter()
	lantern.position.y = 420 + sin(time * 2) * 2
	if Input.is_action_just_pressed("interact") and Session.running:
		interact()
	if Input.is_action_just_pressed("save_game"):
		save_safe()
	if Input.is_action_just_pressed("fullscreen"):
		Session.set_fullscreen(not Session.fullscreen)

func safe_to_rest() -> bool:
	if is_instance_valid(boss) and (boss.awaiting_record or boss.engaged): return false
	for child in get_children():
		if child is BossEnemy and not child.armed: continue
		if child is Enemy and child.global_position.distance_to(player.global_position) < child.aggro_range + 20:
			return false
	for arrow in get_tree().get_nodes_in_group("hostile_projectiles"):
		if arrow.get_parent() == self:
			return false
	return true

func save_safe() -> void:
	_sync_context()
	if safe_to_rest():
		Session.save_at(player.position, player_vitals())
	else:
		Session.notice.emit("CHECKPOINT_UNSAFE")

func nearby_key() -> String:
	if is_instance_valid(boss) and boss.awaiting_record and player.position.distance_to(boss.position) < 65:
		return "TRIAL_RECORD"
	for kind in trial_markers:
		if player.position.distance_to(trial_markers[kind].position) < 48:
			return "TRIAL_SITE_" + kind.to_upper()
	if merchant.visible and player.position.distance_to(merchant.position) < 45:
		return "MERCHANT_NAME" if Schedule.shop_open(Session.world_state.minutes) else "MERCHANT_CLOSED"
	if keeper.visible and player.position.distance_to(keeper.position) < 50:
		return "KEEPER_NAME"
	if wayfarer.visible and player.position.distance_to(wayfarer.position) < 45:
		return "AID_NAME"
	for kind in ["warden", "wright", "tender", "tracker"]:
		if npcs[kind].visible and player.position.distance_to(npcs[kind].position) < 48:
			return kind.to_upper() + "_NAME"
	for target in pack_markers:
		if player.position.distance_to(pack_markers[target].position) < 45: return "PACK_SITE_" + target.to_upper()
	for target in commission_markers:
		if player.position.distance_to(commission_markers[target].position) < 45:
			return "COMMISSION_" + target.to_upper()
	for marker in salvage_markers:
		if marker.visible and player.position.distance_to(marker.position) < 30:
			return "SCRAP"
	if player.position.distance_to(definition.camp) < 45:
		return "REST"
	if lantern.visible and player.position.distance_to(lantern.position) < 40:
		return "LANTERN"
	if event_marker.visible and player.position.distance_to(event_marker.position) < 45:
		return "ENCOUNTER"
	for herb in herbs:
		if herb.visible and player.position.distance_to(herb.position) < 30:
			return "HERB"
	for chest in chests:
		if chest.get_meta("definition").id not in Session.opened and player.position.distance_to(chest.position) < 40:
			return "CHEST"
	for portal in Regions.exits(Session.region):
		if player.position.distance_to(portal.point) < 55:
			return portal.label
	return ""

func interact() -> void:
	_sync_context()
	var key := nearby_key()
	if key == "TRIAL_RECORD":
		record_boss_victory()
		return
	if key.begins_with("TRIAL_SITE_"):
		dialog_requested.emit("trial:" + key.trim_prefix("TRIAL_SITE_").to_lower())
		return
	if Session.nature.form != "human" and (key.ends_with("_NAME") or key.begins_with("COMMISSION_") or key.begins_with("TRIAL_SITE_") or key.begins_with("PACK_SITE_")):
		var role: String = {"KEEPER_NAME": "keeper", "MERCHANT_NAME": "merchant", "AID_NAME": "wayfarer", "WARDEN_NAME": "warden", "WRIGHT_NAME": "wright", "TENDER_NAME": "tender", "TRACKER_NAME": "tracker"}.get(key, "")
		if role != "": dialog_requested.emit("reaction:" + role)
		else: Session.notice.emit("NATURE_RETURN_FORM")
		return
	if key == "TRACKER_NAME":
		dialog_requested.emit("tracker")
		return
	if key.begins_with("PACK_SITE_"):
		dialog_requested.emit("pack:" + key.trim_prefix("PACK_SITE_").to_lower())
		return
	if key.begins_with("TO_"):
		for portal in Regions.exits(Session.region):
			if portal.label == key:
				travel_requested.emit(portal.destination, portal.arrival)
				return
	if key in ["WARDEN_NAME", "WRIGHT_NAME", "TENDER_NAME"]:
		dialog_requested.emit("commission:" + key.trim_suffix("_NAME").to_lower())
		return
	if key.begins_with("COMMISSION_"):
		dialog_requested.emit("commission:" + key.trim_prefix("COMMISSION_").to_lower())
		return
	if key == "SCRAP":
		if not safe_to_rest():
			Session.notice.emit("CHECKPOINT_UNSAFE")
			return
		for marker in salvage_markers:
			if marker.visible and player.position.distance_to(marker.position) < 30:
				Session.collect_salvage(marker.get_meta("id"), player.position, player_vitals())
				return
	match key:
		"ENCOUNTER": dialog_requested.emit("encounter")
		"MERCHANT_CLOSED": dialog_requested.emit("merchant_closed")
		"MERCHANT_NAME": dialog_requested.emit("merchant")
		"KEEPER_NAME": dialog_requested.emit("keeper")
		"AID_NAME": dialog_requested.emit("wayfarer")
		"REST":
			if safe_to_rest():
				wait(30)
			else:
				Session.notice.emit("CHECKPOINT_UNSAFE")
		"LANTERN":
			if Session.advance_quest("found"):
				lantern.hide()
				Session.notice.emit("LANTERN_FOUND")
				Session.changed.emit()
		"CHEST":
			if not safe_to_rest():
				Session.notice.emit("CHECKPOINT_UNSAFE")
				return
			for chest in chests:
				if player.position.distance_to(chest.position) < 40 and chest.get_meta("definition").id not in Session.opened:
					if Session.claim_chest(chest.get_meta("definition"), player.position, player_vitals()):
						chest.modulate = Color("6d7770")
					return
		"HERB":
			for herb in herbs:
				if herb.visible and player.position.distance_to(herb.position) < 30:
					herb.hide()
					Session.gathered.append(herb.get_meta("id"))
					Session.collect("herb")
					Session.notice.emit("HERB_FOUND")
					break

func _on_strike(origin: Vector2, direction: Vector2) -> void:
	for child in get_children():
		if child is Enemy:
			var offset: Vector2 = child.global_position - origin
			if offset.length() < player.weapon_stats().reach and offset.normalized().dot(direction) > 0.15 and navigation.segment_clear(origin, child.global_position):
				child.receive_damage(player.weapon_stats().damage + 4 * int(Session.skills.get("sword", 0)), direction)

func _on_defeated(id: String) -> void:
	if id not in Session.defeated:
		Session.defeated.append(id)
		var reward := 20
		var coins := 3
		for child in get_children():
			if child is Enemy and child.id == id:
				reward = child.reward_xp
				coins = child.coin_reward
				break
		Session.award_xp(reward)
		Session.inventory["coin"] = mini(999, int(Session.inventory.get("coin", 0)) + coins)
	Session.changed.emit()

func _draw() -> void:
	if definition.is_empty():
		return
	for portal in Regions.exits(Session.region):
		var point: Vector2 = portal.point
		draw_rect(Rect2(point + Vector2(-2, -27), Vector2(4, 30)), Color("6c654e"))
		draw_rect(Rect2(point + Vector2(-18, -30), Vector2(36, 12)), Color("baaa7d"))
		var direction: int = portal.direction
		var tip := point + Vector2(direction * 12, -24)
		draw_line(point + Vector2(-direction * 12, -24), tip, Color("394d46"), 2)
		draw_line(tip, tip + Vector2(-direction * 5, -4), Color("394d46"), 2)
		draw_line(tip, tip + Vector2(-direction * 5, 4), Color("394d46"), 2)

func player_vitals() -> Dictionary:
	return {"health": player.health, "stamina": player.stamina, "mana": player.mana}

func _on_cast_spell(origin: Vector2, direction: Vector2, amount: float, kind: String = "light") -> void:
	var bolt := Bolt.new()
	bolt.position = origin
	bolt.direction = direction
	bolt.damage = amount
	bolt.kind = kind
	bolt.blood_drained.connect(func(amount):
		if Session.nature.kind == "vampire" and player.health > 0:
			player.health = minf(100, player.health + amount)
			player.stats_changed.emit())
	add_child(bolt)

func _checkpoint_before_encounter() -> void:
	if player.health <= 0 or not safe_to_rest():
		return
	for child in get_children():
		if child is BossEnemy and not child.armed: continue
		if child is Enemy and not encounter_checkpoints.has(child.id):
			var distance: float = child.position.distance_to(player.position)
			if distance > child.aggro_range + 20 and distance < child.aggro_range + 80:
				if Session.save_at(player.position, player_vitals()):
					encounter_checkpoints[child.id] = true
				return

func aid_choice(event: String) -> bool:
	var result := Session.advance_aid(event, player.mana)
	if result.is_empty():
		return false
	player.mana = result.mana
	save_safe()
	return true

func trade(id: String, selling: bool) -> bool:
	_sync_context()
	var vendor := vendor_context()
	if Session.nature.form != "human" or vendor.is_empty() or not safe_to_rest():
		return false
	return Session.trade_item(id, selling, player.position, player_vitals(), vendor.group)

func _spawn_npc(kind: String) -> CharacterBody2D:
	var npc := ScheduledNpc.new()
	npc.kind = kind
	npc.navigation = navigation
	var destination := Schedule.destination(Session.region, kind, Session.world_state.minutes, Session.aid_quest)
	var saved: Array = Session.world_state.npcs.get(Session.region + ":" + kind, [destination.x, destination.y])
	npc.position = Vector2(saved[0], saved[1])
	npc.destination = destination
	npc.visible = definition.has(kind)
	add_child(npc)
	return npc

func _update_npcs() -> void:
	for npc in npcs.values():
		if is_instance_valid(npc) and npc.visible:
			npc.set_destination(Schedule.destination(Session.region, npc.kind, Session.world_state.minutes, Session.aid_quest))

func _sync_context() -> void:
	for npc in npcs.values():
		if is_instance_valid(npc) and npc.visible:
			Session.world_state.npcs[Session.region + ":" + npc.kind] = [npc.position.x, npc.position.y]

func can_wait() -> bool:
	return Session.nature.form == "human" and player.health > 0 and player.position.distance_to(definition.camp) < 45 and safe_to_rest()

func wait(minutes: float) -> bool:
	if not can_wait():
		Session.notice.emit("WAIT_UNAVAILABLE")
		return false
	_sync_context()
	if not Session.wait_minutes(minutes, player.position):
		return false
	player.restore()
	_update_npcs()
	return true

func _poll_encounter() -> void:
	if not definition.has("event_point") or not safe_to_rest() or not Session.world_state.active.is_empty():
		return
	if Session.world_state.minutes < Session.world_state.next_event or player.position.distance_to(definition.event_point) < 330:
		return
	var id := Encounters.choose(Session.region, Session.world_state.minutes, int(Session.world_state.seed), Session.world_state.seen, int(Session.world_state.reputation.roadfolk))
	if id != "":
		Session.world_state.active = {"id": id, "region": Session.region, "position": [definition.event_point.x, definition.event_point.y]}

func _update_event_marker() -> void:
	var event: Dictionary = Session.world_state.active
	event_marker.visible = not event.is_empty() and event.region == Session.region
	if event_marker.visible:
		event_marker.position = Vector2(event.position[0], event.position[1])
		event_marker.event_id = event.id

func resolve_encounter(choice: String) -> bool:
	if nearby_key() != "ENCOUNTER" or not safe_to_rest():
		return false
	_sync_context()
	if not Session.resolve_encounter(choice, player.position, player_vitals()):
		return false
	player.mana = Session.vitals.mana
	_update_event_marker()
	return true

func _build_commission_objects() -> void:
	if Session.region != "workshop":
		return
	if Session.world_state.commission.stage < 5:
		commission_gate = StaticBody2D.new()
		commission_gate.position = Workshop.GATE.get_center()
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Workshop.GATE.size
		collider.shape = shape
		commission_gate.add_child(collider)
		add_child(commission_gate)
	for kind in definition.commission_sites:
		var marker := CommissionMarker.new()
		marker.kind = kind
		marker.position = definition.commission_sites[kind]
		add_child(marker)
		commission_markers[kind] = marker
	for entry in definition.salvage:
		var marker := CommissionMarker.new()
		marker.kind = "scrap"
		marker.position = entry.point
		marker.set_meta("id", entry.id)
		add_child(marker)
		salvage_markers.append(marker)

func _update_commission_environment() -> void:
	if not is_inside_tree() or Session.region != "workshop" or landscape.region != Session.region:
		return
	var state: Dictionary = Session.world_state.commission
	if state.stage >= 5 and is_instance_valid(commission_gate):
		remove_child(commission_gate)
		commission_gate.queue_free()
		commission_gate = null
		navigation.configure(self)
	landscape.queue_redraw()
	for kind in commission_markers:
		var marker: Node2D = commission_markers[kind]
		marker.done = (state.stage >= 5 if kind == "wheel" else (kind in state.survey or (kind == "workbench" and state.supply == "craft") or (kind == "cache" and state.supply == "recover")))
		marker.queue_redraw()
	for marker in salvage_markers:
		marker.visible = marker.get_meta("id") not in Session.gathered

func can_commission(event: String) -> bool:
	if Session.nature.form != "human" or not Commission.SITES.has(event) or Commission.SITES[event][0] != Session.region or player.health <= 0 or not safe_to_rest():
		return false
	var target: String = Commission.SITES[event][1]
	var point := Vector2.INF
	if npcs.has(target):
		if not npcs[target].visible:
			return false
		point = npcs[target].position
	else:
		point = definition.get("commission_sites", {}).get(target, Vector2.INF)
	if player.position.distance_to(point) >= 52:
		return false
	return not Commission.transition(Session.world_state.commission, Session.inventory, player.mana, Session.world_state.reputation, event, Session.quest, Session.defeated).is_empty()

func commission_action(event: String) -> bool:
	if not can_commission(event):
		Session.notice.emit("COMMISSION_UNAVAILABLE")
		return false
	_sync_context()
	if not Session.commission_event(event, player.position, player_vitals()):
		return false
	player.mana = Session.vitals.mana
	return true

func vendor_context() -> Dictionary:
	if merchant.visible and player.position.distance_to(merchant.position) < 45 and Schedule.shop_open(Session.world_state.minutes):
		return {"group": "roadfolk", "name": "MERCHANT_NAME", "trust": int(Session.world_state.reputation.roadfolk)}
	if npcs.warden.visible and player.position.distance_to(npcs.warden.position) < 48 and Factions.trusted(Session.world_state.reputation, "wardens"):
		return {"group": "wardens", "name": "WARDEN_NAME", "trust": int(Session.world_state.reputation.wardens)}
	return {}

func can_brew_with_tender() -> bool:
	return Session.nature.form == "human" and npcs.tender.visible and player.health > 0 and player.position.distance_to(npcs.tender.position) < 48 and safe_to_rest() and not Items.brew_with_tender(Session.inventory, int(Session.world_state.reputation.tenders)).is_empty()

func brew_with_tender() -> bool:
	if not can_brew_with_tender():
		return false
	_sync_context()
	return Session.brew_with_tender(player.position, player_vitals())

func can_trial(event: String) -> bool:
	if Session.nature.form != "human" or not Trial.SITES.has(event) or player.health <= 0 or not safe_to_rest(): return false
	var site: Array = Trial.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs.wright.position if site[1] == "wright" and npcs.wright.visible else definition.get("trial_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 52 and not Trial.transition(Session.gathered, Session.defeated, Session.opened, Session.inventory, int(Session.world_state.commission.stage), event).is_empty()

func trial_action(event: String) -> bool:
	if not can_trial(event): return false
	_sync_context()
	return Session.trial_event(event, player.position, player_vitals())

func _update_trial_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	if is_instance_valid(boss): boss.armed = "waterworks:awakened" in Session.gathered
	for kind in trial_markers:
		trial_markers[kind].done = "waterworks:" + kind in Session.gathered or (kind == "altar" and "waterworks:awakened" in Session.gathered)
		trial_markers[kind].queue_redraw()

func record_boss_victory() -> void:
	if not is_instance_valid(boss) or not boss.awaiting_record or player.health <= 0: return
	_sync_context()
	if Session.finish_guardian(player.position, player_vitals()):
		boss.queue_free()
		boss = null

func can_nature(event: String) -> bool:
	if not Nature.SITES.has(event) or player.health <= 0 or not safe_to_rest(): return false
	var site: Array = Nature.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("trial_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 52 and not Nature.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, player.mana, event).is_empty()

func nature_action(event: String) -> bool:
	if not can_nature(event): return false
	_sync_context()
	if not Session.nature_event(event, player.position, player_vitals()): return false
	player.mana = Session.vitals.mana
	return true

func can_dialogue(kind: String, answer: String) -> bool:
	if player.health <= 0 or not safe_to_rest() or not npcs.has(kind) or not npcs[kind].visible or player.position.distance_to(npcs[kind].position) >= 52: return false
	return not Dialogue.resolve(Session.nature, Session.gathered, Session.world_state.reputation, kind, answer).is_empty()

func dialogue_action(kind: String, answer: String) -> bool:
	if not can_dialogue(kind, answer): return false
	_sync_context()
	return Session.dialogue_event(kind, answer, player.position, player_vitals())

func can_pack(event: String) -> bool:
	if not Pack.SITES.has(event) or player.health <= 0 or not safe_to_rest(): return false
	var site: Array = Pack.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("pack_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 52 and not Pack.resolve(Session.nature, Session.gathered, Session.opened, player.mana, event).is_empty()
func pack_action(event: String) -> bool:
	if not can_pack(event): return false
	_sync_context()
	if not Session.pack_event(event, player.position, player_vitals()): return false
	player.mana = Session.vitals.mana
	return true
func _update_pack_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	for kind in pack_markers:
		pack_markers[kind].done = "pack:" + kind in Session.gathered or (kind == "den" and "pack:release_den" in Session.gathered)
		pack_markers[kind].queue_redraw()
	_update_tracking()
func _update_tracking() -> void:
	if not is_instance_valid(player) or not is_instance_valid(tracking_cue): return
	var nearest := Vector2.INF
	var distance := 500.0
	for chest in chests:
		var entry: Dictionary = chest.get_meta("definition")
		if not entry.get("hidden", false): continue
		var offset: float = player.position.distance_to(chest.position)
		chest.visible = offset < 40 or (player.can_track() and offset < 260)
		if entry.id not in Session.opened and offset < distance:
			nearest = chest.position
			distance = offset
	tracking_cue.visible = player.can_track() and nearest != Vector2.INF
	if tracking_cue.visible:
		tracking_cue.position = player.position + Vector2(0, -12)
		tracking_cue.direction = player.position.direction_to(nearest)
		tracking_cue.queue_redraw()
func _on_howl(origin: Vector2) -> void:
	for child in get_children():
		if child is Enemy and child.health > 0 and child.position.distance_to(origin) < 150 and navigation.segment_clear(origin, child.position): child.apply_slow(3, 0.55)
	_update_tracking()
