extends CanvasLayer

## The pause screen. A4's U-1.
##
## THE WHOLE PAUSE POLICY, IN ONE LINE: **everything inherits; only this node is
## PROCESS_MODE_ALWAYS.**
##
## That is deliberately the opposite of what alpha_plan's A4 sketch predicted. It
## expected wave_manager's two Timers, ability_manager's _process cooldown tick
## and the boulder's Tween each to need their own process_mode, or "pausing
## either fails to stop the horde or permanently strands a cooldown". Measured
## instead: nothing in the project sets process_mode at all, so everything sits
## at PROCESS_MODE_INHERIT and get_tree().paused already stops all of it. The
## work was one exception, not four rules.
##
## The one genuine hazard the sketch identified was a cooldown on a WALL-CLOCK
## deadline — a Time.get_ticks_msec() target survives a pause and snaps to zero
## on resume. ability_manager does `remaining = max(remaining - delta, 0.0)`,
## which is delta-accumulated, so it freezes correctly. **Any future cooldown,
## timer or duration must be delta-accumulated for the same reason.**
##
## Two things that follow, and that a later change could quietly break:
##
## - **The HUD must NOT be PROCESS_MODE_ALWAYS.** It would keep animating behind
##   this screen. Keep the HUD on its own CanvasLayer at the default mode.
## - **The input handler that toggles pause lives HERE**, on the node that is
##   ALWAYS. On a paused node it would never run, and the only way out of a
##   pause would be to kill the process.

const Palette := preload("res://ui/palette.gd")

## Emitted instead of this screen reaching into the map itself, so the level
## controller owns what "restart" and "quit" actually mean. Same signal-driven
## discipline as every other manager here.
signal resume_requested
signal restart_requested
## Back to the main menu — a scene REPLACEMENT, handled by the level controller.
signal menu_requested
## All the way out of the game.
signal quit_requested

@onready var scrim: ColorRect = $Scrim
@onready var resume_button: Button = $Scrim/Center/Card/Rows/ResumeButton
@onready var restart_button: Button = $Scrim/Center/Card/Rows/RestartButton
@onready var settings_button: Button = $Scrim/Center/Card/Rows/SettingsButton
@onready var menu_button: Button = $Scrim/Center/Card/Rows/MenuButton
@onready var quit_button: Button = $Scrim/Center/Card/Rows/QuitButton

## Whether pausing is currently allowed. False outside a round: pausing a build
## phase would be a screen that stops nothing.
var can_pause: bool = false

var _settings_screen: CanvasLayer = null


func _ready() -> void:
	# Set from the palette rather than baked into the .tscn, so the scrim
	# follows a reskin like everything else. A Theme cannot express it — themes
	# style Controls by type, and this is one specific node's colour.
	scrim.color = Palette.SCRIM

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Owned here rather than signalled out to the level controller, unlike
	# restart/menu/quit. Those three need the controller to decide what they
	# MEAN; settings decides for itself and touches no round state, so routing
	# it through the map would be ceremony. It sits at layer 110 against this
	# screen's 100 so it renders on top, and sets its own PROCESS_MODE_ALWAYS
	# because the tree is paused whenever it is opened from here.
	_settings_screen = preload("res://ui/settings_screen/settings_screen.tscn").instantiate()
	add_child(_settings_screen)
	_settings_screen.closed.connect(_on_settings_closed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	hide()


func setup(round_running: bool) -> void:
	can_pause = round_running


## ui_cancel is Escape by default and is already bound in every Godot project,
## so this needs no InputMap entry — one less thing to configure and one less
## thing to forget when a second level is added.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Escape closes the settings screen FIRST when it is stacked on this one.
	# Without this the press falls through to _on_resume_pressed() and the game
	# unpauses out from under a settings screen that is still on top of it --
	# the round running invisibly behind a modal.
	if _settings_screen != null and _settings_screen.visible:
		_settings_screen.hide_screen()
		settings_button.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if visible:
		_on_resume_pressed()
	elif can_pause:
		pause()
	else:
		return
	# Consumed either way, so Escape cannot also reach the level controller and
	# cancel a tower drag on the same press.
	get_viewport().set_input_as_handled()


func _on_settings_pressed() -> void:
	_settings_screen.open()


func _on_settings_closed() -> void:
	settings_button.grab_focus()


func pause() -> void:
	if visible:
		return
	get_tree().paused = true
	show()
	# Grab focus so the screen is keyboard- and controller-navigable from the
	# moment it opens. Without it the focus ring has nothing to sit on and
	# arrow keys do nothing.
	resume_button.grab_focus()


func resume() -> void:
	if not visible:
		return
	# Defensive: every path out of a pause goes through here (button, Escape,
	# and level_controller restarting), so closing the child here means no
	# caller has to remember to.
	if _settings_screen != null:
		_settings_screen.hide_screen()
	hide()
	get_tree().paused = false


# --- Button handlers ----------------------------------------------------

func _on_resume_pressed() -> void:
	resume()
	resume_requested.emit()


## Unpauses BEFORE emitting, so whatever handles the restart runs on a live
## tree. Restarting into a still-paused tree is a soft lock that looks exactly
## like a crash: the new round exists and nothing in it moves.
func _on_restart_pressed() -> void:
	resume()
	restart_requested.emit()


## Unpaused before emitting, for the same reason restart is: change_scene_to_file
## frees this tree, and leaving get_tree().paused true would carry the pause
## into the NEXT scene — a main menu whose buttons do nothing.
func _on_menu_pressed() -> void:
	resume()
	menu_requested.emit()


func _on_quit_pressed() -> void:
	resume()
	quit_requested.emit()
