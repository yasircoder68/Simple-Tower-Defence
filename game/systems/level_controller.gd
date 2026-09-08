extends Node2D

# Cell size of the enemy NODE grid — the one splash damage and tower targeting
# query through get_enemies_in_radius(). Nothing to do with separation any more.
#
# It used to be `Enemy.SEPARATION_RADIUS`, single-sourced because both sides
# derived cell keys from it. D-1 ended that: enemies no longer index any grid,
# so the constant lives where its only consumer is. The VALUE is unchanged at
# 32.0 on purpose — it sets get_enemies_in_radius()'s search span, and moving it
# would silently re-tune every splash query in the game.
const GRID_CELL := 32.0

# --- Crowd density field (A3 D-1) -------------------------------------------
#
# Replaces the pairwise 3x3 neighbour scan that used to be enemy.gd's
# _separation(). Each enemy deposits its mass into this field once (O(1)) and
# reads the local gradient back (O(1)); it never compares itself to another
# enemy. That is what makes the horde read as a fluid rather than as N
# individuals shoving, and it is also why the largest measured cost in the game
# simply stops existing rather than getting cheaper. See a3_plan.md's D-1.

## World px per density cell. Deliberately the old separation radius, so the
## interaction scale is unchanged; drop it to 24 or 20 if the horde spreads too
## wide (CIC's support is ~1-2 cells, slightly broader than the old hard cutoff).
const DENSITY_CELL := 32.0
## Cells of margin around the tilemap's used rect. Guarantees the 2x2 deposit
## and gather blocks are in range for anything on the play area, so the hot path
## needs one range test and no per-access clamping.
const DENSITY_PAD := 3
## Converts the raw gradient (units: mass per cell, per cell) into the same
## scale as the pairwise push it replaces.
##
## CALIBRATED AGAINST A MEASUREMENT, not eyeballed. Both builds were
## instrumented over a full identical round and the mean magnitude of the push
## actually applied was recorded:
##
##   old pairwise scan   mean 0.277  (106,535 samples)
##   density, gain 1.0   mean 0.682  (184,065 samples)
##   -> 0.277 / 0.682 = 0.41
##
## Matched on the MEAN rather than the max, because the mean is what shapes the
## crowd while the max is a tail event. A side effect worth knowing: the field
## smooths extremes, so at this gain the new push has the same mean as the old
## one but a lower peak (~0.98 against 2.34). See a3_plan.md's D-1.
const DENSITY_GAIN := 0.41
## Runaway guard, NOT a tuning knob — it does not bind in normal play at the
## calibrated gain, and that is intended.
##
## It exists because the old code saturated implicitly: MAX_SEPARATION_CHECKS
## (24) and MAX_SEPARATION_NEIGHBORS (10) capped how much push a dense cell
## could produce. A gradient has no such ceiling and scales with real local
## density, so at a bad enough choke the push could overwhelm the flow field
## and make the horde stall or scatter backwards. Sized from the old measured
## max (2.34), leaving ~2.4x headroom over what a wave-5 crowd actually
## generates.
const DENSITY_MAX_PUSH := 2.4

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

## Where "quit to menu" goes. A const rather than an @export: every level
## returns to the same menu, and a per-level override would only ever be a way
## to get it wrong.
const MAIN_MENU_PATH := "res://ui/main_menu/main_menu.tscn"

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

# Vector2i cell -> Array of enemy nodes, rebuilt each physics frame. Splash
# damage and tower targeting need to know WHICH nodes are nearby, so this
# survives D-1 untouched.
#
# Its twin — a parallel dictionary of enemy POSITIONS — was deleted at D-1. It
# existed solely so _separation() could read neighbour positions without a
# Variant dynamic dispatch through a node reference. Nothing reads positions out
# of a grid any more, so it was ~200 Array allocations a frame for one caller
# that no longer exists.
var enemy_grid_nodes: Dictionary = {}

