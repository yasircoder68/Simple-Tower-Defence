extends Area2D

@export var speed: float = 200.0
var hp: int = 10

@onready var map = get_parent()

func _physics_process(delta: float) -> void:
	if not map.has_method("get_flow_direction"):
		return
		
	var flow_dir = map.get_flow_direction(global_position)
	
	# If flow_dir is zero, it means we reached the target cell.
	# Walk exactly to the final pixel coordinate!
	if flow_dir == Vector2.ZERO:
		flow_dir = global_position.direction_to(map.end_point.global_position)
		if global_position.distance_to(map.end_point.global_position) < 30.0:
			queue_free()
			return
		
	# Soft separation to act like fluid
	var separation = Vector2.ZERO
	var neighbor_count = 0
	for other in get_overlapping_areas():
		if other != self and other.is_in_group("zombie"):
			var dist = global_position.distance_to(other.global_position)
			if dist < 32.0 and dist > 0:
				# Push away softly
				separation += other.global_position.direction_to(global_position) * (1.0 - (dist / 32.0))
				neighbor_count += 1
				if neighbor_count >= 5: # Limit checks to save FPS in massive swarms!
					break
				
	var desired_dir = (flow_dir + separation * 1.5).normalized()
	if desired_dir == Vector2.ZERO:
		desired_dir = flow_dir
		
	# Move manually
	var step = desired_dir * speed * delta
	var next_pos = global_position + step
	
	# Prevent walking into walls by checking the map
	if not map.is_wall(next_pos):
		global_position = next_pos
	else:
		# Try sliding along X axis
		var next_pos_x = global_position + Vector2(step.x, 0)
		if not map.is_wall(next_pos_x):
			global_position = next_pos_x
		else:
			# Try sliding along Y axis
			var next_pos_y = global_position + Vector2(0, step.y)
			if not map.is_wall(next_pos_y):
				global_position = next_pos_y

func take_damage(amount: int) -> void:
	if hp <= 0: return
	hp -= amount
	if hp <= 0:
		queue_free()

func log_death(reason: String):
	var f = FileAccess.open("user://zombie_death.txt", FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open("user://zombie_death.txt", FileAccess.WRITE)
	f.seek_end()
	f.store_string("Died at " + str(global_position) + " reason: " + reason + "\n")
	f.close()
