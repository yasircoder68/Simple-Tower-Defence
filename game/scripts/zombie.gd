extends Area2D

const SEPARATION_RADIUS := 32.0
const SEPARATION_RADIUS_SQ := SEPARATION_RADIUS * SEPARATION_RADIUS
const MAX_SEPARATION_NEIGHBORS := 10
# Hard ceiling on candidates examined per frame. Separation is a soft cosmetic
# force, so sampling a bounded subset of a dense cell looks identical and keeps
# the cost linear in zombie count instead of linear in local density.
const MAX_SEPARATION_CHECKS := 24
const ARRIVAL_RADIUS := 30.0

@export var speed: float = 200.0
var hp: int = 10

@onready var map = get_parent()

# The grid dictionary is rebuilt in place (cleared + refilled) every frame, so
# the REFERENCE is stable and safe to cache. Fetching it per frame through
# map.get() instead costs a dictionary copy per zombie per frame.
var _grid: Dictionary = {}


func _ready() -> void:
	if "zombie_grid" in map:
		_grid = map.zombie_grid

func _physics_process(delta: float) -> void:
	if not map.has_method("get_flow_direction"):
		return

	var flow_dir: Vector2 = map.get_flow_direction(global_position)

	# A zero vector means we're standing in the target cell. Walk the last
	# stretch to the exact end position, then despawn on arrival.
	if flow_dir == Vector2.ZERO:
		flow_dir = global_position.direction_to(map.end_point.global_position)
		if global_position.distance_to(map.end_point.global_position) < ARRIVAL_RADIUS:
			queue_free()
			return

	var desired_dir := (flow_dir + _separation() * 1.5).normalized()
	if desired_dir == Vector2.ZERO:
		desired_dir = flow_dir

	_move_with_wall_slide(desired_dir * speed * delta)


# Soft push-apart so the horde behaves like a fluid.
#
# Reads positions straight out of the map's spatial grid (a plain Array of
# Vector2 per cell — packed arrays are copy-on-write and copy on every append). Two things matter for speed here and both were learned the hard
# way: never build a merged candidate list (the allocation dwarfs the work), and
# never reach through a node reference in the inner loop (each `other.global_position`
# is a Variant dynamic dispatch — with ~200 candidates per zombie per frame that
# alone took 600 zombies from 60 FPS to 2).
func _separation() -> Vector2:
	# clean_area.tscn drives zombies too and has no grid — fall back to no push.
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
			if not _grid.has(key):
				continue
			for other_pos in _grid[key]:
				checks += 1
				if checks > MAX_SEPARATION_CHECKS:
					return separation
				var offset: Vector2 = my_pos - other_pos
				var dist_sq := offset.length_squared()
				# dist_sq == 0 is this zombie's own entry in the grid.
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
	if not map.is_wall(global_position + step):
		global_position += step
		return

	var slide_x := global_position + Vector2(step.x, 0)
	if not map.is_wall(slide_x):
		global_position = slide_x
		return

	var slide_y := global_position + Vector2(0, step.y)
	if not map.is_wall(slide_y):
		global_position = slide_y


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		queue_free()
