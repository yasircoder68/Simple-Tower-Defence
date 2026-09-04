extends Node

## Round-scoped ability owner. In A1 that means exactly one ability: the
## boulder. Cooldowns are round-scoped and are never persisted — see CLAUDE.md's
## state boundary table.
##
## A1 Track B. B-1 (this) owns the cooldown and the cast gate; B-2 adds the
## boulder itself; B-3 adds aiming and input. Nothing here touches
## level_controller.gd — the seams it calls were wired at Step 0.

signal cooldown_changed(remaining: float, total: float)

## 3 seconds makes the boulder a different kind of thing from the 30/60/90s
## abilities arriving in A2: it is the baseline verb of a round, fired 10-12
## times per wave, not a special. That is why its numbers are modest — see
## a1_plan.md's boulder table before tuning them.
const BOULDER_COOLDOWN := 3.0

const BOULDER_SCENE := preload("res://entities/abilities/boulder/boulder.tscn")
const AIM_MARKER_SCRIPT := preload("res://ui/aim_marker/aim_marker.gd")

var map: Node2D = null

## Explicit off-switch, forced false by level_controller._end_round(). This is
## belt-and-braces on top of the live round_state check in _is_in_round(), not
## the primary gate — see can_cast().
var enabled: bool = false

var cooldown_remaining: float = 0.0

## True between LMB press and release. Purely presentational — the cast itself
## is gated by can_cast(), not by this.
var aiming: bool = false

var _marker: Node2D = null


func setup(map_ref: Node2D) -> void:
	map = map_ref

	# Parented to the map so it lives in world space alongside the boulder it
	# previews, rather than in the CanvasLayer the HUD uses.
	_marker = AIM_MARKER_SCRIPT.new()
	_marker.name = "AimMarker"
	_marker.hide()
	map.add_child(_marker)


func _process(delta: float) -> void:
	# Refreshed here rather than only on mouse motion, so a cooldown expiring
	# while the player holds still recolours the marker immediately. set_ready()
	# early-outs when unchanged, so this is not a per-frame redraw.
	if aiming and _marker != null:
		_marker.set_ready(can_cast())

	if cooldown_remaining <= 0.0:
		return
	# Freeze the cooldown outside a round rather than letting it drain against
	# the result screen. reset() clears it for the next round anyway; this just
	# keeps the value honest if anything reads it in between.
	if not _is_in_round():
		return

	cooldown_remaining = max(cooldown_remaining - delta, 0.0)
	# Emitted every frame while cooling so a UI bar can animate, and once more
	# at exactly 0 so the listener gets a definite "ready" edge rather than
	# having to poll for it.
	cooldown_changed.emit(cooldown_remaining, BOULDER_COOLDOWN)


## Read live from round_state rather than cached, mirroring the rule
## is_valid_placement() and round_ui._upgrades_allowed() both follow. A cached
## copy would have to be invalidated on every path back to PRE_ROUND, and
## start_new_round() is exactly such a path — it calls reset() while heading
## *out* of a round, not into one.
func _is_in_round() -> bool:
	return map != null and map.round_state == map.RoundState.IN_ROUND


# --- Public API ---------------------------------------------------------

## Clears the cooldown for a fresh round. Called from _start_round() (entering
## a round) and from start_new_round() (leaving one) — which is why it must not
## be the thing that decides whether casting is allowed.
func reset() -> void:
	enabled = true
	cooldown_remaining = 0.0
	cancel_aim()
	cooldown_changed.emit(0.0, BOULDER_COOLDOWN)


## Called with false from level_controller._end_round().
func set_enabled(value: bool) -> void:
	enabled = value
	# A round can end mid-aim — on the escape that drains the last life, say —
	# and the marker would otherwise be left painted on the result screen.
	if not value:
		cancel_aim()


## Drops the aim without casting. Used by right-click, and by every path that
## takes the game out of a round.
func cancel_aim() -> void:
	aiming = false
	if _marker != null:
		_marker.hide()


func can_cast() -> bool:
	return enabled and _is_in_round() and cooldown_remaining <= 0.0


## Drops a boulder at world_pos and starts the cooldown. Returns false with no
## state change if the ability is disabled, out of round, or still cooling.
##
## Takes an explicit world position rather than reading the mouse, because
## get_global_mouse_position() is not reliably driven by input_simulate in this
## environment (CLAUDE.md, Gotchas) — calling this directly via execute_code is
## the only way this path can be verified.
func cast_boulder(world_pos: Vector2) -> bool:
	if not can_cast():
		return false

	var boulder := BOULDER_SCENE.instantiate()
	boulder.map = map
	# Parented to the map, not to this manager, so it shares the world
	# transform every other entity uses — and so global_position lands where
	# the caller meant. Position is set after add_child: before the node is in
	# the tree, global_position has no parent transform to resolve against.
	map.add_child(boulder)
	boulder.global_position = world_pos

	# The cooldown starts at cast, not at impact — the arc is travel time the
	# player has already committed to.
	cooldown_remaining = BOULDER_COOLDOWN
	cooldown_changed.emit(cooldown_remaining, BOULDER_COOLDOWN)
	return true


## Hold LMB to aim, release to drop; right-click cancels. Forwarded from
## level_controller._input()'s IN_ROUND branch, which does nothing but route —
## all logic lives here, and that is the entire reason Track B touches no file
## Track W touches.
##
## No conflict with the tower drag that uses the same button: that branch is
## PRE_ROUND-only and this one is reached only while IN_ROUND, so the two can
## never be live at the same time.
func handle_input(event: InputEvent) -> void:
	if _marker == null:
		return

	if event is InputEventMouseMotion:
		if aiming:
			_marker.global_position = map.get_global_mouse_position()
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		cancel_aim()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		# Aiming is allowed even while cooling — the marker's colour reports
		# whether releasing will actually throw. Pre-aiming during the 3s is
		# most of what makes a short cooldown feel good to use.
		aiming = true
		_marker.global_position = map.get_global_mouse_position()
		_marker.set_ready(can_cast())
		_marker.show()
	elif aiming:
		# Read the position off the marker rather than the mouse again: the
		# marker is what the player was looking at, so a release that arrives
		# a frame after the last motion still throws where they aimed.
		var target: Vector2 = _marker.global_position
		cancel_aim()
		cast_boulder(target)
