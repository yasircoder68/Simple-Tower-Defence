extends Node2D

# Enemies are pushed apart by this radius. It also sets the spatial grid cell
# size, so one grid lookup covers every neighbour that could possibly matter.
const SEPARATION_RADIUS := 32.0

## Identifies this level for PlayerData's gold-once ledger. Must be unique
## across every level that ever ships.
@export var level_id: String = "map1"
## Gold paid on this level's first clear. PLACEHOLDER — implementation_plan.md
## marks gold-unlock pricing as TBD until the number of levels is known, and
## this reward is priced against those same unknowns. Tune later, not now.
@export var gold_reward: int = 10

## How many rows of wave_manager's WAVE_TABLE this level uses, and a multiplier
## on each wave's enemy count. Two numbers per level instead of a bespoke wave
## table per level — see a1_plan.md.
@export var wave_count: int = 5
@export var difficulty_scale: float = 1.0

@export var debug_logging: bool = false

@onready var tile_map: TileMap = $my_tiles
@onready var start_point: Marker2D = $StartPoint
@onready var end_point: Marker2D = $EndPoint

var flow_field: Dictionary = {} # Vector2i -> Vector2
var walls_dict: Dictionary = {} # Vector2i -> bool

## Vector2i cell -> tower Node2D. Single source of truth for what is placed and
## where. Replaces the old occupied_cells + placed_towers pair — two collections
## tracking one fact desynced too easily once towers became editable (removal
## and moving would have to update both, and any desync is a silent bug: a
## ghost-occupied cell you can never build on, or a leaked slot).
var towers_by_cell: Dictionary = {}

# Vector2i cell -> Array of enemy positions (Vector2), rebuilt each physics
# frame. Positions rather than node references on purpose: separation reads this
# hundreds of times per enemy per frame, and going through a node reference
# means a Variant dynamic dispatch per read, which is what actually melts the
# framerate at horde scale.
var enemy_grid: Dictionary = {}
# Same keys, but node references — for splash damage, which needs take_damage().
var enemy_grid_nodes: Dictionary = {}

var dragging_type: String = ""
var ghost: Node2D = null

## The tower currently being moved, or null. Non-null only between pick-up and
## drop/cancel. While set, the node is hidden and its origin cell is free, so
## the ghost previews correctly and the origin itself reads as a valid drop
## target (dropping back on it is a harmless no-op).
var moving_tower: Node2D = null
## Cell the in-flight tower came from, so cancel and an invalid drop can
## restore it. Vector2i while a move is in flight, null otherwise.
var moving_from_cell = null


# --- Round lifecycle ----------------------------------------------------
#
# Towers are placed in PRE_ROUND only; the loadout locks the moment a round
# starts. This state — round_state, base_health, enemies_to_resolve,
# towers_by_cell — is round-scoped and is never written to PlayerData. See
# CLAUDE.md's state boundary table.

enum RoundState { PRE_ROUND, IN_ROUND, ROUND_WON, ROUND_LOST }

signal round_started
## gold_awarded is the amount ACTUALLY paid — 0 on a loss, and 0 on a replay
## of an already-cleared level (the gold-once ledger), even though won is
## true in that case. Listeners must not assume won implies gold_awarded > 0.
## silver_earned is this round's haul only, not the running PlayerData total.
signal round_ended(won: bool, gold_awarded: int, silver_earned: int)

var round_state: RoundState = RoundState.PRE_ROUND
var base_health: Node = null
var wave_manager: Node = null
var ability_manager: Node = null
var enemies_to_resolve: int = 0
## Silver earned in the current round only — reported on the result screen.
## Round-scoped; the running total lives in PlayerData.silver.
var silver_earned_this_round: int = 0

var round_ui: CanvasLayer = null


