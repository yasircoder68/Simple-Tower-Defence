extends Node2D

## Shows where the selected ability will land and how big its blast will be,
## while the player holds LMB.
##
## Drawn rather than textured, and the geometry is handed in by ability_manager
## from the payload script that owns it — so the preview cannot drift from the
## real blast when a number is tuned at a2_plan.md's step 11, and so it follows
## the SELECTED ability rather than assuming boulder.
##
## SHAPE support was specced for A-3 (Dragon Fire) but landed at A-1, when Rain
## of Arrows became a rotatable rectangle. Built generically rather than as a
## rain-specific branch, exactly as a2_plan described it: read an optional SHAPE
## off the payload, default "circle", and match in _draw(). Dragon Fire can now
## inherit this instead of shipping the fixed left-to-right axis it planned.
##
## Deliberately NOT ui/ghost_tower: that previews a TOWER snapped to a grid
## cell and carries set_tower()/update_validity(). Reusing it would mean
## teaching one node two unrelated jobs.
##
## Script-only, no .tscn — there is no authored content to put in one, and this
## matches how base_health and the two managers are constructed.

## Above towers (20) so it is never buried, below the falling payload (30).
const Z_INDEX := 25

const READY_FILL := Color(0.95, 0.85, 0.4, 0.35)
const COOLING_FILL := Color(0.6, 0.6, 0.6, 0.22)
const OUTLINE := Color(1, 1, 1, 0.8)

## "circle" uses radius; "rect" uses width and length. Whichever is unused stays
## at zero rather than being cleared, because set_aim() overwrites all of them
## together and nothing reads the other shape's fields.
var shape: String = "circle"
var radius: float = 70.0
var width: float = 0.0
var length: float = 0.0

var _ready_to_cast: bool = true


func _init() -> void:
	z_index = Z_INDEX


## Takes the whole geometry in one call rather than a setter per dimension, so
## a shape change and its dimensions can never be applied half-and-half — a
## rect briefly wearing the previous circle's radius would be a visible flicker
## on every selection change.
func set_aim(dims: Dictionary) -> void:
	var new_shape: String = dims.get("shape", "circle")
	var new_radius: float = dims.get("radius", 0.0)
	var new_width: float = dims.get("width", 0.0)
	var new_length: float = dims.get("length", 0.0)

	if shape == new_shape \
			and is_equal_approx(radius, new_radius) \
			and is_equal_approx(width, new_width) \
			and is_equal_approx(length, new_length):
		return

	shape = new_shape
	radius = new_radius
	width = new_width
	length = new_length
	queue_redraw()


## Colour tells the player whether releasing will actually do anything. Aiming
## stays available while cooling on purpose — being able to line up the next
## throw during the cooldown is most of what makes a short one feel good.
func set_ready(value: bool) -> void:
	if _ready_to_cast == value:
		return
	_ready_to_cast = value
	queue_redraw()


func _draw() -> void:
	var fill: Color = READY_FILL if _ready_to_cast else COOLING_FILL

	match shape:
		"rect":
			# Drawn along local +X starting at the ORIGIN, so the node's own
			# rotation aims it and the player's click point is the rectangle's
			# base edge. ability_manager sets rotation = aim_direction.angle(),
			# which is the angle of +X — the two agree by construction.
			var box := Rect2(0.0, -width * 0.5, length, width)
			draw_rect(box, fill, true)
			# The outline carries the edge against both the white walls and the
			# dark floor; a translucent fill alone washes out over the walls.
			draw_rect(box, OUTLINE, false, 2.0)
			# The base edge, drawn thicker: it is the one part of the rectangle
			# that does NOT move while aiming, so marking it is what makes the
			# pivot legible as the player swings the far end around.
			draw_line(Vector2(0.0, -width * 0.5), Vector2(0.0, width * 0.5), OUTLINE, 3.0)
		_:
			draw_circle(Vector2.ZERO, radius, fill)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, OUTLINE, 2.0)
