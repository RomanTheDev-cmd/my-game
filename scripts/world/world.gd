extends Node2D
const Delve = preload("res://scripts/quests/delve_rules.gd")
const DelveGenerator = preload("res://scripts/world/delve_generator.gd")
const Hollow = preload("res://scripts/world/hollow_landscape.gd")
const HollowWarden = preload("res://scripts/actors/hollow_warden.gd")
const DelveMarker = preload("res://scripts/world/delve_marker.gd")
const Knell = preload("res://scripts/quests/knell_rules.gd")
const Undercroft = preload("res://scripts/world/undercroft_landscape.gd")
const EchoEnemy = preload("res://scripts/actors/echo_enemy.gd")
const BellBoss = preload("res://scripts/actors/bell_boss.gd")
const KnellPlaque = preload("res://scripts/world/knell_plaque.gd")
const KnellCue = preload("res://scripts/world/knell_cue.gd")
const Accord = preload("res://scripts/quests/accord_rules.gd")
const AccordChanges = preload("res://scripts/world/accord_changes.gd")
const Rescue = preload("res://scripts/quests/rescue_rules.gd")
const Underhall = preload("res://scripts/world/underhall_landscape.gd")
const RescueEngine = preload("res://scripts/world/rescue_engine.gd")
const RescueCoil = preload("res://scripts/world/rescue_coil.gd")
const Preparation = preload("res://scripts/quests/preparation_rules.gd")
const PreparationRoute = preload("res://scripts/world/preparation_route.gd")
const Junction = preload("res://scripts/quests/junction_rules.gd")
const Rotunda = preload("res://scripts/world/rotunda_landscape.gd")
const JunctionConsole = preload("res://scripts/world/junction_console.gd")
const City = preload("res://scripts/quests/city_rules.gd")
const CityLandscape = preload("res://scripts/world/city_landscape.gd")
const CityBoard = preload("res://scripts/world/city_board.gd")
const Forest = preload("res://scripts/quests/forest_rules.gd")
const Woodroad = preload("res://scripts/world/woodroad_landscape.gd")
const ForestSign = preload("res://scripts/world/forest_sign.gd")
const Campaign = preload("res://scripts/quests/campaign_rules.gd")
const Terrace = preload("res://scripts/world/terrace_landscape.gd")
const CampaignDevice = preload("res://scripts/world/campaign_device.gd")
const Field = preload("res://scripts/magic/field_rules.gd")
const FieldDevice = preload("res://scripts/world/field_device.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Community = preload("res://scripts/factions/community_rules.gd")
const Haven = preload("res://scripts/world/haven_landscape.gd")
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
var bell: CharacterBody2D
var delve_stairs: Node2D
var delve_note: Node2D
var knell_plaques: Dictionary = {}
var knell_cue: Node2D
var rescue_engine: Node2D
var rescue_coils: Dictionary = {}
var preparation_route: Node2D
var junction_objects: Dictionary = {}
var city_objects: Dictionary = {}
var forest_signs: Array[Node2D] = []
var campaign_devices: Dictionary = {}
var field_devices: Dictionary = {}
var community_delivery: Node2D
var community_markers: Dictionary = {}
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
	if definition.get("generated", false):
		definition.merge(DelveGenerator.generate(Delve.seed_of(Session.world_state), Delve.depth_of(Session.region)), true)
	landscape = Hollow.new() if definition.get("generated", false) else Undercroft.new() if Session.region == "undercroft" else Underhall.new() if Session.region == "underhall" else Rotunda.new() if Session.region == "rotunda" else CityLandscape.new() if Session.region == "velshof" else Woodroad.new() if Session.region == "woodroad" else Terrace.new() if Session.region == "terrace" else Haven.new() if Session.region == "haven" else Thicket.new() if Session.region == "thicket" else (Waterworks.new() if Session.region == "waterworks" else (Workshop.new() if Session.region == "workshop" else Landscape.new()))
	landscape.region = Session.region
	landscape.z_index = -2
	add_child(landscape)
	if Session.region == "rotunda":
		preparation_route = PreparationRoute.new()
		preparation_route.world = self
		add_child(preparation_route)
	if Session.region == "underhall":
		rescue_engine = RescueEngine.new()
		rescue_engine.world = self
		rescue_engine.z_index = -1
		add_child(rescue_engine)
		for side in Rescue.COILS:
			var coil := RescueCoil.new()
			coil.side = side
			coil.world = self
			coil.position = Rescue.COILS[side]
			add_child(coil)
			rescue_coils[side] = coil
	_build_commission_objects()
	for id in definition.get("junction_sites", {}):
		var object := JunctionConsole.new()
		object.kind = id
		object.world = self
		object.position = definition.junction_sites[id]
		add_child(object)
		junction_objects[id] = object
	for id in definition.get("city_sites", {}):
		var object := CityBoard.new()
		object.kind = id
		object.position = definition.city_sites[id]
		add_child(object)
		city_objects[id] = object
	for point in definition.get("forest_sites", []):
		var sign := ForestSign.new()
		sign.position = point
		add_child(sign)
		forest_signs.append(sign)
	for id in definition.get("story_sites", {}):
		var device := CampaignDevice.new()
		device.kind = id
		device.position = definition.story_sites[id]
		add_child(device)
		campaign_devices[id] = device
	if definition.has("stairs"):
		delve_stairs = DelveMarker.new()
		delve_stairs.position = definition.stairs
		add_child(delve_stairs)
	if definition.has("note"):
		delve_note = DelveMarker.new()
		delve_note.kind = "note"
		delve_note.position = definition.note
		add_child(delve_note)
	for id in definition.get("knell_sites", {}):
		var plaque := KnellPlaque.new()
		plaque.position = definition.knell_sites[id]
		add_child(plaque)
		knell_plaques[id] = plaque
	if Session.region == "crossing":
		knell_cue = KnellCue.new()
		knell_cue.position = Vector2(1120, 300)
		knell_cue.z_index = 3
		add_child(knell_cue)
	for id in definition.get("field_sites", {}):
		var device := FieldDevice.new()
		device.kind = id
		device.position = definition.field_sites[id]
		add_child(device)
		field_devices[id] = device
	if Session.region == "haven":
		community_delivery = CommissionMarker.new()
		community_delivery.kind = "cache"
		community_delivery.done = true
		community_delivery.position = Vector2(560, 600)
		add_child(community_delivery)
	for kind in definition.get("community_sites", {}):
		var marker := CommissionMarker.new()
		marker.kind = {"supply": "cache", "route": "archive", "search": "scrap"}[kind]
		marker.position = definition.community_sites[kind]
		add_child(marker)
		community_markers[kind] = marker
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
		var enemy = HollowWarden.new() if kind == "warden" else BellBoss.new() if kind == "bell" else EchoEnemy.new() if kind == "echo" else BossEnemy.new() if kind == "boss" else (RangedEnemy.new() if kind == "ranged" else (HeavyEnemy.new() if kind == "heavy" else Enemy.new()))
		enemy.id = entry[0]
		enemy.position = entry[1]
		enemy.target = player
		enemy.navigation = navigation
		if kind == "bell":
			bell = enemy
			bell.armed = Knell.armed(Session.gathered, Session.defeated)
			bell.cover_rects = Undercroft.PILLARS
			bell.victory_requested.connect(record_bell_victory)
		elif kind == "boss":
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
	Session.changed.connect(_update_knell_environment)
	_update_knell_environment()
	Session.changed.connect(_update_delve_environment)
	_update_delve_environment()
	Session.changed.connect(_update_preparation_environment)
	_update_preparation_environment()
	Session.changed.connect(_update_junction_environment)
	_update_junction_environment()
	Session.changed.connect(_update_rescue_environment)
	_update_rescue_environment()
	Session.changed.connect(_update_accord_environment)
	_update_accord_environment()
	Session.changed.connect(_update_city_environment)
	_update_city_environment()
	Session.changed.connect(_update_forest_environment)
	_update_forest_environment()
	Session.changed.connect(_update_campaign_environment)
	_update_campaign_environment()
	Session.changed.connect(_update_field_environment)
	_update_field_environment()
	Session.changed.connect(_update_community_environment)
	_update_community_environment()
	Session.changed.connect(_update_flight_gates)
	Session.changed.connect(_update_pack_environment)
	Session.changed.connect(_update_trial_environment)
	Session.changed.connect(_update_commission_environment)
	_update_commission_environment()
	_update_trial_environment()
	_update_pack_environment()
	_update_flight_gates()

func _process(delta: float) -> void:
	time += delta
	_update_tracking()
	if Session.running and player.health > 0:
		Session.advance_world(delta)
		player.sync_form_geometry()
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
	if is_instance_valid(rescue_engine) and rescue_engine.dangerous(player.position): return false
	if is_instance_valid(boss) and (boss.awaiting_record or boss.engaged): return false
	if is_instance_valid(bell) and (bell.awaiting_record or bell.engaged): return false
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
	if is_instance_valid(bell) and bell.awaiting_record and player.position.distance_to(bell.position) < 80:
		return "KNELL_RECORD"
	for id in knell_plaques:
		if player.position.distance_to(knell_plaques[id].position) < 45: return "KNELL_PLAQUE_" + id.to_upper()
	if is_instance_valid(delve_stairs) and player.position.distance_to(delve_stairs.position) < 50:
		return "DELVE_DESCEND" if delve_stairs.open else "DELVE_STAIRS"
	if is_instance_valid(delve_note) and player.position.distance_to(delve_note.position) < 45: return "DELVE_NOTE"
	for kind in trial_markers:
		if player.position.distance_to(trial_markers[kind].position) < 48:
			return "TRIAL_SITE_" + kind.to_upper()
	if merchant.visible and player.position.distance_to(merchant.position) < 45:
		return "MERCHANT_NAME" if Schedule.shop_open(Session.world_state.minutes) else "MERCHANT_CLOSED"
	if keeper.visible and player.position.distance_to(keeper.position) < 50:
		return "KEEPER_NAME"
	if wayfarer.visible and player.position.distance_to(wayfarer.position) < 45:
		return "AID_NAME"
	if is_instance_valid(preparation_route) and "prep:accepted" in Session.gathered:
		if preparation_route.pending and player.position.distance_to(Preparation.CONTROLS.finish) < 45: return "PREP_SITE_RETRY"
		for id in ["north", "south", "gate"]:
			if player.position.distance_to(Preparation.CONTROLS[id]) < 45: return "PREP_SITE_" + id.to_upper()
	if is_instance_valid(rescue_engine):
		if rescue_engine.pending and player.position.distance_to(Rescue.EXIT) < 75: return "RESCUE_RETRY_SITE"
		for side in rescue_coils:
			if player.position.distance_to(Rescue.COILS[side]) < 48: return "RESCUE_COIL_" + side.to_upper()
	for kind in ["warden", "wright", "tender", "tracker", "host", "mentor", "witness", "roadkeeper", "crafter", "archivist", "steward"]:
		if npcs[kind].visible and player.position.distance_to(npcs[kind].position) < 48:
			return kind.to_upper() + "_NAME"
	for id in junction_objects:
		if player.position.distance_to(junction_objects[id].position) < 45: return "JOINT_SITE_" + id.to_upper()
	for id in city_objects:
		if player.position.distance_to(city_objects[id].position) < 45: return "CITY_SITE_" + id.to_upper()
	for i in forest_signs.size():
		if player.position.distance_to(forest_signs[i].position) < 45: return "FOREST_SITE_%d" % i
	for id in campaign_devices:
		if player.position.distance_to(campaign_devices[id].position) < 45: return "STORY_SITE_" + id.to_upper()
	for id in field_devices:
		if player.position.distance_to(field_devices[id].position) < 45: return "FIELD_SITE_" + id.to_upper()
	for target in community_markers:
		if player.position.distance_to(community_markers[target].position) < 45: return "COMMUNITY_SITE_" + target.to_upper()
	for target in pack_markers:
		if player.position.distance_to(pack_markers[target].position) < 45: return "PACK_SITE_" + target.to_upper()
	for target in commission_markers:
		if player.position.distance_to(commission_markers[target].position) < 45:
			return "COMMISSION_" + target.to_upper()
	for marker in salvage_markers:
		if marker.visible and player.position.distance_to(marker.position) < 30:
			return "SCRAP"
	if Regions.camps(Session.region, Session.opened).any(func(point): return player.position.distance_to(point) < 45):
		return "REST"
	if lantern.visible and player.position.distance_to(lantern.position) < 40:
		return "LANTERN"
	if event_marker.visible and player.position.distance_to(event_marker.position) < 45:
		return "ENCOUNTER"
	for herb in herbs:
		if herb.visible and player.position.distance_to(herb.position) < 30:
			return "HERB"
	for chest in chests:
		if chest.visible and chest.get_meta("definition").id not in Session.opened and player.position.distance_to(chest.position) < 40:
			return "CHEST"
	for portal in Regions.exits(Session.region):
		if player.position.distance_to(portal.point) < 55:
			return portal.label
	return ""

func interact() -> void:
	_update_tracking()
	_sync_context()
	var key := nearby_key()
	if key == "KNELL_RECORD":
		record_bell_victory()
		return
	if key.begins_with("KNELL_PLAQUE_"):
		if Session.nature.form != "human": Session.notice.emit("NATURE_RETURN_FORM")
		else: dialog_requested.emit("knell:plaque_" + key.trim_prefix("KNELL_PLAQUE_").to_lower())
		return
	if key == "DELVE_DESCEND":
		travel_requested.emit(Delve.region(Delve.depth_of(Session.region) + 1), Vector2(250, 680))
		return
	if key == "DELVE_STAIRS":
		Session.notice.emit("DELVE_STAIRS_SEALED")
		return
	if key == "DELVE_NOTE":
		dialog_requested.emit("delve:note")
		return
	if key == "TO_UNDERCROFT" and not Knell.can_enter(Session.gathered):
		Session.notice.emit("KNELL_DOOR_LOCKED")
		return
	if Accord.ready(Session.gathered, Session.opened) and (key == "MENTOR_NAME" or (Session.region == "rotunda" and key in ["STEWARD_NAME", "WITNESS_NAME", "CRAFTER_NAME", "JOINT_SITE_TABLE"])):
		var target := "table" if key == "JOINT_SITE_TABLE" else key.trim_suffix("_NAME").to_lower()
		dialog_requested.emit("accord:" + target)
		return
	if key == "RESCUE_RETRY_SITE":
		rescue_engine.retry()
		return
	if key.begins_with("RESCUE_COIL_"):
		if not rescue_action("manual_" + key.trim_prefix("RESCUE_COIL_").to_lower()): Session.notice.emit("RESCUE_WORK_BLOCKED")
		return
	if key == "MENTOR_NAME" and "preparation_report" in Session.opened:
		dialog_requested.emit("rescue:mentor")
		return
	if key.begins_with("PREP_SITE_"):
		var target := key.trim_prefix("PREP_SITE_").to_lower()
		if target == "retry": preparation_route.activate()
		elif target in ["north", "south"]:
			if not preparation_action("tune_" + target): Session.notice.emit("PREP_LOCKED")
		else: dialog_requested.emit("preparation:gate")
		return
	if "junction_report" in Session.opened and (key == "STEWARD_NAME" or ("prep:accepted" in Session.gathered and key in ["WITNESS_NAME", "CRAFTER_NAME", "MENTOR_NAME", "JOINT_SITE_TABLE"])):
		var target := "table" if key == "JOINT_SITE_TABLE" else key.trim_suffix("_NAME").to_lower()
		dialog_requested.emit("preparation:" + target)
		return
	if key == "STEWARD_NAME" or (key == "MENTOR_NAME" and (Session.region == "rotunda" or Junction.ready(Session.opened))) or key.begins_with("JOINT_SITE_"):
		var target := key.trim_suffix("_NAME").to_lower() if key.ends_with("_NAME") else key.trim_prefix("JOINT_SITE_").to_lower()
		if target == "console" and Junction.stage(Session.gathered, Session.opened) == 2 and Session.gathered.any(func(flag): return flag in Junction.METHODS):
			junction_objects.console.activate()
		else: dialog_requested.emit("junction:" + ("invite" if target == "mentor" and Session.region == "workshop" else target))
		return
	if key in ["CRAFTER_NAME", "ARCHIVIST_NAME"] or key.begins_with("CITY_SITE_"):
		var target := key.trim_suffix("_NAME").to_lower() if key.ends_with("_NAME") else key.trim_prefix("CITY_SITE_").to_lower()
		if key.ends_with("_NAME") and Session.nature.form != "human": dialog_requested.emit("reaction:" + target)
		else: dialog_requested.emit("city:" + target)
		return
	if key == "ROADKEEPER_NAME" or key.begins_with("FOREST_SITE_"):
		if key == "ROADKEEPER_NAME" and Session.nature.form != "human": dialog_requested.emit("reaction:roadkeeper")
		else: dialog_requested.emit("forest:roadkeeper" if key == "ROADKEEPER_NAME" else "forest:" + key.trim_prefix("FOREST_SITE_"))
		return
	if key in ["MENTOR_NAME", "WITNESS_NAME"] or key.begins_with("STORY_SITE_"):
		var target := key.trim_suffix("_NAME").to_lower() if key.ends_with("_NAME") else key.trim_prefix("STORY_SITE_").to_lower()
		if key.ends_with("_NAME") and Session.nature.form != "human": dialog_requested.emit("reaction:" + target)
		else: dialog_requested.emit("story:" + target)
		return
	if key.begins_with("FIELD_SITE_"):
		dialog_requested.emit("field:" + key.trim_prefix("FIELD_SITE_").to_lower())
		return
	if key == "HOST_NAME" or key.begins_with("COMMUNITY_SITE_"):
		if key == "HOST_NAME" and Session.nature.form != "human": dialog_requested.emit("reaction:host")
		else: dialog_requested.emit("community:" + ("host" if key == "HOST_NAME" else key.trim_prefix("COMMUNITY_SITE_").to_lower()))
		return
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
				if chest.visible and player.position.distance_to(chest.position) < 40 and chest.get_meta("definition").id not in Session.opened:
					if Session.claim_chest(chest.get_meta("definition"), player.position, player_vitals()):
						chest.modulate = Color("6d7770")
						var claimed: String = chest.get_meta("definition").id
						if claimed.begins_with("delve_keystone_"): Session.notice.emit("DELVE_COMPLETE" if claimed == Delve.keystone(Delve.DEPTHS) else "DELVE_STAIRS_OPEN")
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
	if Session.nature.form in ["bat", "mist"]: return
	for side in rescue_coils:
		var offset: Vector2 = Rescue.COILS[side] - origin
		if offset.length() < player.weapon_stats().reach and offset.normalized().dot(direction) > 0.15 and navigation.segment_clear(origin, Rescue.COILS[side]): rescue_action("claw_" + side, true)
	for child in get_children():
		if child is Enemy:
			var offset: Vector2 = child.global_position - origin
			if offset.length() < player.weapon_stats().reach and offset.normalized().dot(direction) > 0.15 and navigation.segment_clear(origin, child.global_position):
				var before: float = child.health
				child.receive_damage(player.weapon_stats().damage + 4 * int(Session.skills.get("sword", 0)), direction)
				# The bell tongue's heavy note briefly staggers whoever it actually strikes.
				var stagger: float = Gear.weapon(Session.equipped).get("stagger", 0.0) if Session.nature.form == "human" else 0.0
				if stagger > 0 and is_instance_valid(child) and child.health > 0 and child.health < before: child.apply_slow(stagger, 0.6)

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
	if kind == "frost":
		var spell := Magic.profile(kind, Session.skills)
		bolt.slow_duration = spell.slow_duration
		bolt.slow_multiplier = spell.slow_multiplier
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
			if Session.region == "underhall" and npc.kind == "mentor":
				npc.walk_speed = 75
				var follow: bool = Rescue.stage(Session.gathered, Session.opened) == 3 and Session.nature.form == "human" and player.health > 0 and safe_to_rest()
				var distance: float = npc.position.distance_to(player.position)
				npc.set_destination(player.position if follow and distance > 55 and distance < 280 else npc.position)
				continue
			if Session.region == "rotunda" and npc.kind in ["witness", "crafter"]:
				npc.walk_speed = 85
				npc.set_destination(Preparation.post(Session.gathered, npc.kind))
				continue
			if Session.region == "velshof" and npc.kind in ["crafter", "archivist"] and "city:outcome:shared" in Session.gathered:
				npc.set_destination(Vector2(780, 680) if npc.kind == "crafter" else Vector2(930, 680))
				continue
			if npc.kind == "roadkeeper" and Forest.stage(Session.gathered, Session.opened) > 0:
				_update_escort(npc)
				continue
			npc.set_destination(Schedule.destination(Session.region, npc.kind, Session.world_state.minutes, Session.aid_quest))

func _sync_context() -> void:
	for npc in npcs.values():
		if is_instance_valid(npc) and npc.visible:
			Session.world_state.npcs[Session.region + ":" + npc.kind] = [npc.position.x, npc.position.y]

func can_wait() -> bool:
	return Session.nature.form == "human" and player.health > 0 and Regions.camps(Session.region, Session.opened).any(func(point): return player.position.distance_to(point) < 45) and safe_to_rest()

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
	if Session.nature.kind == "vampire" and "rescue:boundary:keep" in Session.gathered and npcs.mentor.visible and player.position.distance_to(npcs.mentor.position) < 500:
		tracking_cue.visible = true
		tracking_cue.position = player.position + Vector2(0, -12)
		tracking_cue.direction = player.position.direction_to(npcs.mentor.position)
		tracking_cue.queue_redraw()
		return
	tracking_cue.visible = player.can_track() and nearest != Vector2.INF
	if tracking_cue.visible:
		tracking_cue.position = player.position + Vector2(0, -12)
		tracking_cue.direction = player.position.direction_to(nearest)
		tracking_cue.queue_redraw()
func _on_howl(origin: Vector2) -> void:
	for child in get_children():
		if child is Enemy and child.health > 0 and child.position.distance_to(origin) < 150 and navigation.segment_clear(origin, child.position):
			child.apply_slow(3, 0.55)
			if child is EchoEnemy: child.disrupt()
	_update_tracking()

func landing_safe(point: Vector2) -> bool:
	for zone in definition.get("landing_zones", []):
		if zone.rect.grow(10).has_point(point) and zone.opens not in Session.opened: return false
	return true
func _update_flight_gates() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	var changed := false
	for body in get_children():
		if body is StaticBody2D and body.has_meta("flight_gate") and body.get_meta("flight_gate") in Session.opened:
			remove_child(body)
			body.queue_free()
			changed = true
	if changed: navigation.configure(self)
	landscape.queue_redraw()

func can_community(event: String) -> bool:
	if not Community.SITES.has(event) or player.health <= 0 or not safe_to_rest(): return false
	var site: Array = Community.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("community_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 48 and not Community.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, Session.gear_owned, Session.world_state.reputation, player.mana, event).is_empty()
func community_action(event: String) -> bool:
	if not can_community(event): return false
	_sync_context()
	if not Session.community_event(event, player.position, player_vitals()): return false
	player.mana = Session.vitals.mana
	return true
func _update_community_environment() -> void:
	if is_instance_valid(community_delivery): community_delivery.visible = Community.stage(Session.gathered) >= 3
	for target in community_markers:
		community_markers[target].done = "community:seen:" + target in Session.gathered if target != "search" else Community.stage(Session.gathered) >= 3
		community_markers[target].queue_redraw()

func can_learn_skill(id: String) -> bool:
	return player.health > 0 and safe_to_rest() and Session.can_learn_skill(id)
func learn_skill(id: String) -> bool:
	if not can_learn_skill(id):
		Session.notice.emit("LEARN_UNAVAILABLE")
		return false
	_sync_context()
	return Session.learn_skill(id, player.position, player_vitals())

func can_field(id: String, method: String) -> bool:
	if Session.region != "haven" or player.health <= 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var point: Vector2 = npcs.host.position if id in ["accept", "report"] else definition.get("field_sites", {}).get(id, Vector2.INF)
	if player.position.distance_to(point) >= 48 or not navigation.segment_clear(player.position, point): return false
	return not Field.resolve(Session.nature, Session.skills, Session.gathered, Session.opened, player_vitals(), Session.world_state.minutes, id, method, player.magic_cooldown, player.shield_recharge).is_empty()
func field_action(id: String, method: String) -> bool:
	if not can_field(id, method): return false
	_sync_context()
	var result := Session.field_event(id, method, player.position, player_vitals(), player.magic_cooldown, player.shield_recharge)
	if result.is_empty(): return false
	player.mana = Session.vitals.mana
	player.stamina = Session.vitals.stamina
	player.advance_timers(result.elapsed)
	player.magic_cooldown = maxf(player.magic_cooldown, result.cooldown)
	player.shield_recharge = maxf(player.shield_recharge, result.recharge)
	if field_devices.has(id):
		field_devices[id].pulse(method)
		Sound.play_at("magic" if method != "manual" else "collect", player.position)
	player.stats_changed.emit()
	return true
func _update_field_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	var changed := false
	for body in get_children():
		if body is StaticBody2D and body.has_meta("field_gate") and body.get_meta("field_gate") in Session.opened:
			remove_child(body)
			body.queue_free()
			changed = true
	if changed: navigation.configure(self)
	for id in field_devices:
		field_devices[id].progress = Field.progress(Session.gathered, id)
		field_devices[id].queue_redraw()
	for chest in chests:
		var entry: Dictionary = chest.get_meta("definition")
		if entry.has("requires_opened"): chest.visible = entry.requires_opened.all(func(flag): return flag in Session.opened)
	landscape.queue_redraw()

func can_campaign(event: String) -> bool:
	if not Campaign.SITES.has(event) or player.health <= 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var site: Array = Campaign.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("story_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 48 and navigation.segment_clear(player.position, point) and not Campaign.resolve(Session.nature, Session.quest, Session.gathered, Session.opened, Session.inventory, player_vitals(), event).is_empty()
func campaign_action(event: String) -> bool:
	if not can_campaign(event): return false
	_sync_context()
	if not Session.campaign_event(event, player.position, player_vitals()): return false
	player.mana = Session.vitals.mana
	player.stamina = Session.vitals.stamina
	Sound.play_at("collect", player.position)
	player.stats_changed.emit()
	return true
func _update_campaign_environment() -> void:
	for device in campaign_devices.values():
		device.settings = Campaign.positions(Session.gathered)
		device.resolved = Campaign.stage(Session.gathered, Session.opened) >= 4
		device.queue_redraw()

func _update_escort(npc: CharacterBody2D) -> void:
	var current := Forest.stage(Session.gathered, Session.opened)
	if current == 3:
		npc.set_destination(Vector2(430, 780) if Forest.OUTCOMES[0] in Session.gathered else Vector2(1640, 620))
		return
	if current == 2:
		npc.set_destination(Forest.POINTS[2] - Vector2(65, 0))
		return
	npc.walk_speed = 90 if Session.gathered.any(func(flag): return flag in Forest.AIDS) else 70
	var distance: float = npc.position.distance_to(player.position)
	if player.health <= 0 or not safe_to_rest() or distance > 220 or distance < 65:
		npc.set_destination(npc.position)
	elif npc.destination.distance_to(player.position) > 30:
		npc.set_destination(player.position)

func can_forest(event: String) -> bool:
	if Session.region != "woodroad" or player.health <= 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var point: Vector2 = npcs.roadkeeper.position
	if event in ["work", "howl"]:
		var step := Forest.progress(Session.gathered)
		if step >= 3: return false
		point = Forest.POINTS[step]
		if npcs.roadkeeper.position.distance_to(point) > 90 or not navigation.segment_clear(point, npcs.roadkeeper.position): return false
	if player.position.distance_to(point) >= 48 or not navigation.segment_clear(player.position, point): return false
	return not Forest.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, player_vitals(), event).is_empty()

func forest_action(event: String) -> bool:
	if not can_forest(event): return false
	_sync_context()
	if not Session.forest_event(event, player.position, player_vitals()): return false
	player.stamina = Session.vitals.stamina
	player.mana = Session.vitals.mana
	player.stats_changed.emit()
	Sound.play_at("collect", player.position)
	return true

func _update_forest_environment() -> void:
	if not is_inside_tree() or Session.region != "woodroad" or landscape.region != Session.region: return
	var removed := false
	for body in get_children():
		if body is StaticBody2D and body.has_meta("forest_gate") and Forest.PASSAGE in Session.opened:
			remove_child(body)
			body.queue_free()
			removed = true
	if removed: navigation.configure(self)
	for i in forest_signs.size():
		forest_signs[i].repaired = i < Forest.progress(Session.gathered)
		forest_signs[i].outcome = "commons" if Forest.OUTCOMES[0] in Session.gathered else ("watch" if Forest.OUTCOMES[1] in Session.gathered else "")
		forest_signs[i].queue_redraw()
	landscape.queue_redraw()

func can_city(event: String) -> bool:
	if Session.region != "velshof" or not City.SITES.has(event) or player.health <= 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var target: String = City.SITES[event]
	var point: Vector2 = npcs[target].position if npcs.has(target) and npcs[target].visible else definition.get("city_sites", {}).get(target, Vector2.INF)
	return player.position.distance_to(point) < 48 and navigation.segment_clear(player.position, point) and not City.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, player_vitals(), Session.world_state.minutes, event).is_empty()
func city_action(event: String) -> bool:
	if not can_city(event): return false
	_sync_context()
	var result := Session.city_event(event, player.position, player_vitals())
	if result.is_empty(): return false
	player.mana = Session.vitals.mana
	player.stamina = Session.vitals.stamina
	player.advance_timers(result.elapsed)
	player.stats_changed.emit()
	Sound.play_at("collect", player.position)
	return true
func _update_city_environment() -> void:
	for object in city_objects.values():
		object.plan = City.draft(Session.gathered)
		object.signatures = Session.gathered.filter(func(flag): return flag in City.SIGNATURES).size()
		object.completed = City.REPORT in Session.opened
		object.worked = Session.gathered.any(func(flag): return flag in City.WORK)
		object.queue_redraw()

func can_measure() -> bool:
	if not Session.running or Session.region != "rotunda" or not junction_objects.has("console") or player.health <= 0 or player.dodge_time > 0 or player.attack_time > 0 or Session.nature.form != "human" or not safe_to_rest(): return false
	var point: Vector2 = junction_objects.console.position
	return Junction.stage(Session.gathered, Session.opened) == 2 and Session.gathered.any(func(flag): return flag in Junction.METHODS) and player.position.distance_to(point) < 48 and navigation.segment_clear(player.position, point)
func can_junction(event: String) -> bool:
	if not Junction.SITES.has(event) or player.health <= 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var site: Array = Junction.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("junction_sites", {}).get(site[1], Vector2.INF)
	if player.position.distance_to(point) >= 48 or not navigation.segment_clear(player.position, point): return false
	var measured := 0.0
	if event == "prove":
		if not can_measure() or not (junction_objects.console.active or junction_objects.console.pending): return false
		measured = junction_objects.console.progress
	return not Junction.resolve(Session.nature, Session.skills, Session.gathered, Session.opened, Session.inventory, player_vitals(), event, player.magic_cooldown, player.shield_recharge, measured).is_empty()
func junction_action(event: String) -> bool:
	if not can_junction(event): return false
	_sync_context()
	var measured: float = junction_objects.console.progress if event == "prove" else 0.0
	var result := Session.junction_event(event, player.position, player_vitals(), player.magic_cooldown, player.shield_recharge, measured)
	if result.is_empty(): return false
	player.mana = Session.vitals.mana
	player.stamina = Session.vitals.stamina
	player.magic_cooldown = maxf(player.magic_cooldown, result.cooldown)
	player.shield_recharge = maxf(player.shield_recharge, result.recharge)
	player.stats_changed.emit()
	Sound.play_at("collect", player.position)
	return true
func _update_junction_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	if definition.has("mentor") and Session.region in ["workshop", "rotunda"]:
		npcs.mentor.visible = ("junction:accepted" in Session.gathered) if Session.region == "rotunda" else ("junction:accepted" not in Session.gathered)
	for object in junction_objects.values():
		object.records = Session.opened.filter(func(flag): return flag in Junction.RECORDS).size()
		object.isolated = Session.gathered.any(func(flag): return flag in Junction.METHODS)
		object.proved = "junction:proof" in Session.gathered
		object.outcome = "public" if Junction.CHOICES[0] in Session.gathered else ("private" if Junction.CHOICES[1] in Session.gathered else "")
		if object.kind == "console" and object.active and not object.proved and not can_measure(): object.cancel_measure()
		object.queue_redraw()

func can_rehearse() -> bool:
	if Session.region != "rotunda" or not is_instance_valid(preparation_route) or not Session.running or player.health <= 0 or player.attack_time > 0 or player.dodge_time > 0 or Session.nature.form != "human" or not safe_to_rest(): return false
	if "prep:accepted" not in Session.gathered or "prep:tested" in Session.gathered or not Preparation.configured(Session.gathered): return false
	for role in ["witness", "crafter"]:
		var npc: CharacterBody2D = npcs[role]
		var point: Vector2 = Preparation.post(Session.gathered, role)
		if not npc.visible or npc.position.distance_to(point) >= 24 or not navigation.segment_clear(npc.position, Preparation.CONTROLS.gate): return false
	return true
func start_preparation() -> bool:
	if not can_rehearse() or player.position.distance_to(Preparation.CONTROLS.gate) >= 48: return false
	preparation_route.activate()
	return true
func can_preparation(event: String) -> bool:
	if not Preparation.SITES.has(event) or player.health <= 0 or player.attack_time > 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var site: Array = Preparation.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else (definition.get("junction_sites", {}).get(site[1], Preparation.CONTROLS.get(site[1], Vector2.INF)))
	if player.position.distance_to(point) >= 48 or not navigation.segment_clear(player.position, point): return false
	if event == "prove" and (not can_rehearse() or preparation_route.step != Preparation.ROUTE.size() or not (preparation_route.active or preparation_route.pending)): return false
	return not Preparation.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, player_vitals(), event, event == "prove").is_empty()
