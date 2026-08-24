extends Node2D

@export var damage: int = 10
@export var rate_of_fire: float = 0.5

func _ready():
	var archer_scene = preload("res://scenes/archer.tscn")
	var archer = archer_scene.instantiate()
	
	archer.damage = damage
	add_child(archer)
	
	# Offset the archer so it sits on top of the tower visually
	archer.position = Vector2(0, -60)
	
	var timer = archer.get_node("Timer")
	if timer:
		timer.wait_time = rate_of_fire
		timer.start()
