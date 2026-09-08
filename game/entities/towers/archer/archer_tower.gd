extends Node2D

## Instantiates the archer unit on top of the tower base. The archer resolves
## its own stats from TowerStats in its own _ready() — this script no longer
## pushes damage/rate_of_fire onto it. (That push used to run AFTER archer.gd's
## own jitter setup and clobber it — see CLAUDE.md known issue #2, now moot.)

## ZERO because the art is drawn for it: the tower is a top-down 64x64 stone
## platform and the archer is a 64x64 figure meant to stand in its middle, so
## both sprites share a centre and neither needs nudging.
##
## It used to be (0, -60), which lifted the archer clear of a side-on
## placeholder tower. Keeping that with the real art would have parked the
## archer a full tower's height above the platform he is standing on.
const ARCHER_VISUAL_OFFSET := Vector2.ZERO

func _ready():
	var archer_scene = preload("res://entities/towers/archer/archer.tscn")
	var archer = archer_scene.instantiate()
	add_child(archer)
	archer.position = ARCHER_VISUAL_OFFSET