func _ready() -> void:
	add_to_group("map")
	_assert_enemy_contract()
	generate_flow_field()

	# Managers are constructed before round_ui because round_ui connects to
	# their signals in setup() — the ordering dependency base_health already had.
	base_health = preload("res://systems/base_health.gd").new()
	add_child(base_health)

	wave_manager = preload("res://systems/wave_manager.gd").new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.setup(self)

	ability_manager = preload("res://systems/ability_manager.gd").new()
	ability_manager.name = "AbilityManager"
	add_child(ability_manager)
	ability_manager.setup(self)

	# Instantiate Sidebar and Ghost
	var sidebar_scene = preload("res://ui/build_sidebar/build_sidebar.tscn")
	var sidebar = sidebar_scene.instantiate()
	$CanvasLayer.add_child(sidebar)
	sidebar.start_drag.connect(_on_start_drag)

	var ghost_scene = preload("res://ui/ghost_tower/ghost_tower.tscn")
	ghost = ghost_scene.instantiate()
	add_child(ghost)

	round_ui = preload("res://ui/round_ui.gd").new()
	round_ui.name = "RoundUI"
	add_child(round_ui)
	round_ui.setup(self)


## Fails at game start instead of at the first kill of the first round.
##
## Every member below is reached by NAME from another file — Enemy's round
## contract, and the splash query used by fire.gd and boulder.gd. Renaming one
## without its caller is silent: the has_method() guard simply returns false and
## kills stop scoring. This turns that into a startup error.
func _assert_enemy_contract() -> void:
	var required := Enemy.ROUND_CONTRACT + ["get_enemies_in_radius"]
	var missing: Array = []
	for member in required:
		if not has_method(member):
			missing.append(member)

	if not missing.is_empty():
		push_error("level_controller is missing enemy-contract members %s — enemies will not score. A rename has drifted." % [missing])
	elif not ("enemy_grid" in self):
		push_error("level_controller has no enemy_grid — separation will be silently disabled for every enemy.")


func _physics_process(_delta: float) -> void:
	_rebuild_enemy_grid()


# --- Enemy spatial grid -----------------------------------------------------
# Enemies used to find each other via Area2D.get_overlapping_areas(), which
# allocated a fresh array per enemy per frame and dropped the game to 2 FPS at
# 600 enemies. A single O(n) rebuild here replaces all of those queries.

func _rebuild_enemy_grid() -> void:
	enemy_grid.clear()
	enemy_grid_nodes.clear()
	for z in get_tree().get_nodes_in_group(Enemy.GROUP):
		# queue_free() doesn't leave the group until end of frame, so a dead
		# enemy would otherwise be indexed and handed to splash queries.
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		var pos: Vector2 = z.global_position
		var key := _grid_key(pos)
		if not enemy_grid.has(key):
			enemy_grid[key] = []
			enemy_grid_nodes[key] = []
		enemy_grid[key].append(pos)
		enemy_grid_nodes[key].append(z)


func _grid_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / SEPARATION_RADIUS), floori(world_pos.y / SEPARATION_RADIUS))


