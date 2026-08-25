extends Area2D

@export var damage: int = 10
@export var rate_of_fire: float = 1.0
@export var wizard_radius: float = 100.0
@export var fire_damage_radius: float = 100.0

@onready var collision_shape = $CollisionShape2D

func _ready():
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = wizard_radius

func _on_timer_timeout():
	var targets = get_overlapping_areas()
	for target in targets:
		if target.is_in_group("zombie"):
			var fire_scene = preload("res://scenes/fire.tscn")
			var fire = fire_scene.instantiate()
			fire.target = target
			fire.damage = damage
			fire.aoe_radius = fire_damage_radius
			get_parent().add_child(fire)
			fire.global_position = global_position
			break # Shoot one fireball per timeout
