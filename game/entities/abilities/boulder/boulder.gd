extends Node2D

## A1's ability payload. Dropped by ability_manager at a target position, falls
## for IMPACT_DELAY seconds, then damages everything inside RADIUS once and
## frees itself.
##
## Deliberately a plain Node2D, NOT an Area2D. It finds its victims by querying
## the map's spatial grid at impact, so it needs no collision shape and no
## layer/mask setup — and adding another monitoring body into the middle of a
## 95-enemy wave is exactly the O(n^2) collapse CLAUDE.md's collision layer
## table exists to prevent.

## Not in TowerStats: these are not one of the three upgrade tracks the player
## buys, the same reasoning that keeps wizard.gd's AOE_RADIUS local to that
## script. Tuned at a1_plan.md's step 11.
const RADIUS := 70.0
const DAMAGE := 15

## The cooldown starts at cast, so this arc is travel time the player has
## already committed to — it buys lead-your-target skill, not dead air.
const IMPACT_DELAY := 0.5
## How far above the target the boulder begins its fall.
const FALL_HEIGHT := 400.0

## Set by ability_manager before add_child. Not resolved via a group scan here
## because the caller already holds the reference.
var map: Node = null


func _ready() -> void:
	# The root stays parked on the impact point for its whole life, so
	# global_position is already the damage origin and never has to be
	# recomputed — only the sprite travels.
	var sprite: Sprite2D = $Sprite2D
	sprite.position = Vector2(0, -FALL_HEIGHT)

	var tween := create_tween()
	tween.tween_property(sprite, "position", Vector2.ZERO, IMPACT_DELAY) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_impact)


func _impact() -> void:
	for z in _splash_candidates():
		# The map's grid caches node references at rebuild time, and nothing
		# guarantees a candidate survives an earlier iteration of THIS loop —
		# two AoE hits landing on one cluster in a single frame is what crashed
		# the game before (CLAUDE.md, Known issue 1b). Every consumer of
		# zombie_grid_nodes needs this guard.
		if not is_instance_valid(z):
			continue
		if z.global_position.distance_to(global_position) <= RADIUS:
			if z.has_method("take_damage"):
				z.take_damage(DAMAGE)
	queue_free()


## Mirrors fire.gd: the grid keeps this O(nearby) instead of scanning every
## zombie in the scene. The fallback exists for maps without the grid — the
## same reason zombie.gd tolerates clean_area.tscn — and is NOT validity- or
## distance-filtered, which is why the loop above re-checks both.
func _splash_candidates() -> Array:
	if map and map.has_method("get_zombies_in_radius"):
		return map.get_zombies_in_radius(global_position, RADIUS)

	# Falling back is legitimate only on a map with no spatial grid — the
	# testbed, which is not in the "map" group. On the REAL map it means the
	# query name drifted, and the fallback quietly scans every enemy in the
	# scene: a perf cliff dressed as working code. Say so.
	if map != null and map.is_in_group("map"):
		push_error("boulder: map has no get_zombies_in_radius() — falling back to a full scene scan. The query name has drifted.")
	return get_tree().get_nodes_in_group(Enemy.GROUP)
