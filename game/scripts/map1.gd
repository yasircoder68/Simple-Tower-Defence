extends Node2D

# Zombies are pushed apart by this radius. It also sets the spatial grid cell
# size, so one grid lookup covers every neighbour that could possibly matter.
const SEPARATION_RADIUS := 32.0

## Identifies this level for PlayerData's gold-once ledger. Must be unique
## across every level that ever ships.
@export var level_id: String = "map1"
## Gold paid on this level's first clear. PLACEHOLDER — implementation_plan.md
## marks gold-unlock pricing as TBD until the number of levels is known, and
## this reward is priced against those same unknowns. Tune later, not now.
@export var gold_reward: int = 10

@export var zombie_count: int = 50
@export var spawn_interval: float = 0.05
@export var debug_logging: bool = false

@onready var tile_map: TileMap = $my_tiles
@onready var start_point: Marker2D = $StartPoint
@onready var end_point: Marker2D = $EndPoint

var flow_field: Dictionary = {} # Vector2i -> Vector2
var walls_dict: Dictionary = {} # Vector2i -> bool
var occupied_cells: Dictionary = {} # Vector2i -> bool

# Vector2i cell -> Array of zombie positions (Vector2), rebuilt each physics
# frame. Positions rather than node references on purpose: separation reads this
# hundreds of times per zombie per frame, and going through a node reference
# means a Variant dynamic dispatch per read, which is what actually melts the
# framerate at horde scale.
var zombie_grid: Dictionary = {}
# Same keys, but node references — for splash damage, which needs take_damage().
var zombie_grid_nodes: Dictionary = {}

var dragging_type: String = ""
var ghost: Node2D = null


# --- Round lifecycle ----------------------------------------------------
#
# Towers are placed in PRE_ROUND only; the loadout locks the moment a round
# starts. This state — round_state, base_health, zombies_to_resolve,
# placed_towers — is round-scoped and is never written to PlayerData. See
# CLAUDE.md's state boundary table.

enum RoundState { PRE_ROUND, IN_ROUND, ROUND_WON, ROUND_LOST }

signal round_started
## gold_awarded is the amount ACTUALLY paid — 0 on a loss, and 0 on a replay
## of an already-cleared level (the gold-once ledger), even though won is
## true in that case. Listeners must not assume won implies gold_awarded > 0.
signal round_ended(won: bool, gold_awarded: int)

var round_state: RoundState = RoundState.PRE_ROUND
var base_health: Node = null
var zombies_to_resolve: int = 0
var placed_towers: Array = []

var round_ui: CanvasLayer = null


func _ready() -> void:
	add_to_group("map")
	generate_flow_field()

	base_health = preload("res://scripts/base_health.gd").new()
	add_child(base_health)

	# Instantiate Sidebar and Ghost
	var sidebar_scene = preload("res://scenes/build_sidebar.tscn")
	var sidebar = sidebar_scene.instantiate()
	$CanvasLayer.add_child(sidebar)
	sidebar.start_drag.connect(_on_start_drag)

	var ghost_scene = preload("res://scenes/ghost_tower.tscn")
	ghost = ghost_scene.instantiate()
	add_child(ghost)

	round_ui = preload("res://scripts/round_ui.gd").new()
	round_ui.name = "RoundUI"
	add_child(round_ui)
	round_ui.setup(self)


func _physics_process(_delta: float) -> void:
	_rebuild_zombie_grid()


# --- Zombie spatial grid -----------------------------------------------------
# Zombies used to find each other via Area2D.get_overlapping_areas(), which
# allocated a fresh array per zombie per frame and dropped the game to 2 FPS at
# 600 zombies. A single O(n) rebuild here replaces all of those queries.

func _rebuild_zombie_grid() -> void:
	zombie_grid.clear()
	zombie_grid_nodes.clear()
	for z in get_tree().get_nodes_in_group("zombie"):
		var pos: Vector2 = z.global_position
		var key := _grid_key(pos)
		if not zombie_grid.has(key):
			zombie_grid[key] = []
			zombie_grid_nodes[key] = []
		zombie_grid[key].append(pos)
		zombie_grid_nodes[key].append(z)


func _grid_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / SEPARATION_RADIUS), floori(world_pos.y / SEPARATION_RADIUS))


