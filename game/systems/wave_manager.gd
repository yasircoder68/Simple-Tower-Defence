extends Node

## Round-scoped wave sequencer. Owns which wave is running, how many of that
## wave's enemies are still unresolved, and the breather between waves.
##
## Built across A1's Track W: the phase machine and spawner (W-1), resolution
## accounting (W-2), the breather (W-3), reset guards (W-4), and the handover
## that deleted level_controller's flat one-shot spawner (W-5). That old path is
## gone; this is the only thing that puts enemies on the board.
##
## Nothing here may write to PlayerData. Wave state is round-scoped and is
## discarded with the round — see CLAUDE.md's state boundary table.

signal wave_started(wave_num: int, wave_total: int, enemy_count: int)
signal wave_cleared(wave_num: int)
signal breather_started(seconds: float)
signal all_waves_complete

## The SCENE half of the enemy registry. The STATS half is systems/enemy_types.gd,
## and they are deliberately in different layers: enemy.gd preloads the stats, so
## if the stats file preloaded these scenes (which use enemy.gd) that would be a
## cyclic reference GDScript refuses. Key sets are checked to match at setup().
const ENEMY_SCENES := {
	"goblin": preload("res://entities/enemies/goblin/goblin.tscn"),
	"skeleton": preload("res://entities/enemies/skeleton/skeleton.tscn"),
	"ogre": preload("res://entities/enemies/ogre/ogre.tscn"),
}

## Skeletons arrive as a squad rather than a trickle. With spawn intervals of
## 0.04–0.15s a run of 4 lands near-simultaneously, which is what makes them
## read as a rush instead of four unlucky fast goblins.
const SKELETON_PACK := 4

## The authored escalation curve. Composition and spawn interval — enemy HP and
## speed are constant across waves by decision (a1_plan.md), so escalation is
## density and mix, never durability.
##
## `count` is NOT authored here. It is derived in _build_waves() by summing the
## groups, so the wave's total and its spawn plan can never disagree — see the
## check in _start_wave(), and why that matters.
## Skeletons REPLACE goblins rather than adding to them, so every wave's total
## stays exactly on the authored curve (20/30/45/65/95). E-4 is a variety change,
## not a difficulty change — keeping the totals fixed is what lets the round
## still be compared against A1's tuning instead of needing a fresh baseline.
##
## Wave 1 is deliberately pure goblin: the first thing a player meets should
## teach the basic fight before it gains an exception.
const WAVE_TABLE := [
	{"groups": [{"type": "goblin", "count": 20}], "spawn_interval": 0.15},
	{"groups": [
		{"type": "goblin", "count": 26},
		{"type": "skeleton", "count": 4, "pack": SKELETON_PACK},
	], "spawn_interval": 0.12},
	{"groups": [
		{"type": "goblin", "count": 36},
		{"type": "skeleton", "count": 8, "pack": SKELETON_PACK},
		{"type": "ogre", "count": 1},
	], "spawn_interval": 0.09},
	{"groups": [
		{"type": "goblin", "count": 51},
		{"type": "skeleton", "count": 12, "pack": SKELETON_PACK},
		{"type": "ogre", "count": 2},
	], "spawn_interval": 0.06},
	{"groups": [
		{"type": "goblin", "count": 76},
		{"type": "skeleton", "count": 16, "pack": SKELETON_PACK},
		{"type": "ogre", "count": 3},
	], "spawn_interval": 0.04},
]

## A Timer cannot fire more than once per physics frame (16.7ms at 60Hz), so
## below this the knob silently stops responding and the wave just arrives at
## 60/sec. If a wave ever needs to be faster, spawn N per tick instead of
## shrinking this further.
const MIN_SPAWN_INTERVAL := 0.02

## Radius of the random scatter around StartPoint, carried over from the
## flat spawner this replaced — without it every enemy stacks on one pixel.
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
## One enemy type id per spawn of the CURRENT wave, in release order. Rebuilt at
## every _start_wave() and cleared by reset() — round-scoped state, so a lost
## round must not leave a stale plan for the next one to index into.
var _spawn_plan: Array = []
var _spawned_this_wave: int = 0
var _spawn_timer: Timer = null
var _breather_timer: Timer = null


func _ready() -> void:
	# A Timer, not an await loop. The old flat spawner awaited per enemy,
	# making it a coroutine that outlived everything: _clear_all_enemies()
	# could not touch it, and its round_state guard only helped if it happened
	# to wake while the round was over — between Play Again and Start it woke
	# into a fresh IN_ROUND and kept spawning. A Timer has nothing to leak,
	# stops on demand, and exposes its whole state to runtime_get_script_vars.
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)

	_breather_timer = Timer.new()
	_breather_timer.name = "BreatherTimer"
	_breather_timer.one_shot = true
	_breather_timer.timeout.connect(_on_breather_done)
	add_child(_breather_timer)


