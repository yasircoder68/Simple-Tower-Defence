extends Node

## Lives for the CURRENT round only. Round-scoped — never persisted, reset at
## the start of every round via reset(). See CLAUDE.md's state boundary table;
## this must never be folded into PlayerData.

signal life_lost(remaining: int)
signal lives_depleted

@export var max_lives: int = 20

var lives: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	lives = max_lives


func lose_life(amount: int = 1) -> void:
	if lives <= 0:
		return
	lives = max(lives - amount, 0)
	life_lost.emit(lives)
	if lives <= 0:
		lives_depleted.emit()
