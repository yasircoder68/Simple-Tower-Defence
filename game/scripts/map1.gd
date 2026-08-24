extends Node2D

@export var zombie_count: int = 50
@export var spawn_interval: float = 0.05

@onready var tile_map: TileMap = $my_tiles
@onready var start_point: Marker2D = $StartPoint
@onready var end_point: Marker2D = $EndPoint

var flow_field: Dictionary = {} # Vector2i -> Vector2
var walls_dict: Dictionary = {} # Vector2i -> bool

func _ready() -> void:
	var f = FileAccess.open("res://zcount_debug.txt", FileAccess.WRITE)
	f.store_string("Count: " + str(zombie_count))
	f.close()
	generate_flow_field()
	spawn_zombies()

func generate_flow_field() -> void:
	flow_field.clear()
	walls_dict.clear()
	
	# Get all wall cells
	var used_cells = tile_map.get_used_cells(0)
	for cell in used_cells:
		walls_dict[cell] = true
		
	var target_local = tile_map.to_local(end_point.global_position)
	var target_cell = tile_map.local_to_map(target_local)
	
	var cost_field = {}
	var queue = []
	
	queue.push_back(target_cell)
	cost_field[target_cell] = 0
	
	var rect = tile_map.get_used_rect().grow(15)
	
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
				
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cost = cost_field[current]
		
		for d in dirs:
			var neighbor = current + d
			if not rect.has_point(neighbor):
				continue
			if walls_dict.has(neighbor):
				continue
				
			# Prevent diagonal corner cutting
			if d.x != 0 and d.y != 0:
				if walls_dict.has(current + Vector2i(d.x, 0)) or walls_dict.has(current + Vector2i(0, d.y)):
					continue
					
			var new_cost = current_cost + 1
			if not cost_field.has(neighbor):
				cost_field[neighbor] = new_cost
				queue.push_back(neighbor)
				
	# Generate vectors
	for cell in cost_field.keys():
		if cell == target_cell:
			flow_field[cell] = Vector2.ZERO
			continue
			
		var min_cost = cost_field[cell]
		var best_dir = Vector2.ZERO
		
		for d in dirs:
			var neighbor = cell + d
			if cost_field.has(neighbor):
				var n_cost = cost_field[neighbor]
				if n_cost < min_cost:
					min_cost = n_cost
					best_dir = Vector2(d).normalized()
					
		flow_field[cell] = best_dir

	var f = FileAccess.open("res://flow_debug.txt", FileAccess.WRITE)
	f.store_string("Target Cell: " + str(target_cell) + "\n")
	f.store_string("Rect: " + str(rect) + "\n")
	f.store_string("Flow Field Size: " + str(flow_field.size()) + "\n")
	f.close()

func get_flow_direction(world_pos: Vector2) -> Vector2:
	var local_pos = tile_map.to_local(world_pos)
	var cell = tile_map.local_to_map(local_pos)
	if flow_field.has(cell):
		return flow_field[cell]
	return Vector2.ZERO

func is_wall(world_pos: Vector2) -> bool:
	var local_pos = tile_map.to_local(world_pos)
	var cell = tile_map.local_to_map(local_pos)
	return walls_dict.has(cell)

func spawn_zombies() -> void:
	var zombie_scene = preload("res://scenes/zombie.tscn")
	var f = FileAccess.open("res://zombie_spawn.txt", FileAccess.WRITE)
	f.store_string("Started loop\n")
	for i in range(zombie_count):
		f.store_string("Spawned " + str(i) + "\n")
		f.flush()
		var zombie = zombie_scene.instantiate()
		# They no longer need start_point_path/end_point_path because they just read the flow field!
		# But we still place them at start_point
		
		var random_angle = randf() * TAU
		var random_radius = randf_range(0.0, 40.0)
		add_child(zombie)
		zombie.global_position = start_point.global_position + Vector2(cos(random_angle), sin(random_angle)) * random_radius
		
		if spawn_interval > 0.0:
			await get_tree().create_timer(spawn_interval).timeout

func _process(delta: float) -> void:
	var first_zombie_pos = Vector2.ZERO
	for c in get_children():
		if c.name == "Zombie" or c.name.begins_with("@Area2D"):
			first_zombie_pos = c.global_position
			break
	var f = FileAccess.open("res://zombie_pos.txt", FileAccess.WRITE)
	f.store_string("Pos: " + str(first_zombie_pos))
	f.close()
