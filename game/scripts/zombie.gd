extends CharacterBody2D

@export var speed: float = 200.0
@export var acceleration: float = 1000.0

var player: Node2D = null
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	# Enable dynamic avoidance so zombies don't clump up
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 32.0 # Roughly matches the collision shape radius
	nav_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		
	var desired_velocity = velocity
		
	if player:
		nav_agent.target_position = player.global_position
		
		var direction = Vector2.ZERO
		if nav_agent.is_target_reachable() and not nav_agent.is_navigation_finished():
			var next_path_position = nav_agent.get_next_path_position()
			direction = global_position.direction_to(next_path_position)
		else:
			# Fallback: if no navmesh is found or target is unreachable, move directly
			direction = global_position.direction_to(player.global_position)
			
		desired_velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		desired_velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		
	# Prevent physics glitches from permanently increasing speed
	if desired_velocity.length() > speed:
		desired_velocity = desired_velocity.limit_length(speed)
		
	# Send the desired velocity to the NavigationAgent for avoidance calculation
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity
		move_and_slide()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()
