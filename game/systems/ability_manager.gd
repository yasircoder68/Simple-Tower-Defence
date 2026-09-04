extends Node

## Round-scoped ability owner. In A1 that means exactly one ability: the
## boulder. Cooldowns are round-scoped and are never persisted — see CLAUDE.md's
## state boundary table.
##
## STUB — A1 Step 0. Every method below is deliberately inert. The seams in
## level_controller.gd already call into them, which is what lets Track B fill
## this file in without reopening that one. See a1_plan.md, Track B.

signal cooldown_changed(remaining: float, total: float)

## 3 seconds makes the boulder a different kind of thing from the 30/60/90s
## abilities arriving in A2: it is the baseline verb of a round, fired 10-12
## times per wave, not a special. That is why its numbers are modest — see
## a1_plan.md's boulder table before tuning them.
const BOULDER_COOLDOWN := 3.0

var map: Node2D = null

## False outside IN_ROUND, so the boulder is inert during PRE_ROUND (where the
## same mouse button means tower dragging) and after the round has ended.
var enabled: bool = false

var cooldown_remaining: float = 0.0


func setup(map_ref: Node2D) -> void:
	map = map_ref


# --- Public API (inert until Track B) -----------------------------------

## Clears cooldowns and enables casting for a fresh round. Called from
## level_controller._start_round(). B-1 fills this in.
func reset() -> void:
	pass


## Called with false from level_controller._end_round(). B-1 fills this in.
func set_enabled(value: bool) -> void:
	enabled = value


## B-1 fills this in.
func can_cast() -> bool:
	return false


## Drops a boulder at world_pos and starts the cooldown. Returns false with no
## state change if the ability is disabled or still cooling down.
##
## Takes an explicit world position rather than reading the mouse, because
## get_global_mouse_position() is not reliably driven by input_simulate in this
## environment (CLAUDE.md, Gotchas) — calling this directly via execute_code is
## the only way this path can be verified.
## B-1/B-2 fill this in.
func cast_boulder(_world_pos: Vector2) -> bool:
	return false


## Hold LMB to aim, release to drop. Forwarded from level_controller._input()'s
## IN_ROUND branch, which does nothing but route — all logic lives here, and
## that is the entire reason Track B touches no file Track W touches.
## B-3 fills this in.
func handle_input(_event: InputEvent) -> void:
	pass
