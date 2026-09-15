extends Node2D

## A2's first ability payload: a barrage that damages everything inside a
## rotatable RECTANGLE repeatedly for DURATION, rather than once like the boulder.
##
## Aimed base-first: the player presses to pin the rectangle's base edge, moves
## the cursor to swing the far end around it, and releases to cast. The rectangle
## is a FIXED length — the cursor sets the angle only, never the size — so the
## covered area cannot be inflated by dragging further.
##
## This is the commit that tests a1_plan's B-4 promise — that adding an ability
## is one registry entry plus one payload folder. ability_manager.gd gained an
## ABILITIES row and NOTHING ELSE: the bar builds its own slot, the number key
## selects it, and the aim marker sizes itself, all by iterating the registry.
##
## Deliberately a plain Node2D, NOT an Area2D — same reasoning as boulder.gd. It
## finds victims by querying the map's spatial grid, so it needs no collision
## shape and adds no monitoring body to a 152-enemy wave, which is exactly the
## O(n^2) collapse CLAUDE.md's collision layer table exists to prevent.

## Read by ability_manager.get_aim_shape() to build the aim preview, so the
## preview can never drift from the real blast. SHAPE is the optional const
## aim_marker matches on; a payload that omits it is a circle, which is what
## boulder still is. Not in TowerStats: abilities are not one of the three
## upgrade tracks the player buys, the same reasoning that keeps wizard.gd's
## AOE_RADIUS local to that script. Tuned at a2_plan.md's step 11.
const SHAPE := "rect"
## Across the aim direction.
const WIDTH := 90.0
## Along it, forward from the base edge the player pinned.
const LENGTH := 260.0

## --- Cosmetics ---------------------------------------------------------
##
## PURELY VISUAL. The damage is the box test in _on_tick(); where any individual
## arrow sprite happens to land has no effect on it. That separation is
## deliberate: tying damage to the visual would make the barrage's real
## footprint depend on a random number, and randf() would then be sitting in
## the middle of a system this project verifies by exact measurement.
##
## Reuses the archer's arrow art rather than owning a copy — a DELIBERATE
## exception to CLAUDE.md's colocation rule, on the grounds that these are the
## same object: replacing the archer's arrow should re-skin the barrage too,
## and two copies would let them silently diverge. Noted here because a
## cross-folder art reference is otherwise exactly the kind of thing the
## convention exists to prevent.
const ARROW_TEXTURE := preload("res://entities/projectiles/arrow/arrow.png")
## One volley per tick. Roughly nine arrows are in the air at any moment, which
## is nothing beside a 152-enemy wave.
const ARROWS_PER_VOLLEY := 7
## Both tuned by looking at a frozen frame, not by arithmetic. The first pass
## dropped arrows 340px in 0.22s — 1500 px/s, which is faster than the eye
## tracks, so the barrage read as an empty zone with occasional flickers above
## it. Shorter fall, slower, and they are legible as arrows.
const ARROW_FALL_HEIGHT := 220.0
## LONGER than TICK_INTERVAL, deliberately: volleys overlap slightly, so the
## effect reads as continuous rain rather than discrete pulses. The earlier
## non-overlapping version looked like a stutter.
const ARROW_FALL_TIME := 0.32
## Per-arrow jitter on that time. Without it every arrow in a volley spawns on
## one horizontal line and lands in unison — a falling ruler, not rain. Visible
## immediately in a frozen frame, invisible in any amount of reasoning about it.
const ARROW_FALL_JITTER := 0.35
## arrow.png is 8x8; the archer flies it at 5. Slightly smaller here because a
## volley wants to read as many arrows, but not so small it becomes specks —
## which is exactly what 3.0 looked like.
const ARROW_SCALE := 4.0
## Absolute, not relative to this node. The ground zone sits BELOW the horde
## (z 5 vs 10) so it never hides an enemy, while the falling arrows belong
## ABOVE it — one parent cannot express both relatively.
const ARROW_Z := 25
const DAMAGE_PER_TICK := 4
const TICK_INTERVAL := 0.25
const DURATION := 3.0

## Set by ability_manager before add_child. Not resolved by a group scan here
## because the caller already holds the reference.
var map: Node = null

## Exposed deliberately: a 3s barrage is shorter than an MCP round trip (~5s),
## so the only way to observe one mid-flight is to read a counter off the live
## node. Verification is a design constraint in this project, not an afterthought.
var ticks_done: int = 0

var _timer: Timer = null
## The drifted-query push_error fires once per payload, not once per tick — an
## error worth shouting is not worth shouting twelve times per cast.
var _fallback_warned: bool = false


func _ready() -> void:
	# NOT global_position. ability_manager.cast() calls add_child() BEFORE it
	# assigns the world position, so this node is still sitting at the origin
	# here. Only LOCAL transforms are safe in _ready(); the damage origin is
	# read per tick in _on_tick(). boulder.gd dodges the identical trap by
	# touching only sprite.position here and reading global_position at impact.
	var zone: Sprite2D = $Zone
	# centered = false so the sprite starts AT the origin and extends forward
	# along +X, matching where the damage box actually is. Left centred it would
	# straddle the base edge and paint half the barrage behind the player's
	# anchor — a preview/damage mismatch of exactly the kind reading geometry off
	# this script is meant to prevent.
	zone.centered = false
	zone.scale = Vector2(LENGTH, WIDTH)
	zone.position = Vector2(0.0, -WIDTH * 0.5)

	# A Timer, not an await loop. wave_manager's W-1 learned this the expensive
	# way: a coroutine tick loop has nothing that can stop it, outlives whatever
	# spawned it, and can wake into a round that already ended. A Timer stops on
	# demand and exposes its whole state to runtime_get_script_vars.
	_timer = Timer.new()
	_timer.name = "TickTimer"
	_timer.wait_time = TICK_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start()
	# ONE sound per cast, never per tick: the file is a whole volley (bows, whistle, patter)
	# timed to the barrage, and playing it every tick would stack twelve volleys.
	Audio.play("rain_of_arrows")


