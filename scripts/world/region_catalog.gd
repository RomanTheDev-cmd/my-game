extends RefCounted

const REGIONS := {
	"crossing": {
		"extra_exits": [{"point": Vector2(1120, 425), "destination": "undercroft", "arrival": Vector2(240, 650), "label": "TO_UNDERCROFT", "direction": -1}],
		"location": "LOCATION", "description": "REGION", "camp": Vector2(440, 470),
		"event_point": Vector2(650, 600), "merchant": Vector2(235, 500), "keeper": Vector2(520, 490), "mentor": Vector2(600, 600), "exit": Vector2(1800, 500), "destination": "lake",
		"arrival": Vector2(230, 650), "exit_label": "TO_LAKE",
		"herbs": [Vector2(650, 670), Vector2(930, 680), Vector2(1200, 700)],
		"enemies": [["road_1", Vector2(970, 550)], ["road_2", Vector2(1240, 530)], ["road_3", Vector2(1430, 640)]]
	},
	"lake": {
		"location": "LOCATION_LAKE", "description": "REGION_LAKE", "camp": Vector2(360, 610),
		"extra_exits": [{"point": Vector2(1750, 340), "destination": "terrace", "arrival": Vector2(240, 650), "label": "TO_TERRACE", "direction": 1}, {"point": Vector2(135, 1000), "destination": "haven", "arrival": Vector2(240, 650), "label": "TO_HAVEN", "direction": -1}, {"point": Vector2(1800, 650), "destination": "ruins", "arrival": Vector2(260, 650), "label": "TO_RUINS", "direction": 1},
			{"point": Vector2(1750, 1120), "destination": "workshop", "arrival": Vector2(240, 650), "label": "TO_WORKSHOP", "direction": 1}],
		"event_point": Vector2(690, 700), "wayfarer": Vector2(480, 620), "exit": Vector2(135, 650), "destination": "crossing", "arrival": Vector2(1730, 500), "exit_label": "TO_CROSSING",
		"herbs": [Vector2(600, 650), Vector2(1100, 880), Vector2(1500, 750)],
		"enemies": [["lake_1", Vector2(1210, 840)], ["lake_2", Vector2(1510, 860), "ranged"]]
	},
	"workshop": {
		"location": "LOCATION_WORKSHOP", "description": "REGION_WORKSHOP", "camp": Vector2(380, 730),
		"exit": Vector2(135, 650), "destination": "lake", "arrival": Vector2(1800, 1160), "exit_label": "TO_LAKE",
		"extra_exits": [{"point": Vector2(850, 1120), "destination": "rotunda", "arrival": Vector2(240, 650), "label": "TO_ROTUNDA", "direction": 1}, {"point": Vector2(850, 200), "destination": "velshof", "arrival": Vector2(240, 650), "label": "TO_CITY", "direction": 1}, {"point": Vector2(1800, 420), "destination": "waterworks", "arrival": Vector2(240, 650), "label": "TO_WATERWORKS", "direction": 1},
			{"point": Vector2(1780, 1200), "destination": "thicket", "arrival": Vector2(240, 650), "label": "TO_THICKET", "direction": 1}],
		"warden": Vector2(360, 540), "wright": Vector2(570, 540), "tender": Vector2(520, 870), "mentor": Vector2(780, 700),
		"herbs": [Vector2(580, 850), Vector2(780, 1080)],
		"enemies": [["workshop_1", Vector2(1230, 800)], ["workshop_archer", Vector2(1550, 900), "ranged"]],
		"commission_sites": {"wheel": Vector2(960, 600), "archive": Vector2(1450, 460), "workbench": Vector2(680, 600), "cache": Vector2(1540, 1050)},
		"salvage": [{"id": "workshop:scrap_1", "point": Vector2(730, 450)}, {"id": "workshop:scrap_2", "point": Vector2(860, 900)}, {"id": "workshop:scrap_3", "point": Vector2(1320, 360)}]
	},
	"thicket": {
		"extra_exits": [{"point": Vector2(1750, 620), "destination": "woodroad", "arrival": Vector2(240, 620), "label": "TO_WOODROAD", "direction": 1}],
		"location": "LOCATION_THICKET", "description": "REGION_THICKET", "camp": Vector2(350, 760), "tracker": Vector2(450, 600),
		"exit": Vector2(135, 650), "destination": "workshop", "arrival": Vector2(1820, 1190), "exit_label": "TO_WORKSHOP",
		"herbs": [Vector2(610, 850), Vector2(1250, 1080)],
		"enemies": [["thicket_1", Vector2(1600, 320)], ["thicket_2", Vector2(1450, 1080)]],
		"pack_sites": {"trail_0": Vector2(780, 480), "trail_1": Vector2(1080, 600), "trail_2": Vector2(1390, 740), "den": Vector2(1570, 740)},
		"chests": [{"id": "thicket_cache_0", "point": Vector2(340, 320), "hidden": true, "items": {"coin": 3, "herb": 1}},
			{"id": "thicket_cache_1", "point": Vector2(1210, 380), "hidden": true, "items": {"coin": 3, "herb": 1}},
			{"id": "thicket_cache_2", "point": Vector2(1740, 1080), "hidden": true, "items": {"coin": 3, "herb": 1}}]
	},
	"haven": {
		"location": "LOCATION_HAVEN", "description": "REGION_HAVEN", "camp": Vector2(350, 760), "host": Vector2(440, 600),
		"exit": Vector2(135, 650), "destination": "lake", "arrival": Vector2(240, 1000), "exit_label": "TO_LAKE",
		"herbs": [Vector2(610, 820), Vector2(1270, 900)],
		"enemies": [["haven_1", Vector2(1640, 320)], ["haven_archer", Vector2(1670, 1000), "ranged"]],
		"community_sites": {"supply": Vector2(720, 420), "route": Vector2(1320, 600), "search": Vector2(1450, 860)},
		"field_sites": {"sluice": Vector2(850, 380), "garden": Vector2(790, 1080), "relay": Vector2(1250, 760)},
		"extra_camps": [{"point": Vector2(1120, 860), "requires_opened": "field_relay"}],
		"chests": [{"id": "field_garden_supplies", "point": Vector2(850, 1080), "requires_opened": ["field_garden"], "items": {"herb": 2, "potion": 1}}]
	},
	"terrace": {
		"location": "LOCATION_TERRACE", "description": "REGION_TERRACE", "camp": Vector2(350, 780), "witness": Vector2(440, 600),
		"exit": Vector2(135, 650), "destination": "lake", "arrival": Vector2(1680, 340), "exit_label": "TO_LAKE",
		"extra_camps": [{"point": Vector2(1380, 790), "requires_opened": "accord_renewal"}],
		"herbs": [Vector2(670, 760), Vector2(1450, 880)],
		"enemies": [["terrace_watcher", Vector2(1640, 320)], ["terrace_archer", Vector2(1640, 1050), "ranged"]],
		"story_sites": {"marks": Vector2(1040, 450), "control": Vector2(1380, 650), "shore": Vector2(1160, 820)},
		"chests": [{"id": "terrace_cache", "point": Vector2(1740, 1080), "requires": ["terrace_archer"], "items": {"coin": 9, "potion": 1}}, {"id": "commons_terrace_supplies", "point": Vector2(1380, 790), "requires_opened": ["accord_community"], "items": {"herb": 2, "potion": 1}}]
	},
	"woodroad": {
		"location": "LOCATION_WOODROAD", "description": "REGION_WOODROAD", "camp": Vector2(390, 800), "roadkeeper": Vector2(430, 620),
		"exit": Vector2(135, 620), "destination": "thicket", "arrival": Vector2(1680, 620), "exit_label": "TO_THICKET",
		"extra_camps": [{"point": Vector2(1190, 620), "requires_opened": "accord_renewal"}],
		"herbs": [Vector2(590, 870), Vector2(1740, 1020)],
		"enemies": [["woodroad_guard", Vector2(1750, 1060), "heavy"]],
		"forest_sites": [Vector2(700, 620), Vector2(1020, 780), Vector2(1380, 620)],
		"chests": [{"id": "woodroad_cache", "point": Vector2(1640, 650), "requires_opened": ["forest_passage"], "items": {"herb": 2, "potion": 1}}, {"id": "commons_woodroad_supplies", "point": Vector2(1190, 620), "requires_opened": ["accord_community"], "items": {"herb": 2, "potion": 1}}]
	},
	"velshof": {
		"location": "LOCATION_CITY", "description": "REGION_CITY", "camp": Vector2(350, 840), "crafter": Vector2(500, 620), "archivist": Vector2(1170, 520),
		"exit": Vector2(135, 650), "destination": "workshop", "arrival": Vector2(810, 220), "exit_label": "TO_WORKSHOP",
		"extra_camps": [{"point": Vector2(1100, 880), "requires_opened": "accord_renewal"}],
		"herbs": [Vector2(700, 870), Vector2(1450, 800)],
		"enemies": [["velshof_backstreet", Vector2(1750, 1020)], ["velshof_archer", Vector2(1720, 170), "ranged"]],
		"city_sites": {"board": Vector2(850, 700), "press": Vector2(600, 780), "archive": Vector2(1210, 700)},
		"chests": [{"id": "courtyard_supplies", "point": Vector2(980, 780), "requires_opened": ["city_report"], "items": {"herb": 2, "potion": 1}}, {"id": "commons_velshof_supplies", "point": Vector2(1100, 880), "requires_opened": ["accord_community"], "items": {"herb": 2, "potion": 1}}]
	},
	"rotunda": {
		"extra_exits": [{"point": Vector2(1700, 650), "destination": "underhall", "arrival": Vector2(240, 650), "label": "TO_UNDERHALL", "direction": 1}],
		"indoor": true, "location": "LOCATION_ROTUNDA", "description": "REGION_ROTUNDA", "camp": Vector2(340, 820), "mentor": Vector2(650, 820), "steward": Vector2(1000, 480), "witness": Vector2(480, 430), "crafter": Vector2(480, 940),
		"exit": Vector2(135, 650), "destination": "workshop", "arrival": Vector2(830, 1110), "exit_label": "TO_WORKSHOP",
		"herbs": [Vector2(500, 1020)], "enemies": [],
		"junction_sites": {"table": Vector2(620, 650), "console": Vector2(1200, 650)}
	},
	"underhall": {
		"indoor": true, "location": "LOCATION_UNDERHALL", "description": "REGION_UNDERHALL", "camp": Vector2(340, 820), "mentor": Vector2(1440, 650),
		"exit": Vector2(135, 650), "destination": "rotunda", "arrival": Vector2(1640, 650), "exit_label": "TO_ROTUNDA",
		"herbs": [Vector2(430, 960)], "enemies": []
	},
	"waterworks": {
		"indoor": true, "location": "LOCATION_WATERWORKS", "description": "REGION_WATERWORKS", "camp": Vector2(300, 800),
		"exit": Vector2(135, 650), "destination": "workshop", "arrival": Vector2(1760, 420), "exit_label": "TO_WORKSHOP",
		"herbs": [Vector2(450, 1000)], "enemies": [["waterworks_guardian", Vector2(1350, 650), "boss"]],
		"trial_sites": {"north": Vector2(550, 390), "south": Vector2(690, 1000), "altar": Vector2(820, 650)},
		"landing_zones": [{"rect": Rect2(1540, 250, 180, 150), "opens": "waterworks_flight"}, {"rect": Rect2(780, 930, 230, 170), "opens": "waterworks_mist"}],
		"chests": [{"id": "waterworks_flight", "point": Vector2(1640, 320), "required_form": "bat", "items": {"coin": 6}},
			{"id": "waterworks_mist", "point": Vector2(940, 1011), "required_form": "mist", "items": {"coin": 8}},
			{"id": "waterworks_supplies", "point": Vector2(1660, 1020), "requires": ["waterworks_guardian"], "items": {"coin": 18, "potion": 2}}]
	},
	"undercroft": {
		"indoor": true, "location": "LOCATION_UNDERCROFT", "description": "REGION_UNDERCROFT", "camp": Vector2(330, 820),
		"exit": Vector2(135, 650), "destination": "crossing", "arrival": Vector2(1120, 500), "exit_label": "TO_CROSSING",
		"extra_camps": [{"point": Vector2(1030, 320), "requires_opened": "accord_renewal"}],
		"herbs": [Vector2(420, 1060), Vector2(640, 1080)],
		"enemies": [["undercroft_echo_1", Vector2(700, 500), "echo"], ["undercroft_echo_2", Vector2(980, 660), "echo"], ["undercroft_echo_3", Vector2(900, 1000), "echo"], ["undercroft_bell", Vector2(1455, 705), "bell"]],
		"knell_sites": {"hall": Vector2(430, 330), "gallery": Vector2(650, 300), "ossuary": Vector2(1020, 1100)},
		"chests": [{"id": "knell_supplies", "point": Vector2(330, 480), "requires_opened": ["accord_community"], "items": {"herb": 2, "potion": 1}},
			{"id": "knell_cache", "point": Vector2(1700, 1090), "requires": ["undercroft_bell"], "items": {"coin": 14, "potion": 1}}]
	},
	"ruins": {
		"indoor": true, "location": "LOCATION_RUINS", "description": "REGION_RUINS", "camp": Vector2(290, 870),
		"exit": Vector2(135, 650), "destination": "lake", "arrival": Vector2(1840, 650), "exit_label": "TO_LAKE",
		"herbs": [Vector2(430, 940)],
		"enemies": [["ruins_1", Vector2(780, 650)], ["ruins_2", Vector2(1040, 560), "ranged"], ["ruins_warden", Vector2(1400, 550), "heavy"]],
		"chests": [
			{"id": "ruins_supplies", "point": Vector2(1000, 1020), "items": {"coin": 6, "potion": 2}},
			{"id": "ruins_cache", "point": Vector2(1510, 450), "requires": ["ruins_warden"], "items": {"coin": 18}, "gear": ["chain"]}
		]
	}
}

static func valid(id: String) -> bool:
	return REGIONS.has(id)

static func get_region(id: String) -> Dictionary:
	return REGIONS.get(id, {}).duplicate(true)

static func herb_id(region: String, point: Vector2) -> String:
	var id := "herb_%d_%d" % [point.x, point.y]
	# Keep identifiers from v1 saves unchanged in the original location.
	return id if region == "crossing" else region + ":" + id

static func exits(id: String) -> Array:
	var region := get_region(id)
	if region.is_empty():
		return []
	var result := [{"point": region.exit, "destination": region.destination, "arrival": region.arrival,
		"label": region.exit_label, "direction": 1 if region.exit.x > 960 else -1}]
	result.append_array(region.get("extra_exits", []))
	return result

static func camps(id: String, opened: Array) -> Array[Vector2]:
	var definition := get_region(id)
	var result: Array[Vector2] = []
	if definition.is_empty(): return result
	result.append(definition.camp)
	for entry in definition.get("extra_camps", []):
		if entry.requires_opened in opened: result.append(entry.point)
	return result