func get_zombies_in_radius(world_pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var span := int(ceil(radius / SEPARATION_RADIUS))
	var base := _grid_key(world_pos)
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var key := base + Vector2i(dx, dy)
			if not zombie_grid_nodes.has(key):
				continue
			for z in zombie_grid_nodes[key]:
				if z.global_position.distance_to(world_pos) <= radius:
					result.append(z)
	return result


# --- Round lifecycle ----------------------------------------------------

func _on_start_button_pressed() -> void:
	$CanvasLayer/StartButton.hide()
	_start_round()


func _start_round() -> void:
	# Force-cancel any in-progress drag — the loadout locks now.
	dragging_type = ""
	if ghost:
		ghost.hide_ghost()

	round_state = RoundState.IN_ROUND
	base_health.reset()
	zombies_to_resolve = zombie_count
	round_started.emit()
	spawn_zombies()


## Called by round_ui's "Play Again" button after a win or loss. Clears the
## board so the next round is placed from scratch — placement layout is not
## part of what persists between rounds; upgrades are.
func start_new_round() -> void:
	_clear_placed_towers()
	_clear_all_zombies()
	# Reset lives here as well as in _start_round(), so the pre-round HUD shows
	# the lives you're about to play with rather than "0/20" left over from the
	# loss you just took. _start_round() resetting again is harmless.
	base_health.reset()
	round_state = RoundState.PRE_ROUND
	$CanvasLayer/StartButton.show()


## A zombie died to tower damage. has_method-called from zombie.gd — guarded
## there, and again here, against calls arriving after the round already
## ended (a zombie's death this frame can outrace _end_round firing on a
## sibling's escape the same frame).
func on_zombie_killed(silver_reward: int) -> void:
	if round_state != RoundState.IN_ROUND:
		return
	PlayerData.earn_silver(silver_reward)
	zombies_to_resolve -= 1
	_check_round_complete()


## A zombie reached the end unharmed. Costs a life instead of a silent
## despawn; no silver.
func on_zombie_escaped() -> void:
	if round_state != RoundState.IN_ROUND:
		return
	base_health.lose_life()
	zombies_to_resolve -= 1
	if base_health.lives <= 0:
		_end_round(false)
		return
	_check_round_complete()


func _check_round_complete() -> void:
	if round_state == RoundState.IN_ROUND and zombies_to_resolve <= 0:
		_end_round(true)


func _end_round(won: bool) -> void:
	round_state = RoundState.ROUND_WON if won else RoundState.ROUND_LOST

	var gold_awarded := 0
	if won:
		if PlayerData.award_level_gold(level_id, gold_reward):
			gold_awarded = gold_reward
		# else: level already cleared before — silver earned this round is
		# kept regardless (silver has no discard point; see CLAUDE.md's
		# Economy section), gold_awarded stays 0.

	if not won:
		_clear_all_zombies()

	# The round's whole silver haul lands in one write here rather than one per
	# kill. Runs on a loss too — silver earned before dying is kept.
	PlayerData.save_if_dirty()

	round_ended.emit(won, gold_awarded)


func _clear_all_zombies() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()


func _clear_placed_towers() -> void:
	for tower in placed_towers:
		if is_instance_valid(tower):
			tower.queue_free()
	placed_towers.clear()
	occupied_cells.clear()


# --- Building ----------------------------------------------------------------

func _on_start_drag(tower_type: String):
	if round_state != RoundState.PRE_ROUND:
		return
	dragging_type = tower_type
	ghost.set_tower(tower_type)


func _input(event):
	if dragging_type == "":
		return

	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		ghost.global_position = mouse_pos
		ghost.update_validity(is_valid_placement(mouse_pos))

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var mouse_pos = get_global_mouse_position()
			if is_valid_placement(mouse_pos):
				place_tower(dragging_type, mouse_pos)

			# Stop drag
			dragging_type = ""
			ghost.hide_ghost()

		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			# Cancel drag
			dragging_type = ""
			ghost.hide_ghost()


func is_valid_placement(world_pos: Vector2) -> bool:
	if round_state != RoundState.PRE_ROUND:
		return false
	if placed_towers.size() >= PlayerData.slot_count:
		return false
	var local_pos = tile_map.to_local(world_pos)
	var cell = tile_map.local_to_map(local_pos)
	if not walls_dict.has(cell):
		return false
	if occupied_cells.has(cell):
		return false
	return true


func place_tower(type: String, world_pos: Vector2):
	var local_pos = tile_map.to_local(world_pos)
	var cell = tile_map.local_to_map(local_pos)
	var cell_center = tile_map.to_global(tile_map.map_to_local(cell))

	var tower_scene
	if type == "archer":
		tower_scene = preload("res://scenes/archer_tower.tscn")
	elif type == "wizard":
		tower_scene = preload("res://scenes/wizard_tower.tscn")

	var tower = tower_scene.instantiate()
	tower.global_position = cell_center
	add_child(tower)
	placed_towers.append(tower)

	occupied_cells[cell] = true


# --- Flow field --------------------------------------------------------------

func generate_flow_field() -> void:
	flow_field.clear()
	walls_dict.clear()

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

	var head := 0
	while head < queue.size():
		var current = queue[head]
		head += 1
		var current_cost = cost_field[current]

		for d in dirs:
			var neighbor = current + d
			if not rect.has_point(neighbor):
				continue
			if walls_dict.has(neighbor):
				continue

			if d.x != 0 and d.y != 0:
				if walls_dict.has(current + Vector2i(d.x, 0)) or walls_dict.has(current + Vector2i(0, d.y)):
					continue

			var new_cost = current_cost + 1
			if not cost_field.has(neighbor):
				cost_field[neighbor] = new_cost
				queue.push_back(neighbor)

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

	if debug_logging:
		print("[map1] target cell %s | search rect %s | flow field %d cells" % [target_cell, rect, flow_field.size()])


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
	for i in range(zombie_count):
		# The round can end mid-spawn (all lives lost to early escapees) —
		# stop feeding zombies onto a board that already resolved.
		if round_state != RoundState.IN_ROUND:
			return

		var zombie = zombie_scene.instantiate()

		var random_angle = randf() * TAU
		var random_radius = randf_range(0.0, 40.0)
		add_child(zombie)
		zombie.global_position = start_point.global_position + Vector2(cos(random_angle), sin(random_angle)) * random_radius

		if spawn_interval > 0.0:
			await get_tree().create_timer(spawn_interval).timeout
