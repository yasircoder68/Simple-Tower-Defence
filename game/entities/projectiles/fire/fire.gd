extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var aoe_radius: float = 100.0

var target: Node2D = null
var direction: Vector2 = Vector2.ZERO
var hit: bool = false

@onready var map: Node = get_tree().get_first_node_in_group("map")

func _ready():
	if not is_instance_valid(target):
		queue_free()
		return

	var lifetime_timer = Timer.new()
	lifetime_timer.wait_time = 3.0
	lifetime_timer.one_shot = true
	lifetime_timer.autostart = true
	lifetime_timer.timeout.connect(queue_free)
	add_child(lifetime_timer)

func _physics_process(delta):
	if is_instance_valid(target):
		direction = global_position.direction_to(target.global_position)
		rotation = direction.angle()

	global_position += direction * speed * delta

func _on_area_entered(area):
	if hit:
		return
	if area.is_in_group(Enemy.GROUP):
		hit = true
		# Splash everything inside aoe_radius. The candidate list comes from the
		# map's spatial grid so this stays O(nearby) instead of scanning every
		# zombie in the scene on every impact.
		for z in _splash_candidates():
			# The fallback path (get_nodes_in_group) isn't validity-filtered, and
			# nothing guarantees a candidate survives an earlier iteration of
			# this same loop.
			if not is_instance_valid(z):
				continue
			if z.global_position.distance_to(global_position) <= aoe_radius:
				if z.has_method("take_damage"):
					z.take_damage(damage)
		queue_free()

func _splash_candidates() -> Array:
	if map and map.has_method("get_enemies_in_radius"):
		return map.get_enemies_in_radius(global_position, aoe_radius)

	# See boulder.gd: a fallback on the real map means the query name drifted,
	# and quietly degrades to a full scene scan instead of erroring.
	if map != null and map.is_in_group("map"):
		push_error("fire: map has no get_enemies_in_radius() — falling back to a full scene scan. The query name has drifted.")
	return get_tree().get_nodes_in_group(Enemy.GROUP)
