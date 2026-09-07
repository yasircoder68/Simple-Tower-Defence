extends Node

## The horde benchmark. Exists because this project has attempted six optimisations
## of the separation path and five of them produced "no change" — with an FPS label
## as the only instrument. See a3_plan.md.
##
## THE MEASUREMENT PROBLEM THIS SOLVES
##
## MCP's execute_code runs through Godot's Expression class and CANNOT reach
## Engine or Performance, and rejects statements. So the game has to measure
## ITSELF into member variables, which runtime_get_script_vars can then read.
## That constraint is the whole reason this file exists rather than a tool-side
## profiler.
##
## WHY NOT FPS
##
## Engine.get_frames_per_second() is a smoothed integer AND vsync-quantised:
## anything from 3ms to 16.6ms of work reports "60". An optimisation on the flat
## part of the curve reads as "no change" whether it worked or not. FPS is also a
## reciprocal, so it is not additive — you cannot say "that removed 3ms" and
## predict the next change. Frame TIME is linear in work; that is what makes an
## optimisation ladder possible at all.
##
## Usage, over MCP:
##   execute_code  get_node("/root/map1/Bench").call("run", 600, "loose")
##   ... ~4s later ...
##   runtime_get_script_vars  /root/map1/Bench   -> read result_line

## A second spawn site for the goblin scene, alongside wave_manager's. Deliberate:
## the bench must NOT go through the wave machine (see run()), and test
## infrastructure owning its own reference is better than widening the wave
## manager's API for something no player ever touches.
const GOBLIN_SCENE := preload("res://entities/enemies/goblin/goblin.tscn")

## Bumped whenever the harness itself changes, so a table row can never be
## silently compared against numbers produced by different code.
const BENCH_TAG := "M-0b"

## THE MONITOR LAGS. Performance.TIME_PHYSICS_PROCESS updates far more slowly
## than once per frame - measured at roughly one update per 0.4-0.5s - while
## this harness used to sample it once per frame. Every run's early samples
## therefore carried the PREVIOUS run's value.
##
## Caught by dumping _phys_samples from a V5 run started right after a V0 run:
## the first 33 of 180 samples were a frozen 46.229 (V0's figure) before
## dropping to V5's real 3.76 - 93+ frames of stale data counting warm-up.
##
## That artefact produced the entire "the bench degrades +45% within a process"
## story, and inverted its conclusion: run 1 follows an IDLE game so it reads
## too LOW, runs 2+ follow a heavy run so they read too HIGH. It also made short
## variants (V5 ~2s) far more contaminated than long ones (V0 ~35s), because a
## fixed number of stale frames is a bigger share of a short run.
##
## So sampling is counted in DISTINCT MONITOR UPDATES, never in frames. A fixed
## frame count cannot guarantee the previous run's value has been flushed; only
## observing the value CHANGE can.
const WARMUP_FRAMES := 60
## Distinct updates to discard before sampling begins. The first observed change
## is the residue clearing, so discard a couple more after it.
const WARMUP_UPDATES := 3
## Sample size, in distinct monitor updates. Every variant now takes roughly the
## same wall-clock time regardless of how fast it runs, which is what removes the
## duration-dependent bias - and V0 actually gets FASTER than the old 180 frames.
const SAMPLE_UPDATES := 40
## Hard stop, so a monitor that stops updating cannot hang a run forever.
const MAX_SAMPLE_FRAMES := 6000

## Lattice spacings. `loose` is the PRIMARY config: most enemies have zero
## in-radius neighbours, which is the case the per-enemy scaffolding analysis
## says dominates, and the case where capping candidates at 24 changed nothing.
## `packed` is tighter than the 32px cell size, so cells hold several enemies
## each. Under the old pairwise scan that bounded its inner loop; since D-1 the
## crowd cost is data-independent, so `packed` and `loose` now differ mainly in
## how much OTHER per-enemy work the lattice provokes.
##
## Density has never been a controlled variable in this project's measurements,
## despite CLAUDE.md stating the falloff is super-linear in density rather than
## count. These two configs are what close that gap.
const CONFIGS := {
	"loose": 45.0,
	"packed": 20.0,
}

enum Phase { IDLE, WARMUP, SAMPLING }

var map: Node2D = null

var phase: Phase = Phase.IDLE
var enemy_count: int = 0
var config: String = ""
var variant: int = 0
## Whether the current run suppressed the global_position write. Reported in the
## variant column rather than a new one, so existing result rows stay readable.
var skip_write: bool = false

# --- Results. All readable via runtime_get_script_vars. ---------------------

var frame_ms_p50: float = 0.0
var frame_ms_p95: float = 0.0
var frame_ms_max: float = 0.0
var phys_ms_p50: float = 0.0
var phys_ms_p95: float = 0.0