func preparation_action(event: String) -> bool:
	if not can_preparation(event): return false
	_sync_context()
	if not Session.preparation_event(event, player.position, player_vitals(), event == "prove"): return false
	if is_instance_valid(preparation_route) and event != "prove": preparation_route.cancel()
	player.stats_changed.emit()
	Sound.play_at("collect", player.position)
	return true
func _update_preparation_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	for role in ["witness", "crafter"]:
		if not definition.has(role): continue
		var invited: bool = "prep:consent:" + role in Session.gathered
		npcs[role].visible = invited if Session.region == "rotunda" else not invited
	if is_instance_valid(preparation_route):
		if preparation_route.active and "prep:tested" not in Session.gathered and not can_rehearse(): preparation_route.cancel()
		preparation_route.queue_redraw()
	_update_npcs()

func can_rescue(event: String, impact: bool = false) -> bool:
	if player.health <= 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var parts := event.split("_")
	var cutting: bool = parts.size() == 2 and parts[0] in ["manual", "light", "claw"] and Rescue.COILS.has(parts[1])
	var calm := false
	if cutting:
		if Session.region != "underhall" or not is_instance_valid(rescue_engine): return false
		var point: Vector2 = Rescue.COILS[parts[1]]
		if player.position.distance_to(point) >= (520 if parts[0] == "light" else 60) or not navigation.segment_clear(player.position, point): return false
		if parts[0] == "manual" and player.attack_time > 0: return false
		calm = rescue_engine.phase(parts[1]) == 2
	else:
		if not Rescue.SITES.has(event) or Session.region != Rescue.SITES[event][0]: return false
		var target: String = Rescue.SITES[event][1]
		var point: Vector2 = Rescue.EXIT if target == "exit" else (npcs.mentor.position if npcs.mentor.visible else Vector2.INF)
		if player.position.distance_to(point) >= (75 if event == "safe" else 48) or not navigation.segment_clear(player.position, point): return false
		if event == "safe" and not rescue_engine.arrived(): return false
	return not Rescue.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, player_vitals(), event, calm, impact, event == "safe").is_empty()
