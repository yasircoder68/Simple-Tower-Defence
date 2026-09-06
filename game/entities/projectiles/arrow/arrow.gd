extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10

## Since A3's S-1 enemies are Node2D, so area_entered can never fire - the hit
## is a distance test against the target this arrow is already homing on.
##
## THIS ARROW'S OWN radius (CircleShape2D 4.04 at scale 5). The enemy's
## hit_radius is ADDED to it, because that is what area-vs-area collision did:
## two shapes touch when the gap closes to the sum of their extents.
##
## Getting this wrong is not subtle. S-1's first attempt used a single 18px
## radius for the whole test - roughly half the true arrow+goblin reach and a
## third of arrow+ogre - and the towers missed enough that a round which had
## won with 16/20 lives was lost outright. Acceptance here is numeric for
## exactly that reason.
##
## At 600 px/s an arrow steps 10px per frame, well inside this reach, so it
## cannot tunnel through a target.
const PROJECTILE_RADIUS := 20.0
## Used only if a target predates hit_radius; matches the goblin default.
const FALLBACK_TARGET_RADIUS := 16.0

var target: Node2D = null
var direction: Vector2 = Vector2.ZERO
@onready var map: Node = get_tree().get_first_node_in_group("map")

func _ready():
	# If no target, destroy
	if not is_instance_valid(target):
		queue_free()
		return

	# Destroy arrow after 3 seconds to prevent memory leaks
	var lifetime_timer = Timer.new()
	lifetime_timer.wait_time = 3.0
	lifetime_timer.one_shot = true
	lifetime_timer.autostart = true
	lifetime_timer.timeout.connect(queue_free)
	add_child(lifetime_timer)

var hit: bool = false

func _physics_process(delta):
	if hit:
		return

	if is_instance_valid(target):
		direction = global_position.direction_to(target.global_position)
		rotation = direction.angle()

	global_position += direction * speed * delta

	if is_instance_valid(target):
		if _try_hit(target):
			return
		return

	# TARGET DIED MID-FLIGHT. area_entered used to hit whatever this arrow
	# physically overlapped, so the shot still connected with the enemy behind
	# it. S-1's first version just flew on and wasted the arrow, and the cost
	# was invisible until it was looked for: waves 1-3 matched the old build
	# EXACTLY while 4-5 regressed, because only a dense wave has several
	# archers converging on one enemy and killing it out from under each
	# other's arrows.
	#
	# Scanned only on this branch, not every frame, so a normally-homing arrow
	# still costs one distance check. A handful of arrows are ever in flight.
	if map == null or not map.has_method("get_enemies_in_radius"):
		return
	for e in map.get_enemies_in_radius(global_position, PROJECTILE_RADIUS + 40.0):
		if _try_hit(e):
			return


## Damages `victim` and frees this arrow if it is close enough. Returns whether
## the arrow was consumed.
func _try_hit(victim) -> bool:
	if not is_instance_valid(victim):
		return false
	var reach: float = PROJECTILE_RADIUS + (
		victim.hit_radius if "hit_radius" in victim else FALLBACK_TARGET_RADIUS)
	if global_position.distance_to(victim.global_position) > reach:
		return false
	if not victim.has_method("take_damage"):
		return false
	hit = true
	victim.take_damage(damage)
	queue_free()
	return true
