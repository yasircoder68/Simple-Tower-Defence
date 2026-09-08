extends Node2D

## The build preview. Follows the mouse during a placement drag and tints itself
## green or red to say whether the drop is legal.
##
## IT INSTANTIATES THE REAL TOWER SCENE rather than compositing its own sprites,
## so the preview shows exactly what gets placed — tower base AND the unit on
## top, at whatever scales and offsets those scenes carry. The old version drew
## a single Sprite2D of the tower base with a hardcoded scale (3 for archer, 9
## for wizard), which meant it showed no unit at all and its scale had to be
## kept in sync with the tower scene by hand. It had already drifted.
##
## This is the same rule the aim marker follows: preview geometry is read off
## the thing it previews, never duplicated beside it.
##
## PROCESS_MODE_DISABLED IS LOAD-BEARING. A tower scene is a live tower — its
## unit joins the tower_unit group, resolves stats, starts a fire Timer and
## spawns projectiles into its parent. Disabling the subtree stops every Timer
## in it from ticking, so the preview can never fire. Rendering is unaffected;
## process_mode governs processing, not visibility.
##
## _ready() still runs on the instantiated tower (it always does on entering the
## tree), which is harmless — it only resolves stats — but it does mean the
## unit adds itself to `tower_unit` before we can stop it, hence the explicit
## removal below.

const TOWER_SCENES := {
	"archer": preload("res://entities/towers/archer/archer_tower.tscn"),
	"wizard": preload("res://entities/towers/wizard/wizard_tower.tscn"),
}

var type: String = ""

var _preview: Node2D = null


func _ready() -> void:
	visible = false


func set_tower(tower_type: String) -> void:
	if tower_type == type and _preview != null:
		visible = true
		return

	_free_preview()

	if not TOWER_SCENES.has(tower_type):
		push_error("ghost_tower: no scene for tower type '%s' — the build sidebar and this registry have drifted." % tower_type)
		return

	type = tower_type
	_preview = TOWER_SCENES[tower_type].instantiate()
	# Set BEFORE add_child so nothing in the subtree gets a single process frame.
	_preview.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_preview)

	# The unit added itself during _ready(). Left in, the preview would show up
	# in map1's `call_group("tower_unit", "refresh_stats")` at every round start
	# — harmless today, but that group means "a tower that is actually placed".
	for node in _preview.find_children("*", "", true, false):
		node.remove_from_group("tower_unit")

	visible = true


func hide_ghost() -> void:
	visible = false
	_free_preview()


func update_validity(is_valid: bool) -> void:
	# modulate propagates down the subtree, so this tints the whole tower —
	# base and unit together — rather than just a base sprite.
	#
	# The tint keeps some red and blue rather than being pure (0,1,0)/(1,0,0).
	# modulate MULTIPLIES, so a pure channel mask flattens every other channel
	# to zero and the preview collapses into one featureless blob — which did
	# not matter when this drew a single base sprite, and does now that it
	# shows the unit too. These still read unmistakably as green and red.
	modulate = Color(0.45, 1.0, 0.45, 0.65) if is_valid else Color(1.0, 0.4, 0.4, 0.65)


func _free_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	type = ""