func rescue_action(event: String, impact: bool = false) -> bool:
	if not can_rescue(event, impact): return false
	_sync_context()
	var parts := event.split("_")
	var calm: bool = is_instance_valid(rescue_engine) and parts.size() == 2 and Rescue.COILS.has(parts[1]) and rescue_engine.phase(parts[1]) == 2
	if not Session.rescue_event(event, player.position, player_vitals(), calm, impact, event == "safe"): return false
	player.stamina = Session.vitals.stamina
	player.stats_changed.emit()
	Sound.play_at("collect", player.position)
	return true
func _update_rescue_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	var stage := Rescue.stage(Session.gathered, Session.opened)
	if definition.has("mentor"):
		if Session.region == "underhall": npcs.mentor.visible = stage in [1, 2, 3]
		elif Session.region == "crossing": npcs.mentor.visible = stage == 5
		elif stage > 0: npcs.mentor.visible = Session.region == "rotunda" and stage == 4
	if Session.region == "underhall" and Rescue.disconnected(Session.gathered):
		var removed := false
		for body in get_children():
			if body is StaticBody2D and body.has_meta("rescue_gate"):
				remove_child(body)
				body.queue_free()
				removed = true
		if removed: navigation.configure(self)
	landscape.queue_redraw()
	_update_npcs()

