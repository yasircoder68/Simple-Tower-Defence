extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10

var target: Node2D = null
var direction: Vector2 = Vector2.ZERO

func _ready():
	# If no target, destroy
	if not is_instance_valid(target):
		queue_free()
		
	# Destroy arrow after 3 seconds to prevent memory leaks
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
	else:
		# Target died, just keep flying straight
		pass
	
	global_position += direction * speed * delta

func _on_area_entered(area):
	if area.is_in_group("zombie"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
			queue_free()
