extends Camera2D
## Player-controlled view (A5-4). Wheel zooms about the cursor, middle-drag pans.
##
## Shared by every level, like level_controller.gd — the level authors the
## framing on its own Camera2D node and this script reads it rather than
## hardcoding numbers, so a larger map with a different starting zoom works
## without editing this file.
##
## Deliberately NOT persisted: this is per-session view state, not a preference,
## so it has no business in Settings or PlayerData.

## Multiplicative per wheel notch. Multiplicative rather than additive so a step
## feels the same size at every zoom level.
const ZOOM_STEP := 1.1
## Ceiling only. The FLOOR is the level's authored zoom, read in _ready() — that
## is by definition "the whole map fits", which is the most useful zoomed-out view.
const MAX_ZOOM := 2.0

var _min_zoom: float = 1.0
var _panning: bool = false
var _bounds: Rect2 = Rect2()
var _bounds_ready: bool = false


func _ready() -> void:
	_min_zoom = zoom.x
	# Deferred, NOT direct: _ready() runs children-first, so this fires BEFORE
	# level_controller._ready(), at which point its @onready tile_map is still
	# null. Deferring puts the query after the whole ready cascade.
	_resolve_bounds.call_deferred()


func _resolve_bounds() -> void:
	var map: Node = get_parent()
	# has_method-guarded like every other map-side call in this project, so a
	# stripped harness (testbed/clean_area.tscn) can host this script unmodified;
	# it simply pans without clamping.
	if map != null and map.has_method("get_world_bounds"):
		_bounds = map.get_world_bounds()
		_bounds_ready = _bounds.size.x > 0.0 and _bounds.size.y > 0.0


## _unhandled_input, NOT _input — the same rule the boulder is routed by.
## _input() runs BEFORE GUI handling, so a wheel notch over the build sidebar
## would zoom the world underneath it. Controls consume events that land on
## them, so unhandled input only ever sees the game world.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed and event.button_index != MOUSE_BUTTON_MIDDLE:
			return
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(ZOOM_STEP)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(1.0 / ZOOM_STEP)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		# relative is in screen px; dividing by zoom converts to world px so a
		# drag moves the map exactly under the cursor at any zoom.
		global_position -= event.relative / zoom
		_clamp_position()
		get_viewport().set_input_as_handled()


func _apply_zoom(factor: float) -> void:
	var target: float = clampf(zoom.x * factor, _min_zoom, MAX_ZOOM)
	if is_equal_approx(target, zoom.x):
		return
	# Pin the world point under the cursor. Computed from the viewport rect by
	# hand rather than with get_global_mouse_position(), because that reads the
	# canvas transform, which Camera2D does not necessarily refresh in the same
	# frame the zoom is assigned — it would silently read the pre-zoom value and
	# the shift would come out as zero.
	var before: Vector2 = _world_at_cursor(zoom.x)
	zoom = Vector2(target, target)
	global_position += before - _world_at_cursor(target)
	_clamp_position()


## World position under the mouse for a given zoom, assuming the Camera2D's
## default centred anchor and no offset.
func _world_at_cursor(z: float) -> Vector2:
	var half_view: Vector2 = get_viewport_rect().size * 0.5
	return global_position + (get_viewport().get_mouse_position() - half_view) / z


func _clamp_position() -> void:
	if not _bounds_ready:
		return
	var half_view: Vector2 = get_viewport_rect().size * 0.5 / zoom
	global_position.x = _clamp_axis(
		global_position.x, half_view.x, _bounds.position.x, _bounds.end.x)
	global_position.y = _clamp_axis(
		global_position.y, half_view.y, _bounds.position.y, _bounds.end.y)


## Two regimes, and the split is what stops the view snapping.
##
## Zoomed IN (the view is narrower than the map on this axis) the tight clamp
## applies: the visible rect may not cross the map edge, so you cannot pan into
## the void. Zoomed OUT the tight clamp is unsatisfiable — min would exceed max —
## and forcing it would jerk the camera to the map centre the instant the player
## touches the wheel. There the centre is simply kept inside the map, which
## still guarantees the map is on screen because the view already covers it.
func _clamp_axis(value: float, half: float, low: float, high: float) -> float:
	if half * 2.0 >= high - low:
		return clampf(value, low, high)
	return clampf(value, low + half, high - half)
