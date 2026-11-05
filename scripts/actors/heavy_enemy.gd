extends "res://scripts/actors/enemy.gd"

func _ready() -> void:
	max_health = 180
	attack_damage = 32
	attack_distance = 52
	attack_reach = 66
	windup_duration = 1.0
	recovery_duration = 1.2
	move_speed = 42
	aggro_range = 250
	reward_xp = 60
	coin_reward = 10
	super._ready()
	sprite.scale = Vector2(1.3, 1.3)
	sprite.modulate = Color("b8a8a2")

func _physics_process(delta: float) -> void:
	windup_duration = 0.8 if health < max_health / 2 else 1.0
	super._physics_process(delta)
