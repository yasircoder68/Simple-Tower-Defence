extends CanvasLayer

## The settings screen. A5-3.
##
## SELF-CONTAINED, exactly like the upgrade screen (A4's U-5) and for the same
## reason: it reads the Settings autoload and nothing else, never `map`, so the
## identical scene works as a child of the main menu with no level loaded AND as
## an overlay inside a running level. That is what lets both entry points share
## one scene instead of two.
##
## PROCESS_MODE_ALWAYS, set here rather than in the .tscn so the reason travels
## with the code: the pause screen opens this, and the tree is paused when it
## does. A screen that inherits would be frozen the moment it appeared — its
## buttons dead, exactly the soft-lock the pause work warned about. It is
## therefore the SECOND always-on node in the project; CLAUDE.md previously said
## pause_menu was the only one.
##
## Controls are built in code rather than authored, following upgrade_screen's
## rows: the option list is data, and a procedural row cannot drift from the
## Settings API the way a hand-placed one can.
##
## NO AUDIO ROWS YET. A5-2 owns the buses and no files have been supplied, so
## adding sliders now would ship two dead controls. When it lands they are two
## more entries in _build_rows().

signal closed

@onready var options_box: VBoxContainer = $Scrim/Center/Card/Rows/Options
@onready var close_button: Button = $Scrim/Center/Card/Rows/CloseButton

var _fullscreen_check: CheckButton = null
var _vsync_check: CheckButton = null
var _resolution_option: OptionButton = null


func _ready() -> void:
	# See the class comment. Without this the screen is inert when the pause
	# menu opens it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rows()
	close_button.pressed.connect(_on_close_pressed)
	hide_screen()


func _build_rows() -> void:
	_fullscreen_check = _add_toggle("Fullscreen", "FullscreenCheck")
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_vsync_check = _add_toggle("VSync", "VSyncCheck")
	_vsync_check.toggled.connect(_on_vsync_toggled)

	var row := HBoxContainer.new()
	row.name = "ResolutionRow"
	var label := Label.new()
	label.text = "Resolution"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_resolution_option = OptionButton.new()
	# Named for the same reason upgrade_screen names its buttons: an anonymous
	# procedural Control gets a name like @OptionButton@42, gettable at runtime
	# but not guessable in advance for testing.
	_resolution_option.name = "ResolutionOption"
	for i in Settings.RESOLUTIONS.size():
		_resolution_option.add_item(Settings.resolution_name(i), i)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	row.add_child(_resolution_option)
	options_box.add_child(row)


func _add_toggle(text: String, node_name: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.name = node_name + "Row"
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var check := CheckButton.new()
	check.name = node_name
	row.add_child(check)
	options_box.add_child(row)
	return check


## Pushes Settings -> widgets. Called on open so the screen can never show a
## stale value, and deliberately NOT the other direction: Settings is the source
## of truth and these are just a view of it.
func _sync_from_settings() -> void:
	# set_pressed_no_signal, not set_pressed: the plain setter emits toggled(),
	# which would call straight back into Settings and re-save on every open.
	_fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_vsync_check.set_pressed_no_signal(Settings.vsync)
	_resolution_option.select(Settings.resolution_index)
	# Resolution is meaningless while fullscreen — the choice is still stored
	# and re-applies on the way out, so this greys out rather than hides.
	_resolution_option.disabled = Settings.fullscreen


func open() -> void:
	_sync_from_settings()
	visible = true
	close_button.grab_focus()


func hide_screen() -> void:
	visible = false


# --- Handlers ---------------------------------------------------------------

func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.set_fullscreen(pressed)
	_resolution_option.disabled = Settings.fullscreen


func _on_vsync_toggled(pressed: bool) -> void:
	Settings.set_vsync(pressed)


func _on_resolution_selected(index: int) -> void:
	Settings.set_resolution_index(index)


func _on_close_pressed() -> void:
	hide_screen()
	closed.emit()
