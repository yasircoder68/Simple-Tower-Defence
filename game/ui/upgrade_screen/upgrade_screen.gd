extends CanvasLayer

## The upgrade shop. A4's U-5 — the last piece round_ui was still carrying.
##
## SELF-CONTAINED ON PURPOSE. It reads PlayerData and TowerStats and nothing
## else, both of which are autoloads, so the identical scene works in two very
## different contexts: as a child of the main menu with no level loaded at all,
## and as an overlay inside a running level. It never touches `map`, which is
## what makes that possible.
##
## NO NEW BACKEND. TowerStats.try_upgrade(), get_upgrade_cost(),
## PlayerData.get_upgrade_level() and the 10 * 1.35^level silver curve have all
## been working and verified since M1. This is a screen wired to a finished
## economy.
##
## THE GATING IS RE-THOUGHT, NOT PORTED. round_ui asked
## `map.round_state == PRE_ROUND`, which cannot be asked at the main menu —
## there is no round and no map. The real rule underneath was never "PRE_ROUND";
## it was **"upgrades are allowed whenever no round is running"**, which is true
## both at the menu and between rounds. The opener knows which it is and says so
## via open(); this screen does not guess.

const Palette := preload("res://ui/palette.gd")

signal closed

@onready var scrim: ColorRect = $Scrim
@onready var silver_label: Label = $Scrim/Center/Card/Rows/Silver
@onready var tracks_box: VBoxContainer = $Scrim/Center/Card/Rows/Tracks
@onready var close_button: Button = $Scrim/Center/Card/Rows/CloseButton

## tower_type -> track -> Button, so a refresh updates labels in place instead
## of rebuilding the list on every silver change.
var _buttons: Dictionary = {}

## Whether purchases are legal right now. Set by open(); see the class comment.
var _allowed: bool = false


func _ready() -> void:
	scrim.color = Palette.SCRIM
	close_button.pressed.connect(_on_close_pressed)
	_build_rows()
	PlayerData.silver_changed.connect(_on_silver_changed)
	PlayerData.upgrade_changed.connect(_on_upgrade_changed)
	hide()


## `allowed` is the caller's answer to "is a round running right now?". The main
## menu passes true unconditionally; a level passes round_state == PRE_ROUND.
func open(allowed: bool = true) -> void:
	_allowed = allowed
	_refresh()
	show()
	close_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


## Escape closes the shop rather than falling through to whatever is behind it.
## In a level that "whatever" is the pause screen, which would otherwise open
## underneath this one.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Construction -------------------------------------------------------

## Generated from PlayerData's TOWER_TYPES x UPGRADE_TRACKS rather than authored
## in the .tscn, so a third tower or a fourth upgrade track appears here for free
## instead of needing six more nodes placed by hand. The .tscn owns the frame;
## the registry owns the contents.
func _build_rows() -> void:
	for tower_type in PlayerData.TOWER_TYPES:
		var heading := Label.new()
		heading.text = String(tower_type).capitalize()
		heading.theme_type_variation = &"H2"
		tracks_box.add_child(heading)

		_buttons[tower_type] = {}
		for track in PlayerData.UPGRADE_TRACKS:
			var btn := Button.new()
			# Named for the same reason round_ui's were: an anonymous
			# procedurally created Control gets a name like @Button@42, which is
			# gettable at runtime but not guessable in advance for testing.
			btn.name = "UpgradeButton_%s_%s" % [tower_type, track]
			btn.pressed.connect(_on_upgrade_pressed.bind(tower_type, track))
			tracks_box.add_child(btn)
			_buttons[tower_type][track] = btn


# --- Handlers -----------------------------------------------------------

## The AUTHORITATIVE guard, not just the button's disabled flag. A disabled
## Button ignores real clicks, but anything emitting `pressed` directly sails
## past it — and input_simulate's click_node does exactly that, which silently
## defeated the first version of this test in M1. "No upgrades mid-round" is a
## rule, not a UI hint.
func _on_upgrade_pressed(tower_type: String, track: String) -> void:
	if not _allowed or not visible:
		return
	# try_upgrade() spends and increments atomically; on failure nothing changes
	# and no signal fires, so the buttons simply stay as they were.
	TowerStats.try_upgrade(tower_type, track)


func _on_silver_changed(_n: int) -> void:
	if visible:
		_refresh()


func _on_upgrade_changed(_tower_type: String, _track: String, _level: int) -> void:
	if visible:
		_refresh()


func _on_close_pressed() -> void:
	close()


func _refresh() -> void:
	silver_label.text = "Silver  %d" % PlayerData.silver
	for tower_type in _buttons:
		for track in _buttons[tower_type]:
			var btn: Button = _buttons[tower_type][track]
			var level: int = PlayerData.get_upgrade_level(tower_type, track)
			var cost: int = TowerStats.get_upgrade_cost(tower_type, track)
			btn.text = "%s  Lv%d  —  %d silver" % [String(track).capitalize(), level, cost]
			btn.disabled = not _allowed or cost > PlayerData.silver