func can_accord(event: String) -> bool:
	if not Accord.SITES.has(event) or player.health <= 0 or player.attack_time > 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var site: Array = Accord.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("junction_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 48 and navigation.segment_clear(player.position, point) and not Accord.resolve(Session.nature, Session.gathered, Session.opened, Session.inventory, player_vitals(), event).is_empty()
func accord_action(event: String) -> bool:
	if not can_accord(event): return false
	_sync_context()
	if not Session.accord_event(event, player.position, player_vitals()): return false
	Sound.play_at("collect", player.position)
	return true
func _update_accord_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	AccordChanges.apply(self)
	for chest in chests:
		if Accord.CACHES.values().any(func(entry): return entry.id == chest.get_meta("definition").id): chest.visible = "accord_community" in Session.opened
	landscape.queue_redraw()

func can_knell(event: String) -> bool:
	if not Knell.SITES.has(event) or player.health <= 0 or player.attack_time > 0 or player.dodge_time > 0 or not safe_to_rest(): return false
	var site: Array = Knell.SITES[event]
	if Session.region != site[0]: return false
	var point: Vector2 = npcs[site[1]].position if npcs.has(site[1]) and npcs[site[1]].visible else definition.get("knell_sites", {}).get(site[1], Vector2.INF)
	return player.position.distance_to(point) < 52 and navigation.segment_clear(player.position, point) and not Knell.resolve(Session.nature, Session.gathered, Session.defeated, Session.opened, Session.inventory, Session.gear_owned, player_vitals(), event, Session.region).is_empty()
func knell_action(event: String) -> bool:
	if not can_knell(event): return false
	_sync_context()
	if not Session.knell_event(event, player.position, player_vitals()): return false
	Sound.play_at("collect", player.position)
	if event.begins_with("read_") and Knell.armed(Session.gathered, Session.defeated): Session.notice.emit("KNELL_GRATE_OPEN")
	return true
func record_bell_victory() -> void:
	if not is_instance_valid(bell) or not bell.awaiting_record or player.health <= 0: return
	_sync_context()
	if Session.knell_event("silence", player.position, player_vitals()):
		bell.queue_free()
		bell = null
func _update_knell_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	for id in knell_plaques:
		knell_plaques[id].read = "knell:plaque:" + id in Session.gathered
		knell_plaques[id].queue_redraw()
	if is_instance_valid(bell): bell.armed = Knell.armed(Session.gathered, Session.defeated)
	if Session.region == Knell.REGION and not Undercroft.grate_closed():
		var removed := false
		for body in get_children():
			if body is StaticBody2D and body.has_meta("knell_grate"):
				remove_child(body)
				body.queue_free()
				removed = true
		if removed: navigation.configure(self)
	landscape.queue_redraw()

func _update_delve_environment() -> void:
	if not is_inside_tree() or landscape.region != Session.region: return
	if is_instance_valid(delve_stairs):
		delve_stairs.open = Delve.keystone(Delve.depth_of(Session.region)) in Session.opened
		delve_stairs.queue_redraw()
