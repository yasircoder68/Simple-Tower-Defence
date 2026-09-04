extends Node2D

## Instantiates the archer unit and offsets it to sit visually on top of the
## tower base. The archer resolves its own stats from TowerStats in its own
## _ready() — this script no longer pushes damage/rate_of_fire onto it.
## (That push used to run AFTER archer.gd's own jitter setup and clobber it —
## see CLAUDE.md known issue #2, now moot.)

const ARCHER_VISUAL_OFFSET := Vector2(0, -60)

func _ready():
	var archer_scene = preload("res://entities/towers/archer/archer.tscn")
	var archer = archer_scene.instantiate()
	add_child(archer)
	archer.position = ARCHER_VISUAL_OFFSET
