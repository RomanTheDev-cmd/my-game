extends RefCounted

const REGIONS := {
	"crossing": {
		"location": "LOCATION", "description": "REGION", "camp": Vector2(440, 470),
		"event_point": Vector2(650, 600), "merchant": Vector2(235, 500), "keeper": Vector2(520, 490), "exit": Vector2(1800, 500), "destination": "lake",
		"arrival": Vector2(230, 650), "exit_label": "TO_LAKE",
		"herbs": [Vector2(650, 670), Vector2(930, 680), Vector2(1200, 700)],
		"enemies": [["road_1", Vector2(970, 550)], ["road_2", Vector2(1240, 530)], ["road_3", Vector2(1430, 640)]]
	},
	"lake": {
		"location": "LOCATION_LAKE", "description": "REGION_LAKE", "camp": Vector2(360, 610),
		"extra_exits": [{"point": Vector2(1800, 650), "destination": "ruins", "arrival": Vector2(260, 650), "label": "TO_RUINS", "direction": 1}],
		"event_point": Vector2(690, 700), "wayfarer": Vector2(480, 620), "exit": Vector2(135, 650), "destination": "crossing", "arrival": Vector2(1730, 500), "exit_label": "TO_CROSSING",
		"herbs": [Vector2(600, 650), Vector2(1100, 880), Vector2(1500, 750)],
		"enemies": [["lake_1", Vector2(1210, 840)], ["lake_2", Vector2(1510, 860), "ranged"]]
	},
	"ruins": {
		"location": "LOCATION_RUINS", "description": "REGION_RUINS", "camp": Vector2(290, 870),
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
