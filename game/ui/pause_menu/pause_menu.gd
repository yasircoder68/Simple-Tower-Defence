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
signal quit_requested

@onready var scrim: ColorRect = $Scrim
@onready var resume_button: Button = $Scrim/Center/Card/Rows/ResumeButton
@onready var restart_button: Button = $Scrim/Center/Card/Rows/RestartButton
@onready var quit_button: Button = $Scrim/Center/Card/Rows/QuitButton

## Whether pausing is currently allowed. False outside a round: pausing a build
## phase would be a screen that stops nothing.
var can_pause: bool = false


func _ready() -> void:
	# Set from the palette rather than baked into the .tscn, so the scrim
	# follows a reskin like everything else. A Theme cannot express it — themes
	# style Controls by type, and this is one specific node's colour.
	scrim.color = Palette.SCRIM

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
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
	if visible:
		_on_resume_pressed()
	elif can_pause:
		pause()
	else:
		return
	# Consumed either way, so Escape cannot also reach the level controller and
	# cancel a tower drag on the same press.
	get_viewport().set_input_as_handled()


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


func _on_quit_pressed() -> void:
	resume()
	quit_requested.emit()
