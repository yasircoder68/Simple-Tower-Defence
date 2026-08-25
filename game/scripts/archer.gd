extends Area2D

@export var damage: int = 10

@onready var timer = $Timer

func _ready():
	if timer:
		timer.wait_time = timer.wait_time * randf_range(0.95, 1.05)
		timer.stop()
		await get_tree().create_timer(randf_range(0.0, timer.wait_time)).timeout
		if is_instance_valid(timer):
			timer.start()

func _on_timer_timeout():
	var targets = get_overlapping_areas()
	var zombies = []
	for t in targets:
		if t.is_in_group("zombie"):
			zombies.append(t)
			
	if zombies.size() > 0:
		var target = zombies[randi() % zombies.size()]
		var arrow_scene = preload("res://scenes/arrow.tscn")
		var arrow = arrow_scene.instantiate()
		arrow.target = target
		arrow.damage = damage
		get_parent().add_child(arrow)
		arrow.global_position = global_position
