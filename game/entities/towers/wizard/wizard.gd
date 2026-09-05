extends Area2D

## Resolves its own stats from TowerStats at spawn — do not @export damage,
## range or fire-rate here. See tower_stats.gd for why.
const TOWER_TYPE := "wizard"

## AoE splash radius. Not one of the three upgrade tracks (range/fire-rate/
## damage) the player buys — "range" governs target ACQUISITION only. If
## splash size becomes upgradeable later, it belongs in TowerStats as a
## fourth track, not bolted onto "range".
const AOE_RADIUS := 100.0

@onready var collision_shape = $CollisionShape2D
@onready var timer = $Timer

var damage: int = 0

func _ready():
	# See archer.gd — towers persist between rounds, so map1 refreshes this
	# group's stats at every round start.
	add_to_group("tower_unit")
	refresh_stats()

	if timer:
		timer.stop()
		# Random initial delay so multiple wizards don't fire on the exact
		# same frame.
		await get_tree().create_timer(randf_range(0.0, timer.wait_time)).timeout
		if is_instance_valid(timer):
			timer.start()


## Re-resolves stats from TowerStats. Safe on a live tower mid-game.
func refresh_stats() -> void:
	var stats: Dictionary = TowerStats.get_stats(TOWER_TYPE)
	damage = stats["damage"]

	if collision_shape and collision_shape.shape is CircleShape2D:
		# duplicate() so each wizard owns its shape — otherwise resizing one
		# resizes every wizard sharing the scene's sub-resource.
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = stats["range"]

	if timer:
		timer.wait_time = stats["attack_interval"] * randf_range(0.95, 1.05)

func _on_timer_timeout():
	var targets = get_overlapping_areas()
	var zombies = []
	for t in targets:
		if t.is_in_group(Enemy.GROUP):
			zombies.append(t)

	if zombies.size() > 0:
		# Pick a random zombie so multiple wizards don't shoot the exact same target
		var target = zombies[randi() % zombies.size()]
		var fire_scene = preload("res://entities/projectiles/fire/fire.tscn")
		var fire = fire_scene.instantiate()
		fire.target = target
		fire.damage = damage
		fire.aoe_radius = AOE_RADIUS
		get_parent().add_child(fire)
		fire.global_position = global_position
