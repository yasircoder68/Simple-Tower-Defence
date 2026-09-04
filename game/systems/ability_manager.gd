extends Node

## Round-scoped ability owner: which ability is selected, what each one costs in
## cooldown, and turning a click into a cast. Cooldowns and selection are
## round-scoped and are never persisted — see CLAUDE.md's state boundary table.
##
## A1 ships one entry in ABILITIES. The registry exists anyway because A2 adds
## three more, and migrating ONE ability into a registry is far cheaper than
## migrating four — the same "it gets more expensive the longer it waits"
## argument alpha_plan makes for the A3 horde rewrite, in miniature.

## remaining/total are for ability_id specifically; every ability cools
## independently. Boulder's 3s and A2's Dragon Fire at 90s cannot share a float.
signal cooldown_changed(ability_id: String, remaining: float, total: float)
signal selection_changed(ability_id: String)

## The whole ability table. Adding an ability in A2 means adding an entry here
## and nothing else in this file.
##
## `script` sits alongside `scene` so the blast radius can be read off the
## payload that owns it (entry.script.RADIUS) instead of being duplicated here,
## where it would silently drift the first time one is tuned.
const ABILITIES := {
	"boulder": {
		"display_name": "Boulder",
		"key": KEY_1,
		"key_label": "1",
		"cooldown": 3.0,
		"scene": preload("res://entities/abilities/boulder/boulder.tscn"),
		"script": preload("res://entities/abilities/boulder/boulder.gd"),
	},
}

const AIM_MARKER_SCRIPT := preload("res://ui/aim_marker/aim_marker.gd")
const ABILITY_BAR_SCRIPT := preload("res://ui/ability_bar/ability_bar.gd")

var map: Node2D = null

## Explicit off-switch, forced false by level_controller._end_round(). Belt and
## braces on top of the live round_state check in _is_in_round(), not the
## primary gate — see can_cast().
var enabled: bool = false

## ability_id -> seconds remaining. Every id in ABILITIES always has an entry.
var cooldowns: Dictionary = {}

## Which ability a cast will use. A live preference, reset each round — it must
## never reach PlayerData.
var selected_ability: String = ""

## True between LMB press and release. Purely presentational; the cast itself is
## gated by can_cast(), not by this.
var aiming: bool = false

var _marker: Node2D = null
var _bar: Control = null


func setup(map_ref: Node2D) -> void:
	map = map_ref
	_reset_cooldowns()
	selected_ability = first_ability()

	# Parented to the map so it lives in world space alongside the payload it
	# previews, rather than in the CanvasLayer the HUD uses.
	_marker = AIM_MARKER_SCRIPT.new()
	_marker.name = "AimMarker"
	_marker.hide()
	map.add_child(_marker)
	_marker.set_radius(get_radius(selected_ability))

	# The bar is HUD, so it needs the CanvasLayer. Guarded rather than assumed:
	# testbed/clean_area.tscn has no CanvasLayer, and the same has_method-style
	# tolerance is why zombies run unmodified there.
	var canvas := map.get_node_or_null("CanvasLayer")
	if canvas != null:
		_bar = ABILITY_BAR_SCRIPT.new()
		_bar.name = "AbilityBar"
		canvas.add_child(_bar)
		_bar.setup(self)


func _process(delta: float) -> void:
	# Refreshed here rather than only on mouse motion, so a cooldown expiring
	# while the player holds still recolours the marker immediately. set_ready()
	# early-outs when unchanged, so this is not a per-frame redraw.
	if aiming and _marker != null:
		_marker.set_ready(can_cast(selected_ability))

	if not _is_in_round():
		return

	for ability_id in cooldowns:
		var remaining: float = cooldowns[ability_id]
		if remaining <= 0.0:
			continue
		remaining = max(remaining - delta, 0.0)
		cooldowns[ability_id] = remaining
		# Emitted every frame while cooling so the bar can animate, and once
		# more at exactly 0 so listeners get a definite "ready" edge rather
		# than having to poll for it.
		cooldown_changed.emit(ability_id, remaining, get_cooldown_total(ability_id))


## Read live from round_state rather than cached, mirroring the rule
## is_valid_placement() and round_ui._upgrades_allowed() both follow. A cached
## copy would have to be invalidated on every path back to PRE_ROUND, and
## start_new_round() is exactly such a path — it calls reset() while heading
## *out* of a round, not into one.
func _is_in_round() -> bool:
	return map != null and map.round_state == map.RoundState.IN_ROUND


