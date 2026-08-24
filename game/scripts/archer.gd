extends Area2D

@export var damage: int = 10

func _on_timer_timeout():
	var targets = get_overlapping_areas()
	for target in targets:
		if target.is_in_group("zombie"):
			var arrow_scene = preload("res://scenes/arrow.tscn")
			var arrow = arrow_scene.instantiate()
			arrow.target = target
			arrow.global_position = global_position
			get_parent().add_child(arrow)
			break # Shoot one zombie per timeout
