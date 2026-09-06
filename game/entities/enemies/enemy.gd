class_name Enemy
extends Node2D

## NOT an Area2D. A3's S-1 retired the physics presence, and the reason is
## measured rather than assumed: assigning global_position on an Area2D forces a
## PhysicsServer2D transform sync, which cost 12.2 us/enemy - 19% of the frame -
## even with the horde frozen and writing the same value it already held. See
## a3_plan.md's V0-nw ablation.
##
## Nothing in this script ever used an Area2D API; the node type existed only so
## towers could find enemies with get_overlapping_areas(). They now ask the map's
## spatial grid instead, which answers the same question without a broadphase.

## The shared enemy base. Deliberately NOT inside a per-type folder: goblin,
## skeleton and ogre are .tscn files that all point at THIS script, so it sits
## one level up at entities/enemies/enemy.gd rather than colocated with any one
## of them. That is the one documented exception to CLAUDE.md's colocation
## convention, and it is what makes "adding the next enemy is cheap" true —
## a new type is a scene and a registry entry, with no script of its own.
##
## Enemy scripts must never name LevelController: the map is duck-typed through
## `map`, deliberately, so that `class_name Enemy` here and a class_name on the
## controller could never form a cyclic reference.

## The group every enemy joins. Single definition, referenced by archer, wizard,
## arrow, fire, boulder and level_controller.
##
## Joined in code, NOT declared in the .tscn. It used to be scene data only —
## `groups=["zombie"]` in the enemy scene with no add_to_group() anywhere — which
## meant a new enemy scene could silently forget it and be invisible to every
## tower, the spatial grid and every AoE, with no error at all. Nine string
## literals collapse to this one const; a typo in the const NAME is now a parse
## error instead of a silent miss.
##
## Type-neutral, like everything else the machinery is named after: skeletons and
## ogres join this same group. Because every consumer reads the const rather than
## a literal, R-1 flipped the value here and nowhere else.
const GROUP := "enemy"

## Map-side members an enemy needs to score. Either the map implements ALL of
## them or NONE — testbed/clean_area.tscn implements none, which is why this is
## probed rather than required.
const ROUND_CONTRACT := ["on_enemy_killed", "on_enemy_escaped"]

## Bench ablation stages. Cumulative: each skips everything the one above it
## skips, plus one more thing. Measuring a stage means subtracting its row from
## the row above — which gives a full cost breakdown with NO instrumentation
## inside any inner loop. See a3_plan.md's M-1.
##
## BENCH_FULL in all normal play, so the cost of this seam is one int compare
## per enemy per frame. That overhead is itself measured (a3_plan M-0's second
## self-test) — if it is detectable, the harness distorts what it measures.
const BENCH_FULL := 0
const BENCH_NO_SEPARATION := 1
const BENCH_NO_FLOW := 2
const BENCH_NO_MOVE := 3
const BENCH_NO_PROCESS := 4
const BENCH_NO_GRID := 5

## Set by systems/bench.gd only. Static so one write reaches every enemy without
## iterating the horde.
static var bench_variant: int = BENCH_FULL

## Deliberately ORTHOGONAL to the V0-V5 ladder rather than a sixth rung, because
## the ladder is ordinal — each variant strictly does less than the one below —
## and this needs to do MORE than V3 (it keeps is_wall) while doing LESS than V0
## (it skips the position write). No single ordinal value can express that.
##
## Exists to answer one question M-1 could not: "is_wall() + the move" measured
## 17.5 us/enemy, 27% of the frame, and the move ends in a global_position
## assignment on an Area2D — which forces a PhysicsServer2D transform sync per
## enemy per frame. This splits that 17.5 between the wall test and the sync,
## and the answer decides whether a3_plan's S-1 or P-1 leads the ladder.
##
## NOTE the horde does not move while this is set, so it is a MEASUREMENT tool
## only — never leave it true, exactly as with bench_variant.
static var bench_skip_position_write: bool = false

const SEPARATION_RADIUS := 32.0
const SEPARATION_RADIUS_SQ := SEPARATION_RADIUS * SEPARATION_RADIUS
const MAX_SEPARATION_NEIGHBORS := 10
# Hard ceiling on candidates examined per frame. Separation is a soft cosmetic
# force, so sampling a bounded subset of a dense cell looks identical and keeps
# the cost linear in enemy count instead of linear in local density.
const MAX_SEPARATION_CHECKS := 24
const ARRIVAL_RADIUS := 30.0