# --- Crowd density field ----------------------------------------------------
#
# Flat and typed: index is iy * _density_w + ix, allocated once per level and
# refilled with one fill(0.0) per frame. On level_01 that is 52 x 30 = 1560
# floats (6 KB), which fits in L1 — the point of a flat array over a Dictionary
# of freshly allocated buckets.
#
# PRIVATE, AND IT MUST STAY THAT WAY. PackedFloat32Array is copy-on-write: any
# second holder of a reference makes the next write here deep-copy the whole
# array. Never alias it into a local inside the deposit loop, and never hand it
# to an enemy — they read through get_density_push() precisely so this stays
# single-owner. Same trap this project already recorded for PackedVector2Array.
var _enemy_density: PackedFloat32Array = PackedFloat32Array()
var _density_w: int = 0
var _density_h: int = 0
## World coordinates of density cell (0, 0)'s corner. Sits DENSITY_PAD cells
## outside the map, so grid coordinates are non-negative everywhere an enemy can
## be and int() is a safe (and cheaper) stand-in for floori().
var _density_origin: Vector2 = Vector2.ZERO
var _density_inv_cell: float = 1.0 / DENSITY_CELL
## Upper bounds for the in-range test, precomputed as floats so the hot path
## does no int->float conversion.
var _density_max_x: float = 0.0
var _density_max_y: float = 0.0
## Enemies found outside the field this frame, and therefore not deposited.
## Should be 0 on level_01 — StartPoint, EndPoint and the whole flow field are
## inside the used rect. Counted rather than silently dropped because a
## mechanism that fails quietly is how this project has lost a subsystem before
## (see CLAUDE.md's lives_depleted). Readable via runtime_get_script_vars.
var density_oob_count: int = 0

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
## Dev-only horde benchmark. See systems/bench.gd and a3_plan.md.
var bench: Node = null
var enemies_to_resolve: int = 0
## Silver earned in the current round only — reported on the result screen.
## Round-scoped; the running total lives in PlayerData.silver.
var silver_earned_this_round: int = 0
## Enemies killed this round, for the result screen. Round-scoped like the
## silver haul beside it, and reset on the same line — never written to
## PlayerData. Escapes are deliberately not counted: this is a kill count, and
## the lives readout already says what got through.
var kills_this_round: int = 0

## The pause screen. Round-scoped like every other manager here.
var pause_menu: CanvasLayer = null
## The in-round HUD (A4's U-2). Owns the status readout and the breather that
## round_ui used to carry.
var hud: CanvasLayer = null
## The end-of-round screen (A4's U-3). Owns the win/lose result round_ui used
## to carry, and the line telling a losing player their silver was kept.
var result_screen: CanvasLayer = null
## The upgrade shop (A4's U-5). The same scene the main menu instantiates.
var upgrade_screen: CanvasLayer = null


func _ready() -> void:
	add_to_group("map")
	# Ordered after generate_flow_field(), not before: the assertion now also
	# checks that the density field actually got built, which is state rather
	# than a declaration, and a guard that fires on every launch teaches people
	# to ignore it.
	generate_flow_field()
	_assert_enemy_contract()

	# Managers are constructed before the UI, which connects to their signals in
	# setup() — the ordering dependency base_health already had.
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

	# Dev instrumentation, inert until run() is called over MCP. Constructed
	# unconditionally so its node path is stable — a bench you have to enable
	# first is a bench nobody runs.
	bench = preload("res://systems/bench.gd").new()
	bench.name = "Bench"
	add_child(bench)
	bench.setup(self)

	# Instantiate Sidebar and Ghost
	var sidebar_scene = preload("res://ui/build_sidebar/build_sidebar.tscn")
	var sidebar = sidebar_scene.instantiate()
	$CanvasLayer.add_child(sidebar)
	sidebar.start_drag.connect(_on_start_drag)

	var ghost_scene = preload("res://ui/ghost_tower/ghost_tower.tscn")
	ghost = ghost_scene.instantiate()
	add_child(ghost)

	hud = preload("res://ui/hud/hud.tscn").instantiate()
	add_child(hud)
	hud.setup(self)
	hud.upgrades_requested.connect(_on_upgrades_requested)

	# The same self-contained scene the main menu uses. It reads only the
	# autoloads, so nothing here has to hand it any level state.
	upgrade_screen = preload("res://ui/upgrade_screen/upgrade_screen.tscn").instantiate()
	add_child(upgrade_screen)

	result_screen = preload("res://ui/result_screen/result_screen.tscn").instantiate()
	add_child(result_screen)
	result_screen.setup(self)
	result_screen.menu_requested.connect(_on_menu_requested)

	# Added LAST so it sits last in the tree and therefore FIRST in input order —
	# _unhandled_input runs in reverse tree order, and Escape must reach the
	# pause screen before anything else can consume it.
	#
	# It is the ONLY node in the project at PROCESS_MODE_ALWAYS (set in its
	# scene). Everything else inherits, so get_tree().paused stops the horde, both
	# wave Timers and the ability cooldown tick with no per-system wiring. See
	# ui/pause_menu/pause_menu.gd for the whole policy.
	pause_menu = preload("res://ui/pause_menu/pause_menu.tscn").instantiate()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_pause_resumed)
	pause_menu.restart_requested.connect(_on_pause_restart)
	pause_menu.menu_requested.connect(_on_menu_requested)
	pause_menu.quit_requested.connect(_on_pause_quit)