## THE headline number, and the only one that predicts. At 60Hz the physics
## budget is 16.6ms, so 16600 / us_per_enemy IS the enemy ceiling. It makes runs
## at different enemy counts comparable, and turns every optimisation from "felt
## faster" into "27us -> 11us, ceiling 600 -> 1500".
var us_per_enemy: float = 0.0

var phys_pairs: int = 0
var node_count: int = 0

## Preformatted markdown table row, so ONE runtime_get_script_vars call returns
## something paste-ready rather than nine numbers to reassemble by hand.
var result_line: String = ""
## Every result_line this session, so several configs can be run before reading.
var history: Array = []

var _frame_samples: Array = []
var _phys_samples: Array = []
var _frames_seen: int = 0
## Last monitor reading, so a repeat can be told from a fresh update. -1 marks
## "nothing read yet", which no real timing can collide with.
var _last_phys: float = -1.0
var _warmup_updates: int = 0


func setup(map_ref: Node2D) -> void:
	map = map_ref


# --- Public API ----------------------------------------------------------

## Clears the board, spawns `count` enemies on a fixed lattice, and measures.
## Takes about 4 seconds — under one MCP round trip, so run() and the read-back
## are two calls.
##
## DELIBERATELY DOES NOT GO THROUGH THE WAVE MACHINE. That path uses randf()
## scatter, takes 2.5 minutes, and its population DECAYS as enemies escape —
## which destroys the denominator of us_per_enemy. A benchmark whose n changes
## while it runs is not measuring what it claims to.
## skip_position_write is orthogonal to `ablation` — see Enemy's static of the
## same name. It is recorded in the result_line's variant column (V0-nw) so a row
## measured with it can never be compared against one without it by mistake.
func run(count: int, config_name: String = "loose", ablation: int = Enemy.BENCH_FULL, skip_position_write: bool = false) -> bool:
	if phase != Phase.IDLE:
		push_error("bench: already running")
		return false
	if not CONFIGS.has(config_name):
		push_error("bench: unknown config '%s' — expected one of %s" % [config_name, CONFIGS.keys()])
		return false

	# The highest-value line in this file. Without it every result below ~16.6ms
	# is clamped to the refresh rate and the whole table reads "60 / 60 / 60".
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_teardown_round()

	enemy_count = count
	config = config_name
	variant = ablation
	Enemy.bench_variant = ablation
	skip_write = skip_position_write
	Enemy.bench_skip_position_write = skip_position_write

	_spawn_lattice(count, CONFIGS[config_name])

	_frame_samples.clear()
	_phys_samples.clear()
	_frames_seen = 0
	_last_phys = -1.0
	_warmup_updates = 0
	phase = Phase.WARMUP
	return true


## Restores normal play. Call before playing the game again — the ablation
## variant is static and would otherwise leave the horde permanently crippled.
func reset() -> void:
	phase = Phase.IDLE
	Enemy.bench_variant = Enemy.BENCH_FULL
	# Reset alongside bench_variant for the same reason: both are static, so a
	# run that ends without clearing them leaves the horde crippled for the
	# rest of the session.
	Enemy.bench_skip_position_write = false
	skip_write = false
	_teardown_round()


func is_running() -> bool:
	return phase != Phase.IDLE


# --- Sampling ------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		return

	_frames_seen += 1

	var phys: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	# A genuine update, not the same stale value read again. Two consecutive
	# updates that happen to be bit-identical are dropped; that costs a few
	# extra frames and biases nothing.
	var changed: bool = not is_equal_approx(phys, _last_phys)
	if changed:
		_last_phys = phys

	# Warm-up is not superstition: it discards scene instantiation, every
	# enemy's _ready(), texture upload, and the physics server registering n
	# areas — all of which land in the first frames and none of which is the
	# steady-state cost being measured.
	#
	# It ALSO has to outlast the monitor's lag, which a frame count cannot
	# promise — hence the second condition. Without it the previous run's value
	# bleeds straight into this run's samples.
	if phase == Phase.WARMUP:
		if changed:
			_warmup_updates += 1
		if _frames_seen >= WARMUP_FRAMES and _warmup_updates >= WARMUP_UPDATES:
			phase = Phase.SAMPLING
			_frames_seen = 0
		return

	# delta IS per-frame, so frame samples stay per-frame. Only the monitor
	# needs change-gating, which is why the two arrays now differ in length.
	_frame_samples.append(delta * 1000.0)
	if changed:
		_phys_samples.append(phys)

	if _phys_samples.size() >= SAMPLE_UPDATES:
		_finish()
	elif _frames_seen >= MAX_SAMPLE_FRAMES:
		push_error(
			"bench: gave up after %d frames with only %d/%d monitor updates — TIME_PHYSICS_PROCESS may have stopped updating. Result is UNRELIABLE."
			% [_frames_seen, _phys_samples.size(), SAMPLE_UPDATES]
		)
		_finish()


