extends Control

## The main menu, and the game's boot scene. A4's U-4.
##
## SCENE REPLACEMENT ONLY — NEVER A RESIDENT OVERLAY. This is an architectural
## constraint of the stage, not a style preference:
##
## get_tree().change_scene_to_file() frees the current scene and makes the new
## one a DIRECT CHILD OF root, so the level's root node stays `map1` at
## `/root/map1`. Every gotcha, every scope_path and every MCP verification
## snippet in CLAUDE.md is written against that path. A menu that stayed
## resident above the level would push the level down a level and invalidate
## all of it, for a purely cosmetic gain.
##
## alpha_plan's A4 sketch predicted "a main menu changes /root/map1 — expect a
## docs pass". It does not, as long as scenes are replaced rather than nested.
## The only real change is that run/main_scene now points here, so a playtest
## started with scene_path "main" lands on the menu instead of a playable level.
##
## Nothing round-scoped lives here. The only state that survives the transition
## is the autoloads (PlayerData, TowerStats), which is exactly what CLAUDE.md's
## state-boundary table says should.

const LEVEL_PATH := "res://levels/level_01.tscn"

@onready var currency_label: Label = $Backdrop/Center/Card/Rows/Currency
@onready var begin_button: Button = $Backdrop/Center/Card/Rows/BeginButton
@onready var quit_button: Button = $Backdrop/Center/Card/Rows/QuitButton


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Surfacing the persistent currencies here is the cheapest possible way to
	# make meta-progression visible before the player has played anything. It is
	# the hook the whole economy rests on — a returning player should see that
	# their last run left them better off.
	currency_label.text = "Silver %d     Gold %d" % [PlayerData.silver, PlayerData.gold]

	begin_button.grab_focus()


## No Upgrades entry yet — U-5 builds the upgrade screen and adds its button in
## the same step. A disabled button now would be dead UI in a shipped build, and
## the menu is the first thing a stranger sees.
func _on_begin_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