## Fails at game start instead of at the first kill of the first round.
##
## Every member below is reached by NAME from another file — Enemy's round
## contract, and the splash query used by fire.gd and boulder.gd. Renaming one
## without its caller is silent: the has_method() guard simply returns false and
## kills stop scoring. This turns that into a startup error.
func _assert_enemy_contract() -> void:
	var required := Enemy.ROUND_CONTRACT + ["get_enemies_in_radius", "get_density_push"]
	var missing: Array = []
	for member in required:
		if not has_method(member):
			missing.append(member)

	if not missing.is_empty():
		push_error("level_controller is missing enemy-contract members %s — enemies will not score. A rename has drifted." % [missing])
	elif _enemy_density.is_empty():
		push_error("level_controller's density field is empty — the crowd push will be silently zero for every enemy. _build_density_grid() did not run.")


func _physics_process(_delta: float) -> void:
	# The last rung of the bench ablation ladder — isolates the whole manager
	# side (group scan + per-cell Array reallocation) by subtraction. One int
	# compare per FRAME, not per enemy. See a3_plan.md's M-1.
	if Enemy.bench_variant >= Enemy.BENCH_NO_GRID:
		return
	_rebuild_enemy_grid()


# --- Enemy spatial grid -----------------------------------------------------
# Enemies used to find each other via Area2D.get_overlapping_areas(), which
# allocated a fresh array per enemy per frame and dropped the game to 2 FPS at
# 600 enemies. A single O(n) rebuild here replaces all of those queries.

func _rebuild_enemy_grid() -> void:
	enemy_grid_nodes.clear()
	# One flat memset over 1560 floats, versus clearing a Dictionary and
	# dropping ~200 Arrays for the collector every frame.
	_enemy_density.fill(0.0)
	density_oob_count = 0

	for z in get_tree().get_nodes_in_group(Enemy.GROUP):
		# queue_free() doesn't leave the group until end of frame, so a dead
		# enemy would otherwise be indexed and handed to splash queries.
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		var pos: Vector2 = z.global_position

		# --- Node grid, for splash and tower targeting ----------------------
		# One hash per enemy. Arrays are reference types, so appending to this
		# local mutates the array actually stored in the dictionary.
		var key := _grid_key(pos)
		var nodes = enemy_grid_nodes.get(key)
		if nodes == null:
			nodes = []
			enemy_grid_nodes[key] = nodes
		nodes.append(z)

		# --- Density scatter, cloud-in-cell ---------------------------------
		# The enemy's mass of 1.0 is split bilinearly across the four cells
		# whose CENTRES surround it, rather than dumped whole into one cell.
		# That is what makes the field — and therefore the gradient read back
		# out of it — continuous instead of blocky at cell boundaries, so the
		# horde does not visibly snap to a 32px lattice.
		#
		# Mass is 1.0 for EVERY type, deliberately: under the old scan each
		# enemy contributed exactly one position regardless of type, so a
		# uniform mass is what keeps D-1 from being a difficulty change. A
		# per-type deposit_mass (the ogre's sprite is twice a goblin's) is an
		# obvious registry field later, not now.
		#
		# NEVER write `var d := _enemy_density` here. See the field's
		# declaration: that alias would deep-copy 6 KB per enemy per frame.
		var f := _density_coords(pos)
		if f.x < 0.0 or f.y < 0.0 or f.x >= _density_max_x or f.y >= _density_max_y:
			# Outside the field. The node grid above already has it, so splash
			# still finds it; it just exerts no crowd pressure this frame.
			density_oob_count += 1
			continue
		var ix := int(f.x)
		var iy := int(f.y)
		var u := f.x - ix
		var v := f.y - iy
		var iu := 1.0 - u
		var iv := 1.0 - v
		var base := iy * _density_w + ix
		_enemy_density[base] += iu * iv
		_enemy_density[base + 1] += u * iv
		_enemy_density[base + _density_w] += iu * v
		_enemy_density[base + _density_w + 1] += u * v


