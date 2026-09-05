extends Node2D

@export var enemy_count: int = 10
@export var spawn_interval: float = 1.0

@onready var start_point: Marker2D = $StartPoint
@onready var end_point: Marker2D = $EndPoint

func _ready() -> void:
	spawn_enemies()

func get_flow_direction(world_pos: Vector2) -> Vector2:
	if is_instance_valid(end_point):
		# Direction towards end point
		var dir = world_pos.direction_to(end_point.global_position)
		# If very close, stop
		if world_pos.distance_to(end_point.global_position) < 10.0:
			return Vector2.ZERO
		return dir
	return Vector2.ZERO

func is_wall(world_pos: Vector2) -> bool:
	return false

func spawn_enemies() -> void:
	var enemy_scene = preload("res://entities/enemies/goblin/goblin.tscn")
	for i in range(enemy_count):
		var enemy = enemy_scene.instantiate()
		
		# Slight random offset so they don't overlap perfectly
		var random_angle = randf() * TAU
		var random_radius = randf_range(0.0, 20.0)
		
		add_child(enemy)
		enemy.global_position = start_point.global_position + Vector2(cos(random_angle), sin(random_angle)) * random_radius
		
		if spawn_interval > 0.0:
			await get_tree().create_timer(spawn_interval).timeout
