extends Node

## Round-scoped wave sequencer. Owns which wave is running, how many of that
## wave's enemies are still unresolved, and the breather between waves.
##
## A1 Track W. W-1 (this) owns the phase machine and the spawner; W-2 takes over
## resolution accounting; W-3 adds the breather; W-5 hands the round over from
## level_controller's flat spawn_zombies(). Until W-5 the old path is still
## live — see the note on zombie_count in a1_plan.md's Track W intro.
##
## Nothing here may write to PlayerData. Wave state is round-scoped and is
## discarded with the round — see CLAUDE.md's state boundary table.

signal wave_started(wave_num: int, wave_total: int, enemy_count: int)
signal wave_cleared(wave_num: int)
signal breather_started(seconds: float)
signal all_waves_complete

const ZOMBIE_SCENE := preload("res://entities/enemies/zombie/zombie.tscn")

## The authored escalation curve. Count and spawn interval only — enemy HP and
## speed are constant across waves by decision (a1_plan.md), which is why this
## manager never touches the enemy scene: it instantiates and positions, and
## nothing else.
const WAVE_TABLE := [
	{"count": 20, "spawn_interval": 0.15},
	{"count": 30, "spawn_interval": 0.12},
	{"count": 45, "spawn_interval": 0.09},
	{"count": 65, "spawn_interval": 0.06},
	{"count": 95, "spawn_interval": 0.04},
]

## A Timer cannot fire more than once per physics frame (16.7ms at 60Hz), so
## below this the knob silently stops responding and the wave just arrives at
## 60/sec. If a wave ever needs to be faster, spawn N per tick instead of
## shrinking this further.
const MIN_SPAWN_INTERVAL := 0.02

## Radius of the random scatter around StartPoint, carried over from the flat
## spawn_zombies() this replaces — without it every enemy stacks on one pixel.
const SPAWN_SCATTER := 40.0

## Seconds of breather between waves. Not a build phase — placement and
## upgrades stay locked, which costs no code because the round is still
## IN_ROUND throughout. W-3 uses this.
@export var breather_seconds: float = 12.0

## Private to this manager on purpose. RoundState deliberately gains no
## BETWEEN_WAVES value: keeping the round IN_ROUND for its whole duration means
## is_valid_placement(), _upgrades_allowed(), _input()'s tower branch,
## remove_tower() and begin_move() all keep working untouched.
enum Phase { IDLE, SPAWNING, CLEARING, BREATHER, DONE }

var phase: Phase = Phase.IDLE
## 1-based index of the wave being run. 0 while idle.
var current_wave: int = 0
## Spawned-but-unresolved enemies in the CURRENT wave. Set to the full wave
## count when a wave starts, not incremented per spawn, so it cannot reach zero
## early while enemies are still being fed onto the board. W-2 decrements it.
var wave_remaining: int = 0

var map: Node2D = null

## Resolved wave specs for THIS level, built at begin() from WAVE_TABLE plus
## the level's wave_count and difficulty_scale.
var _waves: Array = []
var _spawned_this_wave: int = 0
var _spawn_timer: Timer = null


func _ready() -> void:
	# A Timer, not an await loop. The old spawn_zombies() awaited per zombie,
	# making it a coroutine that outlived everything: _clear_all_zombies()
	# could not touch it, and its round_state guard only helped if it happened
	# to wake while the round was over — between Play Again and Start it woke
	# into a fresh IN_ROUND and kept spawning. A Timer has nothing to leak,
	# stops on demand, and exposes its whole state to runtime_get_script_vars.
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)


func setup(map_ref: Node2D) -> void:
	map = map_ref


# --- Wave construction --------------------------------------------------