func _grid_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / GRID_CELL), floori(world_pos.y / GRID_CELL))


func get_enemies_in_radius(world_pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var span := int(ceil(radius / GRID_CELL))
	var base := _grid_key(world_pos)
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var key := base + Vector2i(dx, dy)
			# Same single-probe idiom as _separation(). Not in a per-frame path
			# today, but Rain of Arrows queries this 12 times per cast and A3's
			# S-1 routes both towers through it, so it is no longer cold.
			var nodes = enemy_grid_nodes.get(key)
			if nodes == null:
				continue
			for z in nodes:
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


# --- Crowd density field ----------------------------------------------------

## Sized once per level, from the tilemap's own extent, so it can never drift
## from the map. Called at the end of generate_flow_field() because that is
## already the one place that owns the map's geometry.
func _build_density_grid() -> void:
	var rect: Rect2i = tile_map.get_used_rect()
	# map_to_local() returns a cell's CENTRE, so back off half a tile to reach
	# the rect's true corner.
	var half_tile := Vector2(tile_map.tile_set.tile_size) * 0.5
	var top_left: Vector2 = tile_map.to_global(tile_map.map_to_local(rect.position) - half_tile)
	var bottom_right: Vector2 = tile_map.to_global(
		tile_map.map_to_local(rect.position + rect.size) - half_tile)
	var span: Vector2 = bottom_right - top_left

	_density_origin = top_left - Vector2(DENSITY_CELL, DENSITY_CELL) * DENSITY_PAD
	_density_w = int(ceil(span.x / DENSITY_CELL)) + 2 * DENSITY_PAD
	_density_h = int(ceil(span.y / DENSITY_CELL)) + 2 * DENSITY_PAD
	_density_inv_cell = 1.0 / DENSITY_CELL
	# The gather and scatter blocks are 2x2, so the last legal integer cell is
	# w - 2; the test is `< w - 1` on the fractional coordinate.
	_density_max_x = float(_density_w - 1)
	_density_max_y = float(_density_h - 1)

	_enemy_density.resize(_density_w * _density_h)
	_enemy_density.fill(0.0)

	if debug_logging:
		print("[map1] density field %d x %d cells @ %.0fpx, origin %s"
			% [_density_w, _density_h, DENSITY_CELL, _density_origin])


## World position -> fractional density-grid coordinates, where INTEGER values
## land on cell CENTRES.
##
## Scatter and gather MUST both go through this. A half-cell disagreement
## between them would be a silent constant bias in every push direction, and it
## would also break the self-force cancellation in get_density_push(), which
## assumes both sides see the same (u, v). One definition makes that
## unrepresentable — the same argument that used to single-source the old grid
## cell size across two files.
func _density_coords(world_pos: Vector2) -> Vector2:
	return Vector2(
		(world_pos.x - _density_origin.x) * _density_inv_cell - 0.5,
		(world_pos.y - _density_origin.y) * _density_inv_cell - 0.5)


## The crowd push at a point: down the local density gradient, scaled and
## clamped. This is what replaced enemy.gd's _separation(), and the enemy
## multiplies the result by its own separation_weight exactly as before.
##
## A METHOD rather than exposing _enemy_density, because the array is
## copy-on-write — see its declaration. One cross-object call per enemy per
## frame is the price of keeping it single-owner, and it is a fraction of the
## 3x3 scan it replaces.
func get_density_push(world_pos: Vector2) -> Vector2:
	var f := _density_coords(world_pos)
	if f.x < 0.0 or f.y < 0.0 or f.x >= _density_max_x or f.y >= _density_max_y:
		return Vector2.ZERO

	var ix := int(f.x)
	var iy := int(f.y)
	var u := f.x - ix
	var v := f.y - iy
	var base := iy * _density_w + ix

	var a: float = _enemy_density[base]
	var b: float = _enemy_density[base + 1]
	var c: float = _enemy_density[base + _density_w]
	var e: float = _enemy_density[base + _density_w + 1]

	# Gradient of the bilinear interpolant over those four cells. It varies
	# smoothly WITHIN a cell rather than being constant across it, which is what
	# stops the push direction snapping at cell boundaries.
	var gx := (b - a) * (1.0 - v) + (e - c) * v
	var gy := (c - a) * (1.0 - u) + (e - b) * u

	# SUBTRACT THIS ENEMY'S OWN DEPOSIT. It is in the field it is reading, and
	# its self-contribution is NOT zero: differentiating the CIC weights gives
	# d/du = (2u-1)[(1-v)^2 + v^2], and likewise for v. Left in, that is a
	# coherent lattice-aligned pull toward u = v = 0.5 — every enemy feeling it
	# identically, while the real neighbour forces are incoherent — and the
	# horde would visibly crystallise onto the grid.
	#
	# The closed form uses values already in hand, so removing it costs ~8 flops
	# and no memory traffic. It also yields a falsifiable invariant that catches
	# a scatter/gather lattice mismatch immediately: A SINGLE ENEMY ALONE ON THE
	# MAP MUST GET EXACTLY Vector2.ZERO.
	var iu := 1.0 - u
	var iv := 1.0 - v
	gx -= (2.0 * u - 1.0) * (iv * iv + v * v)
	gy -= (2.0 * v - 1.0) * (iu * iu + u * u)

	# Not divided by DENSITY_CELL: the gradient is left in mass-per-cell units
	# and DENSITY_GAIN carries the conversion, since the caller normalises the
	# blended direction anyway.
	return (Vector2(-gx, -gy) * DENSITY_GAIN).limit_length(DENSITY_MAX_PUSH)


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
	# Pausing is armed only inside a round. A pause screen over the build phase
	# would stop nothing — the same reasoning that makes abilities inert outside
	# IN_ROUND.
	pause_menu.setup(true)
	# enemies_to_resolve is no longer seeded here: wave_manager sets it per
	# wave, topping it up at each wave boundary so this controller's existing
	# decrement-and-check path still decides when the round is won.
	silver_earned_this_round = 0
	kills_this_round = 0

	# Towers persist between rounds now, so any upgrade bought since the last
	# round hasn't reached them yet — they resolved their stats when they were
	# placed. Re-resolve before the first enemy spawns.
	get_tree().call_group("tower_unit", "refresh_stats")

	round_started.emit()
	wave_manager.begin()


## Called by the result screen's "Play Again" button after a win or loss.
##
## Deliberately does NOT clear placed towers — a layout you built survives
## replaying the level, and you can keep adding to it up to slot_count. Only a
## map change resets placement, which happens for free: loading a different
## level scene destroys these nodes with it. If levels ever start swapping
## in-place without a scene reload, call _clear_placed_towers() at that point.
# --- Pause -------------------------------------------------------------
#
# The pause screen emits intent; this decides what the intent MEANS. Same
# signal-driven split as every other manager here — the screen does not reach
# into the round lifecycle itself.

func _on_pause_resumed() -> void:
	pass # Unpausing is the screen's own job; nothing round-scoped to restore.


## Restart goes through start_new_round() — the SAME path "Play Again" uses —
## rather than re-implementing a reset. That path is tested, and it is also the
## one that deliberately does NOT emit round_started, which every UI listener
## already accounts for. A bespoke restart here would rediscover that the hard
## way.
func _on_pause_restart() -> void:
	start_new_round()


## The ONE place that knows how to get back to the menu — the pause screen and
## the result screen both route here rather than each calling change_scene.
##
## SCENE REPLACEMENT, never a resident overlay: change_scene_to_file frees this
## level and makes the menu a direct child of root, which is what keeps the next
## level's root node at /root/map1. See ui/main_menu/main_menu.gd.
##
## Nothing needs saving first. PlayerData flushes at _end_round() and again from
## its own _notification() on tree exit, and everything else here is round-scoped
## by design — see CLAUDE.md's state-boundary table.
func _on_menu_requested() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


## Upgrades are a between-rounds activity, which in a level means PRE_ROUND.
## The shop itself does not know what a round is — it takes the answer, because
## it also runs at the main menu where there is no round to ask about.
func _on_upgrades_requested() -> void:
	upgrade_screen.open(round_state == RoundState.PRE_ROUND)


func _on_pause_quit() -> void:
	get_tree().quit()


func start_new_round() -> void:
	_clear_all_enemies()
	# Reset lives here as well as in _start_round(), so the pre-round HUD shows
	# the lives you're about to play with rather than "0/20" left over from the
	# loss you just took. _start_round() resetting again is harmless.
	base_health.reset()
	wave_manager.reset()
	ability_manager.reset()
	round_state = RoundState.PRE_ROUND
	pause_menu.setup(false)
	# start_new_round() deliberately does NOT emit round_started (only the Start
	# button's _start_round() does), and base_health.reset() emits no life_lost,
	# so nothing else would move the HUD back to full lives here. The deleted
	# round_ui hit this exact trap twice and the HUD hit it a third time at U-2;
	# listeners get told directly rather than trusting a lifecycle signal to
	# cover every entry point.
	hud.reset_for_new_round()
	$CanvasLayer/StartButton.show()


## An enemy died to tower damage. Called from enemy.gd — guarded
## there, and again here, against calls arriving after the round already
## ended (an enemy's death this frame can outrace _end_round firing on a
## sibling's escape the same frame).
func on_enemy_killed(silver_reward: int) -> void:
	if round_state != RoundState.IN_ROUND:
		return
	PlayerData.earn_silver(silver_reward)
	silver_earned_this_round += silver_reward
	kills_this_round += 1
	enemies_to_resolve -= 1
	# Inert until W-2, which moves wave-scoped accounting into the manager.
	# Forwarding from here means that move never has to reopen this file.
	wave_manager.on_enemy_resolved()
	_check_round_complete()


## An enemy reached the end unharmed. Costs a life instead of a silent
## despawn; no silver.
func on_enemy_escaped(life_cost: int = 1) -> void:
	if round_state != RoundState.IN_ROUND:
		return
	base_health.lose_life(life_cost)

	# EXACTLY 1, never life_cost. One spawned unit is one resolution unit;
	# life_cost is a damage number, not a count.
	#
	# Decrementing by 3 for an ogre is the single most tempting wrong edit in
	# this file. It would desync this counter from wave_manager.wave_remaining,
	# which decrements once per resolution — and the round would end early. That
	# is the "victory after wave 1" failure W-2 and W-3 each had to defeat,
	# re-entering through a third door.
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
	pause_menu.setup(false)

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

	# Sized here rather than in _ready() so it can never be built against a
	# different tilemap extent than the flow field walked.
	_build_density_grid()


func get_flow_direction(world_pos: Vector2) -> Vector2:
	var local_pos = tile_map.to_local(world_pos)
	var cell = tile_map.local_to_map(local_pos)
	# get() with a default is one hash; has()-then-[] was two. Vector2.ZERO is
	# already what a miss meant, so the branch disappears with it.
	return flow_field.get(cell, Vector2.ZERO)


func is_wall(world_pos: Vector2) -> bool:
	var local_pos = tile_map.to_local(world_pos)
	var cell = tile_map.local_to_map(local_pos)
	return walls_dict.has(cell)