func setup(map_ref: Node2D) -> void:
	map = map_ref
	_assert_registries_agree()


## The two halves of the enemy registry live in different files for a good
## reason (see ENEMY_SCENES), which means they can drift. A stats entry with no
## scene fails at spawn, mid-wave; a scene with no stats falls back to defaults
## and quietly plays wrong. Catch both at startup instead.
func _assert_registries_agree() -> void:
	var EnemyTypes := preload("res://systems/enemy_types.gd")
	for id in ENEMY_SCENES:
		if not EnemyTypes.TYPES.has(id):
			push_error("wave_manager: enemy scene '%s' has no EnemyTypes.TYPES entry — it would spawn with default stats." % id)
	for id in EnemyTypes.TYPES:
		if not ENEMY_SCENES.has(id):
			push_error("wave_manager: enemy type '%s' has no scene in ENEMY_SCENES — a wave asking for it would fail at spawn." % id)


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
		var groups: Array = _scale_groups(row["groups"])
		var total := 0
		for g in groups:
			total += g["count"]

		result.append({
			"groups": groups,
			# Derived from the same numbers the spawn plan is built from, so the
			# two cannot disagree.
			"count": total,
			"spawn_interval": maxf(row["spawn_interval"], MIN_SPAWN_INTERVAL),
		})
	return result


## Scales one wave's groups by difficulty_scale so the group counts SUM to the
## scaled wave total, instead of each group rounding on its own.
##
## Independent per-group rounding lets the errors accumulate rather than cancel.
## At scale 1.6 wave 5's 76/16/3 rounds to 122/26/5 = 153, while the wave's
## authored total of 95 scales to 152. That +1 is tiny, but it breaks A2's rule
## that a composition change must not move the difficulty curve — and it only
## appeared once E-5 added a third group, because with two groups the errors
## happened to cancel. A drift that shows up when you add content is exactly the
## kind that gets blamed on the content.
##
## Largest-remainder apportionment: floor every group, then hand the leftover
## units to whichever groups were rounded down hardest. Deliberately the same
## rule _build_spawn_plan() uses to interleave types, applied here to counts.
##
## maxi(1, ...) still applies PER GROUP: a one-ogre group can never be scaled
## out of existence by a low difficulty_scale. When those floors push the sum
## past the target the floors win and the wave runs slightly large — losing the
## heavy entirely is the worse failure.
func _scale_groups(authored_groups: Array) -> Array:
	var authored_total := 0
	for authored in authored_groups:
		authored_total += authored["count"]
	var target: int = maxi(1, int(round(authored_total * map.difficulty_scale)))

	var counts: Array = []
	var remainders: Array = []
	var running := 0

	for authored in authored_groups:
		var exact: float = authored["count"] * map.difficulty_scale
		var floored: int = maxi(1, int(floor(exact)))
		counts.append(floored)
		remainders.append(exact - floor(exact))
		running += floored

	# Flooring drops strictly less than one unit per group, so at most one extra
	# unit per group is ever owed — a single pass reaches the target. Each unit
	# goes to the largest unspent remainder, and spent groups are marked -1.0 so
	# they cannot win twice; that also guarantees this loop terminates.
	while running < target:
		var best := -1
		var best_remainder := -1.0
		for gi in range(counts.size()):
			if remainders[gi] > best_remainder:
				best_remainder = remainders[gi]
				best = gi
		if best < 0:
			break
		counts[best] += 1
		remainders[best] = -1.0
		running += 1

	var scaled: Array = []
	for gi in range(authored_groups.size()):
		var authored: Dictionary = authored_groups[gi]
		var g: Dictionary = {"type": authored["type"], "count": counts[gi]}
		# Carry `pack` through. Omitting it here is what made E-4's SKELETON_PACK
		# inert: _build_spawn_plan() reads pack off the groups THIS function
		# produces, not off WAVE_TABLE, so a dropped key silently degraded every
		# pack to 1 and skeletons trickled in singly instead of arriving as a
		# squad. Nothing errored and every wave total stayed correct, which is
		# why E-4's totals-based acceptance check could not see it.
		if authored.has("pack"):
			g["pack"] = authored["pack"]
		scaled.append(g)
	return scaled