func _reset_cooldowns() -> void:
	for ability_id in ABILITIES:
		cooldowns[ability_id] = 0.0


# --- Registry queries ---------------------------------------------------

func first_ability() -> String:
	for ability_id in ABILITIES:
		return ability_id
	return ""


func get_cooldown_total(ability_id: String) -> float:
	if not ABILITIES.has(ability_id):
		return 0.0
	return ABILITIES[ability_id]["cooldown"]


func get_cooldown(ability_id: String) -> float:
	return cooldowns.get(ability_id, 0.0)


## Blast radius of the payload itself. Read off the payload script so the aim
## preview and the real damage can never disagree.
func get_radius(ability_id: String) -> float:
	if not ABILITIES.has(ability_id):
		return 0.0
	var payload: GDScript = ABILITIES[ability_id]["script"]
	return payload.RADIUS


# --- Selection ----------------------------------------------------------

## Selecting a cooling ability is allowed — only casting is gated. Same
## reasoning as letting the player aim while cooling: lining up the next throw
## during the cooldown is most of what makes a short one feel good.
func select(ability_id: String) -> bool:
	if not ABILITIES.has(ability_id):
		return false
	if selected_ability == ability_id:
		return true
	selected_ability = ability_id
	if _marker != null:
		_marker.set_radius(get_radius(ability_id))
	selection_changed.emit(ability_id)
	return true


# --- Public API ---------------------------------------------------------

## Clears cooldowns and selection for a fresh round. Called from _start_round()
## (entering a round) and from start_new_round() (leaving one) — which is why it
## must not be the thing that decides whether casting is allowed.
func reset() -> void:
	enabled = true
	_reset_cooldowns()
	cancel_aim()
	select(first_ability())
	for ability_id in ABILITIES:
		cooldown_changed.emit(ability_id, 0.0, get_cooldown_total(ability_id))


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


func can_cast(ability_id: String) -> bool:
	if not ABILITIES.has(ability_id):
		return false
	return enabled and _is_in_round() and get_cooldown(ability_id) <= 0.0


## Spawns ability_id's payload at world_pos and starts that ability's cooldown.
## Returns false with no state change if it is disabled, out of round, unknown,
## or still cooling.
##
## Takes an explicit world position rather than reading the mouse, because
## get_global_mouse_position() is not reliably driven by input_simulate in this
## environment (CLAUDE.md, Gotchas) — calling this directly via execute_code is
## the only way this path can be verified.
func cast(ability_id: String, world_pos: Vector2) -> bool:
	if not can_cast(ability_id):
		return false

	var entry: Dictionary = ABILITIES[ability_id]
	var payload = entry["scene"].instantiate()
	payload.map = map
	# Parented to the map, not to this manager, so it shares the world
	# transform every other entity uses. Position is set after add_child:
	# before the node is in the tree, global_position has no parent transform
	# to resolve against.
	map.add_child(payload)
	payload.global_position = world_pos

	# The cooldown starts at cast, not at impact — the arc is travel time the
	# player has already committed to.
	var total: float = entry["cooldown"]
	cooldowns[ability_id] = total
	cooldown_changed.emit(ability_id, total, total)
	return true


func cast_selected(world_pos: Vector2) -> bool:
	return cast(selected_ability, world_pos)


## Hold LMB to aim, release to drop; right-click cancels; number keys select.
## Forwarded from level_controller._unhandled_input(), which does nothing but
## route — all logic lives here.
##
## _unhandled_input, NOT _input: _input runs before GUI handling, so a click on
## the ability bar would start an aim here and throw on release at whatever
## world position sits behind the bar. Controls consume clicks that land on
## them, so unhandled input only ever sees clicks on the game world.
func handle_input(event: InputEvent) -> void:
	if _marker == null:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			_try_select_by_key(event.keycode)
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
		aiming = true
		_marker.global_position = map.get_global_mouse_position()
		_marker.set_radius(get_radius(selected_ability))
		_marker.set_ready(can_cast(selected_ability))
		_marker.show()
	elif aiming:
		# Read the position off the marker rather than the mouse again: the
		# marker is what the player was looking at, so a release arriving a
		# frame after the last motion still throws where they aimed.
		var target: Vector2 = _marker.global_position
		cancel_aim()
		cast_selected(target)


func _try_select_by_key(keycode: int) -> void:
	for ability_id in ABILITIES:
		if ABILITIES[ability_id]["key"] == keycode:
			select(ability_id)
			return
