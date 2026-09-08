extends Control

## Bottom-centre ability bar: one slot per registry entry, click or number key
## to select, with each slot showing its own cooldown draining.
##
## Its own scene rather than part of the old round_ui.gd, because that was
## throwaway and is deleted wholesale at UI-0/UI-1 — this is a permanent element
## (ui_plan.md's UI-1), so building it inside the throwaway means building it
## twice. build_sidebar is the precedent.
##
## Zero-asset per ui_plan: panels, labels and a fill rect. A theme pass can
## restyle all of it without touching this structure.

const SLOT_SIZE := Vector2(96, 56)
const SLOT_GAP := 8
const MARGIN_BOTTOM := 16

const SELECTED_TINT := Color(1.0, 1.0, 1.0, 1.0)
const UNSELECTED_TINT := Color(0.62, 0.62, 0.62, 1.0)
## Covers the portion of a slot still on cooldown, draining downward.
const COOLDOWN_VEIL := Color(0.0, 0.0, 0.0, 0.55)

var manager: Node = null

## ability_id -> { "button": Button, "veil": ColorRect }
var _slots: Dictionary = {}


func setup(manager_ref: Node) -> void:
	manager = manager_ref

	# Full-rect and click-through: only the slot Buttons should ever swallow a
	# click. If this root captured the mouse it would block the whole play area
	# from aiming, which is the exact opposite of the problem the bar's own
	# click-consumption is meant to solve.
	#
	# Anchors AND offsets set explicitly rather than via set_anchors_preset():
	# the preset alone leaves this Control at size (0,0), which parks the row
	# off-screen at (-48, -72) because it then centres on an empty rect.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", SLOT_GAP)
	# Anchored to bottom-centre and grown both ways, so the row stays centred
	# on its own content width no matter how many abilities A2 adds.
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -MARGIN_BOTTOM
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for ability_id in manager.ABILITIES:
		row.add_child(_build_slot(ability_id))

	manager.cooldown_changed.connect(_on_cooldown_changed)
	manager.selection_changed.connect(_on_selection_changed)

	_refresh_selection()


func _build_slot(ability_id: String) -> Button:
	var entry: Dictionary = manager.ABILITIES[ability_id]

	var button := Button.new()
	# Explicit name so it is addressable by path for testing — anonymous
	# procedural Controls get auto-generated names like @Button@42, which are
	# not guessable in advance. The upgrade screen names its buttons likewise.
	button.name = "AbilitySlot_%s" % ability_id
	button.custom_minimum_size = SLOT_SIZE
	button.text = "%s  %s" % [entry["key_label"], entry["display_name"]]
	button.pressed.connect(_on_slot_pressed.bind(ability_id))

	# Drains downward: anchor_top rides from 0 (fully covered) to 1 (clear).
	var veil := ColorRect.new()
	veil.name = "Cooldown"
	veil.color = COOLDOWN_VEIL
	# Explicit for the same reason as the root above.
	veil.anchor_left = 0.0
	veil.anchor_right = 1.0
	veil.anchor_bottom = 1.0
	veil.offset_left = 0.0
	veil.offset_top = 0.0
	veil.offset_right = 0.0
	veil.offset_bottom = 0.0
	# Must not eat the click — the Button underneath is what consumes it, and
	# that consumption is what keeps _unhandled_input from firing an ability.
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Starts clear (anchor_top == anchor_bottom); _on_cooldown_changed drives it.
	veil.anchor_top = 1.0
	button.add_child(veil)

	_slots[ability_id] = {"button": button, "veil": veil}
	return button


func _on_slot_pressed(ability_id: String) -> void:
	manager.select(ability_id)


func _on_selection_changed(_ability_id: String) -> void:
	_refresh_selection()


func _refresh_selection() -> void:
	for ability_id in _slots:
		var button: Button = _slots[ability_id]["button"]
		button.modulate = SELECTED_TINT if ability_id == manager.selected_ability else UNSELECTED_TINT


func _on_cooldown_changed(ability_id: String, remaining: float, total: float) -> void:
	if not _slots.has(ability_id):
		return
	var veil: ColorRect = _slots[ability_id]["veil"]
	var fraction: float = 0.0 if total <= 0.0 else clampf(remaining / total, 0.0, 1.0)
	veil.anchor_top = 1.0 - fraction