## Flattens a wave's groups into one type-id per spawn, in the order they will
## be released.
##
## Deterministic interleave, NOT a shuffle and NOT concatenation:
##   - concatenation would staple the single ogre to the end of the wave;
##   - a shuffle would make every measurement noisy and every regression
##     unreproducible, in a project that verifies by measurement.
##
## Largest-remainder: at each slot, release from whichever group is furthest
## behind its fair share. With one group it degenerates to "all goblins", which
## is exactly the pre-E-3 behaviour.
## Groups may declare a `pack`, which makes their members emit in contiguous
## runs rather than singly — the existing 0.04–0.15s spawn interval then
## delivers a pack near-simultaneously, which is what makes skeletons arrive as
## a squad. Distribution therefore runs over CHUNKS, not individuals: a group of
## 8 with pack 4 is two chunks competing for slots, and each chunk expands to
## four spawns. With pack 1 (the default) a chunk is one enemy and this
## degenerates exactly to the pre-E-4 behaviour.
func _build_spawn_plan(groups: Array, total: int) -> Array:
	var chunks_left: Array = []
	var placed_chunks: Array = []
	var remaining: Array = []
	var total_chunks := 0

	for g in groups:
		var pack: int = maxi(1, g.get("pack", 1))
		var count: int = g["count"]
		var chunks: int = int(ceil(float(count) / float(pack)))
		chunks_left.append(chunks)
		placed_chunks.append(0)
		remaining.append(count)
		total_chunks += chunks

	var plan: Array = []
	for slot in range(total_chunks):
		var best := 0
		var best_deficit := -INF
		for gi in range(groups.size()):
			if remaining[gi] <= 0:
				continue
			var fair_share: float = float(chunks_left[gi]) * float(slot + 1) / float(total_chunks)
			var deficit: float = fair_share - float(placed_chunks[gi])
			if deficit > best_deficit:
				best_deficit = deficit
				best = gi

		var pack_size: int = maxi(1, groups[best].get("pack", 1))
		# The final chunk of a group is short whenever count is not a multiple
		# of pack — mini() is what keeps the plan's length equal to the derived
		# count rather than overshooting it.
		var emit: int = mini(pack_size, remaining[best])
		for _i in range(emit):
			plan.append(groups[best]["type"])
		remaining[best] -= emit
		placed_chunks[best] += 1

	return plan


# --- Public API ---------------------------------------------------------

## Starts wave 1. Called from level_controller._start_round(); can also be
## driven directly via execute_code to test without pressing Start.
func begin() -> void:
	# Always start from a known state. Without this, a second begin() while a
	# wave is already running would rebuild _waves and reset the counters
	# underneath a live spawner — leaving two waves' worth of bookkeeping
	# fighting over one board.
	reset()

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
	# The breather timer too: a round lost during the gap would otherwise
	# start the next wave onto a board that has already resolved.
	if _breather_timer != null:
		_breather_timer.stop()
	phase = Phase.IDLE


## Returns to wave 0 / IDLE for a fresh round. Called from
## level_controller.start_new_round(), and by begin() so a round always starts
## from a known state.
func reset() -> void:
	abort()
	current_wave = 0
	wave_remaining = 0
	_spawned_this_wave = 0
	_waves = []
	_spawn_plan = []

	# A round lost mid-wave leaves level_controller's counter holding whatever
	# was still unresolved. Nothing reads it before the next wave overwrites
	# it, but leaving a stale count sitting in round-scoped state is how the
	# next reader of it gets quietly misled.
	if map != null:
		map.enemies_to_resolve = 0


## One enemy of the current wave has been killed or has escaped. Forwarded from
## level_controller.on_enemy_killed() / on_enemy_escaped(), which is the seam
## that lets this land without reopening that file.
func on_enemy_resolved() -> void:
	if phase != Phase.SPAWNING and phase != Phase.CLEARING:
		return
	if wave_remaining <= 0:
		return

	wave_remaining -= 1
	if wave_remaining > 0:
		return

	_advance_after_wave()


## Test hook: resolve the current wave immediately, board and all. Exists
## because playing five full waves by hand after every tuning change is not a
## workable loop.
##
## Frees the live enemies rather than pretending they resolved — leaving them
## alive would let their real deaths arrive later and decrement the NEXT wave's
## counter, which is the one desync this design can actually suffer.
func force_clear_wave() -> void:
	if phase != Phase.SPAWNING and phase != Phase.CLEARING:
		return

	_spawn_timer.stop()
	_spawned_this_wave = _waves[current_wave - 1]["count"]
	map._clear_all_enemies()
	wave_remaining = 0
	map.enemies_to_resolve = 0
	_advance_after_wave()
	# Real resolutions arrive through level_controller, which calls this right
	# after forwarding to on_enemy_resolved(). Without it the hook advances
	# waves but never ends the round — the shortcut would silently diverge from
	# the path it is meant to stand in for.
	map._check_round_complete()


## A wave has been fully resolved: either the next one starts, or the round is
## over.
func _advance_after_wave() -> void:
	wave_cleared.emit(current_wave)

	if current_wave >= _waves.size():
		phase = Phase.DONE
		all_waves_complete.emit()
		# Deliberately does NOT touch map.enemies_to_resolve, which is already
		# 0 — so level_controller's own _check_round_complete(), running
		# immediately after this returns, ends the round won through the exact
		# path M1 already uses (gold-once ledger, save flush, round_ended).
		# Re-implementing that here would risk the verified economy for nothing.
		return

	_begin_breather()


