extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var aoe_radius: float = 100.0

var target: Node2D = null
var direction: Vector2 = Vector2.ZERO
var hit: bool = false

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
	if area.is_in_group("zombie"):
		hit = true
		# Apply AOE damage to all zombies within radius
		var all_zombies = get_tree().get_nodes_in_group("zombie")
		for z in all_zombies:
			if z.global_position.distance_to(global_position) <= aoe_radius:
				if z.has_method("take_damage"):
					z.take_damage(damage)
		queue_free()