const EnemyTypes := preload("res://systems/enemy_types.gd")

## Which row of EnemyTypes.TYPES this scene is. The ONLY stat-ish thing a
## `.tscn` carries — everything else is resolved from the registry at spawn, so
## goblin/skeleton/ogre are three scenes pointing at this one script.
@export var enemy_id: String = "goblin"

# --- Resolved from EnemyTypes at _ready(). Deliberately NOT @export ----------
#
# Same rule as tower stats: no @export, nothing baked into a .tscn. An inspector
# value here would silently win over the registry and be invisible to whoever
# later tunes the numbers in one place and wonders why nothing moved.

var max_hp: int = 10
var speed: float = 100.0
## Silver the round controller earns via PlayerData when this enemy is
## KILLED (not when it escapes — see _die() vs _escape() below).
var silver_reward: int = 2
## Lives this costs on escape. Carried by E-2; every enemy costs 1 until then.
var life_cost: int = 1
## Target size for projectile hit tests, in world px. See enemy_types.gd.
var hit_radius: float = 16.0
## Skips push-apart entirely — an early-out, so this is cheaper, not dearer.
var ignore_separation: bool = false
## Scales how hard THIS enemy is pushed by others. It still pushes them
## normally, since it still contributes its position to the grid.
var separation_weight: float = 1.0

var hp: int = 10

@onready var map = get_parent()

# The grid dictionary is rebuilt in place (cleared + refilled) every frame, so
# the REFERENCE is stable and safe to cache. Fetching it per frame through
# map.get() instead costs a dictionary copy per enemy per frame.
var _grid: Dictionary = {}

## Answered once at spawn instead of at every call site. See _probe_round_contract().
var _has_round_contract: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_resolve_stats()
	_has_round_contract = _probe_round_contract()

	if "enemy_grid" in map:
		_grid = map.enemy_grid

	_on_spawn()


## Pulls this enemy's numbers from the registry. Resolved once, at spawn —
## exactly like archer.gd/wizard.gd resolving from TowerStats. Nothing re-reads
## it later, so an enemy already on the board keeps the numbers it spawned with.
func _resolve_stats() -> void:
	var stats := EnemyTypes.get_stats(enemy_id)
	max_hp = stats["max_hp"]
	speed = stats["speed"]
	silver_reward = stats["silver_reward"]
	life_cost = stats["life_cost"]
	hit_radius = stats["hit_radius"]
	ignore_separation = stats["ignore_separation"]
	separation_weight = stats["separation_weight"]
	hp = max_hp


# --- Behaviour hooks, empty in the base ---------------------------------
#
# Event-level, never per-frame. A per-frame virtual would be a dispatch A3's
# manager loop then has to untangle; type differences that survive that rewrite
# are DATA the loop can branch on (ignore_separation, separation_weight), not
# methods it must call. Keep it that way.
#
# These exist so the first enemy with genuine behaviour — the Troll's enrage at
# 50% HP — costs a six-line subclass instead of another @export on this file.

func _on_spawn() -> void:
	pass


func _on_damaged(_amount: int) -> void:
	pass


func _on_death() -> void:
	pass


## Asks the whole contract at once, rather than each call site guarding itself.
##
## The old design called has_method() independently in _die() and _escape(), so
## a half-finished rename produced a PARTIALLY working game: kills still awarded
## silver while escapes silently cost nothing, with no error anywhere. Probing
## together collapses that into two honest outcomes — everything routes, or
## nothing does and you are told exactly what is missing.
func _probe_round_contract() -> bool:
	var missing: Array = []
	for member in ROUND_CONTRACT:
		if not map.has_method(member):
			missing.append(member)

	if missing.is_empty():
		return true

	if missing.size() == ROUND_CONTRACT.size():
		# A map with no round lifecycle at all — testbed/clean_area.tscn.
		# Legitimate: enemies there just despawn without scoring.
		return false

	# Some but not all. That is always a bug and never a design — it is exactly
	# the silent partial failure this probe exists to make impossible.
	push_error("Enemy: map '%s' implements only part of the round contract (missing %s). Kills or escapes would silently do nothing." % [map.name, missing])
	return false