## One authored curve plus two per-level numbers, rather than a bespoke table
## per level. difficulty_scale multiplies count only — spawn_interval is a
## pacing decision, not a difficulty one.
func _build_waves() -> Array:
	var result: Array = []
	var rows: int = map.wave_count
	if rows > WAVE_TABLE.size():
		push_warning("wave_manager: level asks for %d waves but WAVE_TABLE has %d — clamping." % [rows, WAVE_TABLE.size()])
		rows = WAVE_TABLE.size()

	for i in range(rows):
		var row: Dictionary = WAVE_TABLE[i]
		result.append({
			"count": maxi(1, int(round(row["count"] * map.difficulty_scale))),
			"spawn_interval": maxf(row["spawn_interval"], MIN_SPAWN_INTERVAL),
		})
	return result


# --- Public API ---------------------------------------------------------

## Starts wave 1. Called from level_controller._start_round() once W-5 lands;
## until then, drive it directly to test.
func begin() -> void:
	_waves = _build_waves()
	if _waves.is_empty():
		phase = Phase.DONE
		all_waves_complete.emit()
		return
	_start_wave(1)


## Stops everything dead — spawner included. Called from
## level_controller._end_round(), which has nothing else that halts a running
## spawner.
##
## Implemented here rather than waiting for W-4 because W-1 is what creates the
## thing that needs stopping: leaving this inert for one commit would mean a
## lost round keeps feeding enemies onto a board that already resolved.
func abort() -> void:
	if _spawn_timer != null:
		_spawn_timer.stop()
	phase = Phase.IDLE


## Returns to wave 0 / IDLE for a fresh round. Called from
## level_controller.start_new_round(). W-4 finishes this.
func reset() -> void:
	abort()
	current_wave = 0
	wave_remaining = 0
	_spawned_this_wave = 0
	_waves = []


## One enemy of the current wave has been killed or has escaped. Forwarded from
## level_controller.on_zombie_killed() / on_zombie_escaped().
##
## This seam is the entire reason W-2's counter split does not have to reopen
## level_controller.gd. Until then level_controller keeps its own
## zombies_to_resolve accounting and this is inert. W-2 fills this in.
func on_enemy_resolved() -> void:
	pass


## Test hook: resolve the current wave immediately. Exists because playing five
## full waves by hand after every tuning change is not a workable loop.
## W-2 fills this in.
func force_clear_wave() -> void:
	pass


## Ends the breather early. Also driven by the UI's Skip button.
## W-3 fills this in.
func skip_breather() -> void:
	pass


# --- Spawning -----------------------------------------------------------

func _start_wave(index: int) -> void:
	current_wave = index
	var wave: Dictionary = _waves[index - 1]
	wave_remaining = wave["count"]
	_spawned_this_wave = 0
	phase = Phase.SPAWNING

	wave_started.emit(current_wave, _waves.size(), wave["count"])

	_spawn_timer.wait_time = wave["spawn_interval"]
	_spawn_timer.start()
	# First enemy goes out now rather than one interval from now, so a wave
	# does not open with dead air.
	_spawn_one()


func _on_spawn_tick() -> void:
	# The timer is stopped on every path that leaves SPAWNING, so this is a
	# belt-and-braces guard against a tick already in flight when that happened.
	if phase != Phase.SPAWNING:
		_spawn_timer.stop()
		return
	_spawn_one()


func _spawn_one() -> void:
	var wave: Dictionary = _waves[current_wave - 1]

	var zombie := ZOMBIE_SCENE.instantiate()
	# Must be a direct child of the map: zombie.gd reaches its map via
	# get_parent() and reads map.end_point off it.
	map.add_child(zombie)
	var angle := randf() * TAU
	var scatter := randf_range(0.0, SPAWN_SCATTER)
	zombie.global_position = map.start_point.global_position + Vector2(cos(angle), sin(angle)) * scatter

	_spawned_this_wave += 1
	if _spawned_this_wave >= wave["count"]:
		_spawn_timer.stop()
		# Everything is on the board; now we wait for it to be resolved. W-2
		# decides what happens when it is.
		phase = Phase.CLEARING