func get_enemies_in_radius(world_pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var span := int(ceil(radius / SEPARATION_RADIUS))
	var base := _grid_key(world_pos)
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var key := base + Vector2i(dx, dy)
			if not enemy_grid_nodes.has(key):
				continue
			for z in enemy_grid_nodes[key]:
				# The grid caches node references at rebuild time, but splash
				# damage reads it later in the frame — by then other kills may
				# already have freed some of them. Without this guard, two
				# fireballs landing on the same cluster in one frame crashes on
				# 'previously freed'.
				if not is_instance_valid(z):
					continue
				if z.global_position.distance_to(world_pos) <= radius:
					result.append(z)
	return result


# --- Round lifecycle ----------------------------------------------------

func _on_start_button_pressed() -> void:
	$CanvasLayer/StartButton.hide()
	_start_round()


func _start_round() -> void:
	# A move in flight would otherwise be left hidden and untracked — in
	# neither towers_by_cell nor visible — the instant dragging_type is
	# cleared below erases the only reference back to it.
	if moving_tower != null:
		cancel_move()

	# Force-cancel any in-progress drag — the loadout locks now.
	dragging_type = ""
	if ghost:
		ghost.hide_ghost()

	round_state = RoundState.IN_ROUND
	base_health.reset()
	ability_manager.reset()
	# enemies_to_resolve is no longer seeded here: wave_manager sets it per
	# wave, topping it up at each wave boundary so this controller's existing
	# decrement-and-check path still decides when the round is won.
	silver_earned_this_round = 0

	# Towers persist between rounds now, so any upgrade bought since the last
	# round hasn't reached them yet — they resolved their stats when they were
	# placed. Re-resolve before the first enemy spawns.
	get_tree().call_group("tower_unit", "refresh_stats")

	round_started.emit()
	wave_manager.begin()


## Called by round_ui's "Play Again" button after a win or loss.
##
## Deliberately does NOT clear placed towers — a layout you built survives
## replaying the level, and you can keep adding to it up to slot_count. Only a
## map change resets placement, which happens for free: loading a different
## level scene destroys these nodes with it. If levels ever start swapping
## in-place without a scene reload, call _clear_placed_towers() at that point.
func start_new_round() -> void:
	_clear_all_enemies()
	# Reset lives here as well as in _start_round(), so the pre-round HUD shows
	# the lives you're about to play with rather than "0/20" left over from the
	# loss you just took. _start_round() resetting again is harmless.
	base_health.reset()
	wave_manager.reset()
	ability_manager.reset()
	round_state = RoundState.PRE_ROUND
	$CanvasLayer/StartButton.show()


## An enemy died to tower damage. has_method-called from zombie.gd — guarded
## there, and again here, against calls arriving after the round already
## ended (an enemy's death this frame can outrace _end_round firing on a
## sibling's escape the same frame).
func on_enemy_killed(silver_reward: int) -> void:
	if round_state != RoundState.IN_ROUND:
		return
	PlayerData.earn_silver(silver_reward)
	silver_earned_this_round += silver_reward
	enemies_to_resolve -= 1
	# Inert until W-2, which moves wave-scoped accounting into the manager.
	# Forwarding from here means that move never has to reopen this file.
	wave_manager.on_enemy_resolved()
	_check_round_complete()


## An enemy reached the end unharmed. Costs a life instead of a silent
## despawn; no silver.
func on_enemy_escaped() -> void:
	if round_state != RoundState.IN_ROUND:
		return
	base_health.lose_life()
	enemies_to_resolve -= 1
	if base_health.lives <= 0:
		_end_round(false)
		return
	# Placed after the loss short-circuit, not before, so a loss still wins the
	# race against a wave completing on the same escape. Same reason
	# _check_round_complete() sits here. Inert until W-2.
	wave_manager.on_enemy_resolved()
	_check_round_complete()


func _check_round_complete() -> void:
	if round_state == RoundState.IN_ROUND and enemies_to_resolve <= 0:
		_end_round(true)


func _end_round(won: bool) -> void:
	round_state = RoundState.ROUND_WON if won else RoundState.ROUND_LOST

	# _clear_all_enemies() handles enemies already on the board, but nothing
	# stopped a RUNNING spawner before this — that gap is exactly what let a
	# stale spawn coroutine bleed into the next round.
	wave_manager.abort()
	ability_manager.set_enabled(false)

	var gold_awarded := 0
	if won:
		if PlayerData.award_level_gold(level_id, gold_reward):
			gold_awarded = gold_reward
		# else: level already cleared before — silver earned this round is
		# kept regardless (silver has no discard point; see CLAUDE.md's
		# Economy section), gold_awarded stays 0.

	if not won:
		_clear_all_enemies()

	# The round's whole silver haul lands in one write here rather than one per
	# kill. Runs on a loss too — silver earned before dying is kept.
	PlayerData.save_if_dirty()

	round_ended.emit(won, gold_awarded, silver_earned_this_round)


func _clear_all_enemies() -> void:
	for z in get_tree().get_nodes_in_group(Enemy.GROUP):
		z.queue_free()


func _clear_placed_towers() -> void:
	for tower in towers_by_cell.values():
		if is_instance_valid(tower):
			tower.queue_free()
	towers_by_cell.clear()


# --- Building ----------------------------------------------------------------

func _on_start_drag(tower_type: String):
	if round_state != RoundState.PRE_ROUND:
		return
	dragging_type = tower_type
	ghost.set_tower(tower_type)


## _input() covers four things now, not just placing a fresh drag:
##   LMB press,   not dragging, cell occupied  -> pick up (begin_move)
##   LMB release, dragging                     -> drop: place/finish-move, or restore
##   RMB release, dragging                     -> cancel a move (or just drop a sidebar drag)
##   RMB release, not dragging, cell occupied  -> remove
## All of it is PRE_ROUND-only, gated once at the top.
## Abilities are the only live input a round has, and they are IN_ROUND only —
## so this and the PRE_ROUND tower-editing branch in _input() below can never
## both be active. That separation is what lets "hold LMB" mean two entirely
## different things without either side knowing about the other.
##
## _unhandled_input, NOT _input, and that distinction is load-bearing: _input()
## runs BEFORE GUI handling, so a click on the ability bar would reach the
## manager first, start an aim, and throw on release at whatever world position
## sits behind the bar. Controls consume clicks that land on them, so unhandled
## input only ever sees clicks on the game world.
##
## The tower drag below has the same hazard and gets away with it: clicking
## build_sidebar does reach _input(), but resolves to a cell under the sidebar
## where nothing is placed, so nothing happens. Benign there, not here.
##
## Forwards and nothing else — all ability logic lives in ability_manager.
func _unhandled_input(event):
	if round_state != RoundState.IN_ROUND:
		return
	ability_manager.handle_input(event)


func _input(event):
	if round_state != RoundState.PRE_ROUND:
		return

	if event is InputEventMouseMotion:
		if dragging_type == "":
			return
		var drag_pos = get_global_mouse_position()
		ghost.global_position = drag_pos
		ghost.update_validity(is_valid_placement(drag_pos))
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_pos = get_global_mouse_position()

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Only a fresh pick-up if nothing is already in flight (a sidebar
			# drag also sets dragging_type, but that arrives via
			# _on_start_drag, not through a press here).
			if dragging_type == "":
				var cell = _cell_at(mouse_pos)
				if towers_by_cell.has(cell):
					begin_move(cell)
		else:
			if dragging_type != "":
				if is_valid_placement(mouse_pos):
					if moving_tower != null:
						finish_move(_cell_at(mouse_pos)) # self-contained cleanup
					else:
						place_tower(dragging_type, mouse_pos)
						dragging_type = ""
						ghost.hide_ghost()
				elif moving_tower != null:
					# Invalid drop while moving: restore, don't destroy and
					# don't leave it floating.
					cancel_move() # self-contained cleanup
				else:
					# Invalid drop of a fresh sidebar drag: nothing was ever
					# placed, so there's nothing to restore — just stop dragging.
					dragging_type = ""
					ghost.hide_ghost()

	elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		if dragging_type != "":
			if moving_tower != null:
				cancel_move() # self-contained cleanup
			else:
				# Cancelling a fresh sidebar drag — nothing was picked up.
				dragging_type = ""
				ghost.hide_ghost()
		else:
			var cell = _cell_at(mouse_pos)
			remove_tower(cell)


func _cell_at(world_pos: Vector2) -> Vector2i:
	var local_pos = tile_map.to_local(world_pos)
	return tile_map.local_to_map(local_pos)


func is_valid_placement(world_pos: Vector2) -> bool:
	if round_state != RoundState.PRE_ROUND:
		return false
	if towers_by_cell.size() >= PlayerData.slot_count:
		return false
	var cell = _cell_at(world_pos)
	if not walls_dict.has(cell):
		return false
	if towers_by_cell.has(cell):
		return false
	return true


func place_tower(type: String, world_pos: Vector2):
	var cell = _cell_at(world_pos)
	var cell_center = tile_map.to_global(tile_map.map_to_local(cell))

	var tower_scene
	if type == "archer":
		tower_scene = preload("res://entities/towers/archer/archer_tower.tscn")
	elif type == "wizard":
		tower_scene = preload("res://entities/towers/wizard/wizard_tower.tscn")

	var tower = tower_scene.instantiate()
	tower.global_position = cell_center
	# Recorded so a later pick-up (begin_move) knows which ghost sprite to
	# show without string-matching auto-generated node names.
	tower.set_meta("tower_type", type)
	add_child(tower)
	towers_by_cell[cell] = tower


## Removes a placed tower outright. PRE_ROUND only. No refund — towers are
## free to place; PlayerData.slot_count is the actual constraint, and this
## frees a slot, which IS the refund. Returns false (no-op) if not in
## PRE_ROUND or the cell is empty.
func remove_tower(cell: Vector2i) -> bool:
	if round_state != RoundState.PRE_ROUND:
		return false
	if not towers_by_cell.has(cell):
		return false
	var tower = towers_by_cell[cell]
	# Erase before queue_free(), which is deferred — a lookup this same frame
	# would otherwise still find and hand out a tower that's about to die.
	towers_by_cell.erase(cell)
	tower.queue_free()
	return true


## Picks up a placed tower to reposition it. The node is hidden and unindexed,
## not destroyed — see finish_move()/cancel_move(). Reuses the exact same
## ghost-follows-mouse/release-to-drop pipeline a fresh sidebar placement uses.
func begin_move(cell: Vector2i) -> bool:
	if round_state != RoundState.PRE_ROUND:
		return false
	if moving_tower != null:
		return false
	if not towers_by_cell.has(cell):
		return false

	moving_tower = towers_by_cell[cell]
	moving_from_cell = cell
	# Freed now (not on drop) so the origin cell itself previews as a valid
	# drop target, and so the move doesn't need a spare slot.
	towers_by_cell.erase(cell)
	moving_tower.hide()

	var tower_type: String = moving_tower.get_meta("tower_type", "")
	dragging_type = tower_type
	ghost.set_tower(tower_type)
	return true


## Drops the in-flight tower at cell and fully unwinds the drag (dragging_type,
## ghost) — self-contained so every caller gets correct cleanup without having
## to remember the two follow-up lines. Caller must have already confirmed
## is_valid_placement(); this does not re-check.
func finish_move(cell: Vector2i) -> void:
	var cell_center = tile_map.to_global(tile_map.map_to_local(cell))
	moving_tower.global_position = cell_center
	moving_tower.show()
	towers_by_cell[cell] = moving_tower
	moving_tower = null
	moving_from_cell = null
	dragging_type = ""
	if ghost:
		ghost.hide_ghost()


## Restores the in-flight tower to the cell it was picked up from and fully
## unwinds the drag (dragging_type, ghost) — used on an explicit right-click
## cancel, a drop onto an invalid cell, and a round starting mid-move. The
## node itself never moved, so there's nothing to reposition, only to
## re-show, re-index, and stop dragging. Self-contained for the same reason
## as finish_move() — a caller that forgot the cleanup would leave the game
## stuck mid-drag for a real player, not just a test.
func cancel_move() -> void:
	if moving_tower == null:
		return
	moving_tower.show()
	towers_by_cell[moving_from_cell] = moving_tower
	moving_tower = null
	moving_from_cell = null
	dragging_type = ""
	if ghost:
		ghost.hide_ghost()


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