func _on_tick() -> void:
	# THE SHARED RULE FOR MULTI-TICK PAYLOADS, established here while there are
	# two of them rather than seven. A barrage can still be alive when
	# _end_round() force-clears the board: is_instance_valid() below would stop
	# the crash, but not the wrongness of damaging a round that already ended.
	#
	# `in`-guarded rather than assumed, because testbed/clean_area.tscn has no
	# round lifecycle at all and payloads should keep working there — the same
	# tolerance enemy.gd extends to it.
	if map == null or not is_instance_valid(map):
		queue_free()
		return
	if "round_state" in map and map.round_state != map.RoundState.IN_ROUND:
		queue_free()
		return

	for e in _splash_candidates():
		# Re-checked on EVERY tick, not once at spawn. A 3-second barrage reads
		# a grid that is rebuilt ~180 times underneath it, with enemies freed
		# out from under the cached node references — CLAUDE.md's Known issue
		# 1b, stretched over time instead of over a single frame.
		if not is_instance_valid(e):
			continue
		# to_local() undoes this node's rotation for free, so the containment
		# test is a plain axis-aligned box check in the rectangle's own frame:
		# x forward from the base edge, y within half-width either side. No
		# trigonometry here, and no second copy of the angle to keep in sync.
		var local: Vector2 = to_local(e.global_position)
		if local.x < 0.0 or local.x > LENGTH:
			continue
		if absf(local.y) > WIDTH * 0.5:
			continue
		if e.has_method("take_damage"):
			e.take_damage(DAMAGE_PER_TICK)

	_fire_volley()

	ticks_done += 1
	if float(ticks_done) * TICK_INTERVAL >= DURATION:
		queue_free()


## Drops one volley of arrow sprites into the box. Cosmetic only — see
## ARROW_TEXTURE. Children of this node, so a payload that frees itself mid-fall
## (round ended, or duration reached) takes its arrows and their tweens with it.
func _fire_volley() -> void:
	# World-space DOWN expressed in this node's LOCAL frame. Without this the
	# arrows would fall along the rectangle's own axis, so a sideways-aimed
	# barrage would show arrows flying horizontally — the one thing "rain" must
	# never do. The zone rotates with the aim; the arrows do not.
	var down_local: Vector2 = Vector2(0.0, 1.0).rotated(-rotation)
	# Same correction for the sprite's own facing: arrow.png points +X, and it
	# needs to point world-down (+Y, i.e. PI/2) whatever this node's rotation is.
	var arrow_rotation: float = PI * 0.5 - rotation

	for _i in range(ARROWS_PER_VOLLEY):
		var landing := Vector2(
			randf() * LENGTH,
			randf_range(-WIDTH * 0.5, WIDTH * 0.5))

		var arrow := Sprite2D.new()
		arrow.texture = ARROW_TEXTURE
		arrow.scale = Vector2(ARROW_SCALE, ARROW_SCALE)
		arrow.rotation = arrow_rotation
		arrow.z_as_relative = false
		arrow.z_index = ARROW_Z
		arrow.position = landing - down_local * ARROW_FALL_HEIGHT
		add_child(arrow)

		# Bound to this node, so freeing the payload kills the tween too rather
		# than leaving it to fire a callback at a freed sprite.
		# Jittered per arrow so the volley desynchronises as it falls. Note this
		# also varies each arrow's SPEED, since the distance is fixed — which is
		# what sells it, because real arrows in a volley do not arrive together.
		var fall_time: float = ARROW_FALL_TIME * randf_range(
			1.0 - ARROW_FALL_JITTER, 1.0 + ARROW_FALL_JITTER)

		var tween := create_tween()
		tween.tween_property(arrow, "position", landing, fall_time) 			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(arrow.queue_free)


## Mirrors boulder.gd and fire.gd: the grid keeps this O(nearby) instead of
## scanning every enemy in the scene. The fallback exists for maps without the
## grid — the same reason enemy.gd tolerates clean_area.tscn — and is NOT
## validity- or distance-filtered, which is why the loop above re-checks both.
func _splash_candidates() -> Array:
	# Queried from the rectangle's CENTRE with its half-diagonal, not from the
	# base with its full length: the circle that bounds the box from the middle
	# is far smaller (~138px here versus 260), so the grid hands back a fraction
	# of the candidates for the box test above to reject.
	var centre: Vector2 = to_global(Vector2(LENGTH * 0.5, 0.0))
	var bound: float = Vector2(LENGTH, WIDTH).length() * 0.5
	if map and map.has_method("get_enemies_in_radius"):
		return map.get_enemies_in_radius(centre, bound)

	# Falling back is legitimate only on a map with no spatial grid — the
	# testbed, which is deliberately not in the "map" group. On the REAL map it
	# means the query name drifted, and the fallback quietly scans every enemy
	# in the scene: a perf cliff dressed as working code. Say so, once.
	if map != null and map.is_in_group("map") and not _fallback_warned:
		_fallback_warned = true
		push_error("rain_of_arrows: map has no get_enemies_in_radius() — falling back to a full scene scan. The query name has drifted.")
	return get_tree().get_nodes_in_group(Enemy.GROUP)
