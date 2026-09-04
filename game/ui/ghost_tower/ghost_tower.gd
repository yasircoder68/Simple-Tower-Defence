extends Node2D

@onready var sprite = Sprite2D.new()
var type: String = ""

func _ready():
	add_child(sprite)
	visible = false

func set_tower(tower_type: String):
	type = tower_type
	if type == "archer":
		sprite.texture = load("res://entities/towers/archer/archer_tower.png")
		sprite.scale = Vector2(3, 3)
	elif type == "wizard":
		sprite.texture = load("res://entities/towers/wizard/wizard_tower.png")
		sprite.scale = Vector2(9, 9)
	visible = true

func hide_ghost():
	visible = false
	type = ""

func update_validity(is_valid: bool):
	if is_valid:
		sprite.modulate = Color(0, 1, 0, 0.6)
	else:
		sprite.modulate = Color(1, 0, 0, 0.6)
