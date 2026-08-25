extends Area2D

@export var damage: int = 10
@export var rate_of_fire: float = 1.0
@export var wizard_radius: float = 100.0
@export var fire_damage_radius: float = 100.0

@onready var collision_shape = $CollisionShape2D
@onready var timer = $Timer

func _ready():
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = wizard_radius
	
	if timer:
		timer.wait_time = rate_of_fire * randf_range(0.95, 1.05)
		timer.stop()
		# Add a random initial delay so they don't fire on the exact same frame
		await get_tree().create_timer(randf_range(0.0, rate_of_fire)).timeout
		if is_instance_valid(timer):
			timer.start()

func _on_timer_timeout():
	var targets = get_overlapping_areas()
	var zombies = []
	for t in targets:
		if t.is_in_group("zombie"):
			zombies.append(t)
			
	if zombies.size() > 0:
		# Pick a random zombie so multiple wizards don't shoot the exact same target
		var target = zombies[randi() % zombies.size()]
		var fire_scene = preload("res://scenes/fire.tscn")
		var fire = fire_scene.instantiate()
		fire.target = target
		fire.damage = damage
		fire.aoe_radius = fire_damage_radius
		get_parent().add_child(fire)
		fire.global_position = global_position
