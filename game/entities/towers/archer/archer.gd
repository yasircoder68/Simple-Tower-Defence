extends Area2D

## Resolves its own stats from TowerStats at spawn — do not @export damage,
## range or fire-rate here. See tower_stats.gd for why.
const TOWER_TYPE := "archer"

@onready var timer: Timer = $Timer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
## Resolved via the group rather than get_parent(), matching fire.gd. The
## testbed is deliberately not in this group, so a tower there simply never
## fires instead of erroring.
@onready var map: Node = get_tree().get_first_node_in_group("map")

var damage: int = 0
## Acquisition radius in world px. Since S-1 this is a NUMBER, not a collision
## shape - the enemies it must find are no longer in the physics world at all.
var range_px: float = 0.0

func _ready():
	# Towers now survive between rounds, so map1 re-runs refresh_stats() on this
	# group at every round start — otherwise a tower placed before an upgrade
	# would keep its old numbers forever.
	add_to_group("tower_unit")
	refresh_stats()

	if timer:
		# Desync archers so a room full of them doesn't fire in lockstep:
		# stagger the first shot with a random initial delay. (refresh_stats
		# already jittered the interval itself.)
		timer.stop()
		await get_tree().create_timer(randf_range(0.0, timer.wait_time)).timeout
		if is_instance_valid(timer):
			timer.start()


## Re-resolves stats from TowerStats. Safe to call on a live tower mid-game —
## it doesn't restart the firing cycle, just updates what the next shot uses.
func refresh_stats() -> void:
	var stats: Dictionary = TowerStats.get_stats(TOWER_TYPE)
	damage = stats["damage"]
	range_px = stats["range"]
	if timer:
		timer.wait_time = stats["attack_interval"] * randf_range(0.95, 1.05)


## Since S-1 this asks the map's spatial grid instead of the physics broadphase.
## The grid is rebuilt every physics frame and towers fire at ~2 Hz, so what it
## returns is always fresh - and it is the same query boulder, fire and Rain of
## Arrows already use, so there is one answer to "which enemies are near here"
## rather than two that can disagree.
##
## The CollisionShape2D in archer.tscn is now vestigial: it is on layer 2
## (tower_range), which nothing masks any more. Left in place rather than
## deleted so the scene needs no edit; see CLAUDE.md's collision layer table.
func _on_timer_timeout():
	if map == null or not map.has_method("get_enemies_in_radius"):
		return

	var enemies: Array = map.get_enemies_in_radius(global_position, range_px)
	if enemies.is_empty():
		return

	var target = enemies[randi() % enemies.size()]
	# The grid caches node references at rebuild time and a kill earlier in the
	# same frame can free one - Known issue 1b, and every consumer needs this.
	if not is_instance_valid(target):
		return

	var arrow_scene = preload("res://entities/projectiles/arrow/arrow.tscn")
	var arrow = arrow_scene.instantiate()
	arrow.target = target
	arrow.damage = damage
	get_parent().add_child(arrow)
	arrow.global_position = global_position