func _physics_process(delta: float) -> void:
	if bench_variant >= BENCH_NO_PROCESS:
		return

	if not map.has_method("get_flow_direction"):
		return

	var flow_dir: Vector2 = Vector2.ZERO
	if bench_variant < BENCH_NO_FLOW:
		flow_dir = map.get_flow_direction(global_position)

		# A zero vector means we're standing in the target cell. Walk the last
		# stretch to the exact end position, then despawn on arrival.
		if flow_dir == Vector2.ZERO:
			flow_dir = global_position.direction_to(map.end_point.global_position)
			if global_position.distance_to(map.end_point.global_position) < ARRIVAL_RADIUS:
				_escape()
				return

	var separation_push := Vector2.ZERO
	# ignore_separation is checked FIRST because it is an early-out: an enemy
	# that ignores the crowd never enters the 3x3 scan at all, so it is cheaper
	# than one that does.
	if not ignore_separation and bench_variant < BENCH_NO_SEPARATION:
		separation_push = _separation() * separation_weight

	if bench_variant >= BENCH_NO_MOVE:
		return

	var desired_dir := (flow_dir + separation_push * 1.5).normalized()
	if desired_dir == Vector2.ZERO:
		desired_dir = flow_dir

	_move_with_wall_slide(desired_dir * speed * delta)


# Soft push-apart so the horde behaves like a fluid.
#
# Reads positions straight out of the map's spatial grid (a plain Array of
# Vector2 per cell — packed arrays are copy-on-write and copy on every append). Two things matter for speed here and both were learned the hard
# way: never build a merged candidate list (the allocation dwarfs the work), and
# never reach through a node reference in the inner loop (each `other.global_position`
# is a Variant dynamic dispatch — with ~200 candidates per enemy per frame that
# alone took 600 enemies from 60 FPS to 2).
func _separation() -> Vector2:
	# clean_area.tscn drives enemies too and has no grid — fall back to no push.
	if _grid.is_empty():
		return Vector2.ZERO

	var my_pos := global_position
	var separation := Vector2.ZERO
	var neighbor_count := 0
	var checks := 0
	var base := Vector2i(
		floori(my_pos.x / SEPARATION_RADIUS),
		floori(my_pos.y / SEPARATION_RADIUS))

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := base + Vector2i(dx, dy)
			# ONE hash, not two. has()-then-[] hashes the same key twice, and
			# this runs nine times per enemy per frame whether or not the cell
			# has anything in it. Untyped on purpose: get() returns null on a
			# miss, so it cannot be annotated Array.
			var cell = _grid.get(key)
			if cell == null:
				continue
			for other_pos in cell:
				checks += 1
				if checks > MAX_SEPARATION_CHECKS:
					return separation
				var offset: Vector2 = my_pos - other_pos
				var dist_sq := offset.length_squared()
				# dist_sq == 0 is this enemy's own entry in the grid.
				if dist_sq >= SEPARATION_RADIUS_SQ or dist_sq <= 0.0:
					continue
				var dist := sqrt(dist_sq)
				separation += (offset / dist) * (1.0 - (dist / SEPARATION_RADIUS))
				neighbor_count += 1
				if neighbor_count >= MAX_SEPARATION_NEIGHBORS:
					return separation
	return separation


# Walk into the wall, and if that fails try each axis on its own so the horde
# slides along surfaces instead of piling up against them.
func _move_with_wall_slide(step: Vector2) -> void:
	# Every branch below is guarded, not just the first, so the flag means
	# "no position write at all" rather than "no position write on open
	# ground" — a partial guard would leave wall-adjacent enemies still
	# paying the sync and quietly understate what it costs.
	if not map.is_wall(global_position + step):
		if not bench_skip_position_write:
			global_position += step
		return

	var slide_x := global_position + Vector2(step.x, 0)
	if not map.is_wall(slide_x):
		if not bench_skip_position_write:
			global_position = slide_x
		return

	var slide_y := global_position + Vector2(0, step.y)
	if not map.is_wall(slide_y):
		if not bench_skip_position_write:
			global_position = slide_y


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	_on_damaged(amount)
	if hp <= 0:
		_die()


## Killed by a tower. Awards silver via the round controller, then despawns.
## Gated on the contract probe rather than a local has_method(), so this and
## _escape() can never disagree about whether the map is scoring.
func _die() -> void:
	_on_death()
	if _has_round_contract:
		map.on_enemy_killed(silver_reward)
	queue_free()


## Reached the end point unharmed. Costs the round a life instead of a silent
## despawn. Same gate as _die() — deliberately the same bool, not a second probe.
func _escape() -> void:
	if _has_round_contract:
		map.on_enemy_escaped(life_cost)
	queue_free()
