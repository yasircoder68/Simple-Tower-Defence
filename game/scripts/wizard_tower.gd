extends Node2D

@export var damage: int = 10
@export var rate_of_fire: float = 1.0
@export var wizard_radius: float = 100.0
@export var fire_damage_radius: float = 100.0

func _ready():
	var wizard_scene = preload("res://scenes/wizard.tscn")
	var wizard = wizard_scene.instantiate()
	
	wizard.damage = damage
	wizard.wizard_radius = wizard_radius
	wizard.fire_damage_radius = fire_damage_radius
	
	add_child(wizard)
	
	# Offset the wizard so it sits on top of the tower visually
	wizard.position = Vector2(0, 20)
	
	var timer = wizard.get_node("Timer")
	if timer:
		timer.wait_time = rate_of_fire
		timer.start()
