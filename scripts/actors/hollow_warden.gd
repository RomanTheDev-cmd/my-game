extends "res://scripts/actors/heavy_enemy.gd"
# Elite keeper of the deepest hollow: tougher and quicker to strike than an ordinary heavy foe.

func _ready() -> void:
	super._ready()
	max_health = 300
	health = max_health
	attack_damage = 34
	move_speed = 48
	aggro_range = 280
	reward_xp = 90
	coin_reward = 12
	sprite.modulate = Color("9e8fb0")
	sprite.scale = Vector2(1.45, 1.45)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	windup_duration = 0.7 if health < max_health / 2 else 0.9
