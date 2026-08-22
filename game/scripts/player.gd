extends CharacterBody2D

@export var speed: float = 400.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
	# Prevent physics glitches from permanently increasing speed
	if velocity.length() > speed:
		velocity = velocity.limit_length(speed)
		
	move_and_slide()