func _finish() -> void:
	phase = Phase.IDLE

	frame_ms_p50 = _percentile(_frame_samples, 0.50)
	frame_ms_p95 = _percentile(_frame_samples, 0.95)
	frame_ms_max = _percentile(_frame_samples, 1.0)
	phys_ms_p50 = _percentile(_phys_samples, 0.50)
	phys_ms_p95 = _percentile(_phys_samples, 0.95)

	us_per_enemy = 0.0 if enemy_count <= 0 else phys_ms_p50 * 1000.0 / float(enemy_count)

	phys_pairs = int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
	node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# Three significant figures. Anything finer than the noise floor is not a
	# result — see a3_plan.md.
	result_line = "| %s | %s | %d | %s | %.2f | %.2f | %.2f | %.2f | %.1f | %d | %d |" % [
		BENCH_TAG, ("V%d-nw" % variant) if skip_write else ("V%d" % variant),
		enemy_count, config,
		frame_ms_p50, frame_ms_p95, phys_ms_p50, phys_ms_p95,
		us_per_enemy, phys_pairs, node_count,
	]
	history.append(result_line)


## Linear-interpolation-free percentile: sort, index, clamp. Good enough at 180
## samples and has no edge cases to get wrong.
func _percentile(samples: Array, q: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	var i := int(floor(q * (sorted.size() - 1)))
	return sorted[clampi(i, 0, sorted.size() - 1)]


# --- Board setup ---------------------------------------------------------

func _teardown_round() -> void:
	# Stop the wave machine first: an abort() after spawning would clear the
	# lattice out from under the measurement.
	if map.wave_manager != null:
		map.wave_manager.reset()
	map._clear_all_enemies()
	map._clear_placed_towers()
	map.round_state = map.RoundState.PRE_ROUND


## A fixed lattice, with NO RNG anywhere. A seeded RNG would also be repeatable,
## but a lattice additionally reproduces across engine versions and machines, and
## it makes density an explicit parameter rather than an emergent one.
##
## EVERY POSITION MUST BE ON THE FLOW FIELD, not merely off a wall. That is the
## difference between measuring the code path real gameplay takes and measuring a
## different, more expensive one:
##
##   - on the flow field  -> 1 flow lookup, 1 is_wall, separation.
##   - off it             -> get_flow_direction returns ZERO, so the enemy also
##                           fetches map.end_point TWICE and runs direction_to +
##                           distance_to, every frame, forever.
##   - standing on a wall -> _move_with_wall_slide takes its slide branch,
##                           which is 2 EXTRA is_wall() calls.
##
## The first version of this function filtered on `not is_wall()` and seeded the
## lattice at StartPoint, which put ~350 of 600 enemies off the map entirely —
## and the harness dutifully measured the zero-flow branch. The self-test caught
## it. Filtering on the flow field is what makes the number mean anything.
func _spawn_lattice(count: int, spacing: float) -> void:
	var slots := _walkable_lattice(spacing)

	if slots.size() < count:
		push_error(
			"bench: '%s' spacing (%.0fpx) fits only %d enemies on this map's %d walkable cells, but %d were asked for. Use a tighter config or a lower count — do NOT compare this run against others."
			% [config, spacing, slots.size(), map.flow_field.size(), count]
		)

	var placed := mini(count, slots.size())
	for i in range(placed):
		var enemy := GOBLIN_SCENE.instantiate()
		map.add_child(enemy)
		enemy.global_position = slots[i]
		# Frozen. The entire measured cost still runs — separation, the flow
		# lookup, and one is_wall() from the move — but positional drift, which
		# is the main source of run-to-run variance, does not.
		enemy.speed = 0.0

	enemy_count = placed


## Every lattice position inside the map's used rect that sits on reachable
## floor, in a deterministic row-major order. Bounded by the tilemap's own extent
## so it can never wander off-map.
func _walkable_lattice(spacing: float) -> Array:
	var rect: Rect2i = map.tile_map.get_used_rect()
	var top_left: Vector2 = map.tile_map.to_global(map.tile_map.map_to_local(rect.position))
	var bottom_right: Vector2 = map.tile_map.to_global(map.tile_map.map_to_local(rect.position + rect.size))

	var slots: Array = []
	var y := top_left.y
	while y <= bottom_right.y:
		var x := top_left.x
		while x <= bottom_right.x:
			var pos := Vector2(x, y)
			# flow_field membership is the authoritative "reachable open floor"
			# test — it is exactly what the BFS walked, so it excludes walls AND
			# anything unreachable behind them.
			if map.flow_field.has(map._cell_at(pos)):
				slots.append(pos)
			x += spacing
		y += spacing
	return slots