## The gap between waves. Not a build phase: the round stays IN_ROUND, so
## placement and upgrades remain locked with no extra code.
func _begin_breather() -> void:
	# Reserve the NEXT wave's enemies on level_controller's counter BEFORE the
	# gap opens. Without this the counter sits at 0 for the whole breather —
	# and _check_round_complete() runs immediately after this returns, on the
	# very resolution that cleared the wave, so the round would be declared won
	# after wave 1. That is the same "victory after wave 1" failure W-2 exists
	# to prevent, re-entering through the gap the breather creates.
	#
	# Reserving before the enemies exist is not a new idea here: _start_round()
	# always set enemies_to_resolve before a single one had spawned.
	map.enemies_to_resolve = _waves[current_wave]["count"]

	# A zero-length breather is a valid tuning choice, and Timer rejects a
	# wait_time of 0 — go straight on instead.
	if breather_seconds <= 0.0:
		_start_wave(current_wave + 1)
		return

	phase = Phase.BREATHER
	breather_started.emit(breather_seconds)
	_breather_timer.wait_time = breather_seconds
	_breather_timer.start()


func _on_breather_done() -> void:
	# abort() stops the timer, but a timeout already in flight would otherwise
	# start a wave into a round that has ended.
	if phase != Phase.BREATHER:
		return
	_start_wave(current_wave + 1)


## Seconds left in the breather, for the HUD. 0 when not in one.
func get_breather_remaining() -> float:
	if phase != Phase.BREATHER or _breather_timer == null:
		return 0.0
	return _breather_timer.time_left


## Ends the breather early. Driven by the UI's Skip button — a player who does
## not want to wait should not have to.
func skip_breather() -> void:
	if phase != Phase.BREATHER:
		return
	_breather_timer.stop()
	_start_wave(current_wave + 1)


# --- Spawning -----------------------------------------------------------

func _start_wave(index: int) -> void:
	current_wave = index
	Audio.play("wave_start")
	var wave: Dictionary = _waves[index - 1]
	wave_remaining = wave["count"]
	_spawned_this_wave = 0
	phase = Phase.SPAWNING

	_spawn_plan = _build_spawn_plan(wave["groups"], wave["count"])
	# Not an assert(): asserts are stripped from release builds, and this is the
	# one disagreement that silently breaks a round rather than crashing it. If
	# the plan is SHORT the spawner runs out and the wave never reaches its
	# count, so the round hangs in CLEARING forever; if it is LONG the extra
	# entries are never reached. Neither shows an error on its own.
	if _spawn_plan.size() != wave["count"]:
		push_error(
			"wave_manager: wave %d spawn plan has %d entries but count is %d — the round would %s."
			% [index, _spawn_plan.size(), wave["count"],
				"hang forever" if _spawn_plan.size() < wave["count"] else "under-spawn"]
		)

	# Top level_controller's counter up for this wave. It decrements that
	# counter per resolution exactly as it always has, and this overwrite
	# re-syncs the two at every wave boundary — so they cannot drift apart
	# even though both are being decremented on the same events.
	#
	# The important consequence: on the LAST wave nothing tops it up, so it
	# reaches 0 naturally and _check_round_complete() ends the round won
	# without this manager needing to reach into _end_round() at all.
	map.enemies_to_resolve = wave["count"]

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

	if _spawned_this_wave >= _spawn_plan.size():
		push_error("wave_manager: spawn plan exhausted at %d — stopping to avoid spawning nothing forever." % _spawned_this_wave)
		_spawn_timer.stop()
		phase = Phase.CLEARING
		return

	var enemy_type: String = _spawn_plan[_spawned_this_wave]
	# Annotated, not inferred: `:=` on a value read out of an untyped Dictionary
	# is a compile error, not a warning (CLAUDE.md, Conventions).
	var scene: PackedScene = ENEMY_SCENES[enemy_type]
	var enemy := scene.instantiate()
	# Must be a direct child of the map: enemy.gd reaches its map via
	# get_parent() and reads map.end_point off it.
	map.add_child(enemy)
	var angle := randf() * TAU
	var scatter := randf_range(0.0, SPAWN_SCATTER)
	enemy.global_position = map.start_point.global_position + Vector2(cos(angle), sin(angle)) * scatter

	_spawned_this_wave += 1
	if _spawned_this_wave >= wave["count"]:
		_spawn_timer.stop()
		# Everything is on the board; now we wait for it to be resolved. W-2
		# decides what happens when it is.
		phase = Phase.CLEARING
