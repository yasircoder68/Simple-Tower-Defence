extends Node

## Round-scoped wave sequencer. Owns which wave is running, how many of that
## wave's enemies are still unresolved, and the breather between waves.
##
## STUB — A1 Step 0. Every method below is deliberately inert. The seams in
## level_controller.gd already call into them, which is what lets Track W fill
## this file in without reopening that one. See a1_plan.md, Track W.
##
## Nothing here may write to PlayerData. Wave state is round-scoped and is
## discarded with the round — see CLAUDE.md's state boundary table.

signal wave_started(wave_num: int, wave_total: int, enemy_count: int)
signal wave_cleared(wave_num: int)
signal breather_started(seconds: float)
signal all_waves_complete

## The authored escalation curve. Count and spawn interval only — enemy HP and
## speed are constant across waves by decision (a1_plan.md), which is why this
## manager never touches the enemy scene: it instantiates and positions, and
## nothing else.
##
## spawn_interval is floored at MIN_SPAWN_INTERVAL because a Timer cannot fire
## more than once per physics frame; below that the knob silently stops
## responding and the wave just arrives at 60/sec.
const WAVE_TABLE := [
	{"count": 20, "spawn_interval": 0.15},
	{"count": 30, "spawn_interval": 0.12},
	{"count": 45, "spawn_interval": 0.09},
	{"count": 65, "spawn_interval": 0.06},
	{"count": 95, "spawn_interval": 0.04},
]

const MIN_SPAWN_INTERVAL := 0.02

## Seconds of breather between waves. Not a build phase — placement and
## upgrades stay locked, which costs no code because the round is still
## IN_ROUND throughout.
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
## early while enemies are still being fed onto the board.
var wave_remaining: int = 0

var map: Node2D = null


func setup(map_ref: Node2D) -> void:
	map = map_ref


# --- Public API (inert until Track W) -----------------------------------

## Starts wave 1. Called from level_controller._start_round().
## W-1 fills this in.
func begin() -> void:
	pass


## Stops everything dead — spawner and breather both. Called from
## level_controller._end_round(), which currently has nothing that halts a
## running spawner. W-4 fills this in.
func abort() -> void:
	pass


## Returns to wave 0 / IDLE for a fresh round. Called from
## level_controller.start_new_round(). W-4 fills this in.
func reset() -> void:
	pass


## One enemy of the current wave has been killed or has escaped. Forwarded from
## level_controller.on_zombie_killed() / on_zombie_escaped().
##
## This seam is the entire reason W-2's counter split does not have to reopen
## level_controller.gd. Until then level_controller keeps its own
## zombies_to_resolve accounting and this is inert. W-2 fills this in.
func on_enemy_resolved() -> void:
	pass


## Test hook: resolve the current wave immediately. Exists because
## node_call_method is the reliable MCP verb and playing five full waves by
## hand after every tuning change is not a workable loop. W-2 fills this in.
func force_clear_wave() -> void:
	pass


## Ends the breather early. Also driven by the UI's Skip button.
## W-3 fills this in.
func skip_breather() -> void:
	pass
