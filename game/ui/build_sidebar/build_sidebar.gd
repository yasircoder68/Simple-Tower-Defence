extends CanvasLayer

## The build panel. Its buttons preview the WHOLE tower — base and unit — by
## rendering the real tower scene into a SubViewport and using that as the icon.
##
## They used to just `load()` the tower base PNG, which showed no unit at all.
## Compositing the two textures here instead would mean duplicating each tower's
## unit scale and offset in a third place (the scene, the ghost, and here), and
## those had already drifted once. Rendering the scene keeps one source of truth
## — the same reasoning as ui/ghost_tower/ghost_tower.gd, which see for why
## PROCESS_MODE_DISABLED is what makes instantiating a live tower safe.

signal start_drag(tower_type)

const TOWER_SCENES := {
	"archer": preload("res://entities/towers/archer/archer_tower.tscn"),
	"wizard": preload("res://entities/towers/wizard/wizard_tower.tscn"),
}

## Matches the tower art's own 64x64 canvas, so the icon captures exactly the
## sprite and no dead margin. The button upscales it via expand_icon.
const ICON_SIZE := 64

func _ready():
	var panel = Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -160.0
	panel.modulate = Color(1, 1, 1, 0.8)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10
	vbox.offset_top = 20
	vbox.offset_right = -10
	vbox.offset_bottom = -20
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "Build Tower\n(Drag or Click)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var btn_archer = Button.new()
	btn_archer.text = "Archer"
	btn_archer.icon = _make_tower_icon("archer")
	btn_archer.expand_icon = true
	btn_archer.custom_minimum_size = Vector2(0, 100)
	btn_archer.button_down.connect(func(): start_drag.emit("archer"))
	vbox.add_child(btn_archer)
	
	var btn_wizard = Button.new()
	btn_wizard.text = "Wizard"
	btn_wizard.icon = _make_tower_icon("wizard")
	btn_wizard.expand_icon = true
	btn_wizard.custom_minimum_size = Vector2(0, 100)
	btn_wizard.button_down.connect(func(): start_drag.emit("wizard"))
	vbox.add_child(btn_wizard)


## Renders a tower scene to a texture for use as a button icon.
##
## PROCESS_MODE_DISABLED before add_child, exactly as the build ghost does: a
## tower scene is a live tower that would otherwise join tower_unit, start its
## fire Timer and spawn projectiles — into a SubViewport, invisibly, forever.
## Disabling the subtree stops every Timer without affecting rendering.
func _make_tower_icon(tower_type: String) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	add_child(viewport)

	var tower: Node2D = TOWER_SCENES[tower_type].instantiate()
	tower.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(tower)
	# Sprites are centred on their origin; a viewport's origin is its top-left.
	tower.position = Vector2(ICON_SIZE, ICON_SIZE) * 0.5

	# _ready() already ran and the unit added itself. That group means "a tower
	# that is actually placed", and an icon is not one.
	for node in tower.find_children("*", "", true, false):
		node.remove_from_group("tower_unit")

	# UPDATE_ONCE, set AFTER the contents exist, so it renders a populated frame
	# and then stops. The subject never moves, so re-rendering it every frame for
	# the life of the game would be pure waste.
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return viewport.get_texture()
