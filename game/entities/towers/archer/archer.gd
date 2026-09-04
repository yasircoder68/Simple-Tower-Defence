extends Area2D

## Resolves its own stats from TowerStats at spawn — do not @export damage,
## range or fire-rate here. See tower_stats.gd for why.
const TOWER_TYPE := "archer"

@onready var timer: Timer = $Timer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var damage: int = 0

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
	_apply_range(stats["range"])
	if timer:
		timer.wait_time = stats["attack_interval"] * randf_range(0.95, 1.05)


## CollisionShape2D's own node scale must stay 1:1 for this to land in world
## space correctly — see the node in archer.tscn.
func _apply_range(range_px: float) -> void:
	if not collision_shape or not (collision_shape.shape is CircleShape2D):
		return
	collision_shape.shape = collision_shape.shape.duplicate()
	collision_shape.shape.radius = range_px


func _on_timer_timeout():
	var targets = get_overlapping_areas()
	var zombies = []
	for t in targets:
		if t.is_in_group("zombie"):
			zombies.append(t)

	if zombies.size() > 0:
		var target = zombies[randi() % zombies.size()]
		var arrow_scene = preload("res://entities/projectiles/arrow/arrow.tscn")
		var arrow = arrow_scene.instantiate()
		arrow.target = target
		arrow.damage = damage
		get_parent().add_child(arrow)
		arrow.global_position = global_position
