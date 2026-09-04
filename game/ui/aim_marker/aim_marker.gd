extends Node2D

## Shows where the selected ability will land and how big its blast will be,
## while the player holds LMB.
##
## Drawn rather than textured, and the radius is handed in by ability_manager
## from the payload script that owns it — so the preview cannot drift from the
## real blast when a number is tuned at a1_plan.md's step 11, and so it follows
## the SELECTED ability rather than assuming boulder. A2's Divine Smite and
## Rain of Arrows have nothing like the same footprint.
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

var radius: float = 70.0
var _ready_to_cast: bool = true


func _init() -> void:
	z_index = Z_INDEX


func set_radius(value: float) -> void:
	if is_equal_approx(radius, value):
		return
	radius = value
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
	draw_circle(Vector2.ZERO, radius, READY_FILL if _ready_to_cast else COOLING_FILL)
	# The outline carries the edge against both the white walls and the dark
	# floor; a translucent fill alone washes out over the walls.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 2.0)
