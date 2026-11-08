extends RefCounted
const Rules = preload("res://scripts/quests/accord_rules.gd")
const WALLS := {"terrace": Rect2(620, 890, 120, 40), "woodroad": Rect2(1500, 0, 45, 560), "velshof": Rect2(650, 930, 240, 130)}
const PASSAGES := {"terrace": Rect2(644, 890, 72, 40), "woodroad": Rect2(1500, 260, 45, 80), "velshof": Rect2(650, 963, 240, 64)}
const PIECES := {"terrace": [Rect2(620, 890, 24, 40), Rect2(716, 890, 24, 40)], "woodroad": [Rect2(1500, 0, 45, 260), Rect2(1500, 340, 45, 220)], "velshof": [Rect2(650, 930, 240, 33), Rect2(650, 1027, 240, 33)]}
static func parts(region: String, rect: Rect2) -> Array:
	return PIECES[region] if WALLS.has(region) and "accord_release" in Session.opened and rect == WALLS[region] else [rect]
static func apply(world: Node2D) -> void:
	var region: String = world.landscape.region
	if not WALLS.has(region) or "accord_release" not in Session.opened: return
	var removed := false
	for body in world.get_children():
		if not body is StaticBody2D or body.collision_layer & 17 == 0: continue
		for child in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D and Rect2(child.global_position - child.shape.size / 2, child.shape.size) == WALLS[region]:
				world.remove_child(body)
				body.queue_free()
				removed = true
				break
	if not removed: return
	for rect in PIECES[region]:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		body.add_child(collider)
		world.add_child(body)
	world.navigation.configure(world)
