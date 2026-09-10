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

var _upgrade_screen: CanvasLayer = null
var _settings_screen: CanvasLayer = null

@onready var currency_label: Label = $Backdrop/Center/Card/Rows/Currency
@onready var begin_button: Button = $Backdrop/Center/Card/Rows/BeginButton
@onready var upgrades_button: Button = $Backdrop/Center/Card/Rows/UpgradesButton
@onready var settings_button: Button = $Backdrop/Center/Card/Rows/SettingsButton
@onready var quit_button: Button = $Backdrop/Center/Card/Rows/QuitButton


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)

	# The upgrade screen is a self-contained CanvasLayer that reads only the
	# autoloads, so the SAME scene works here with no level loaded and as an
	# overlay inside a running one. Added as a child rather than swapped to via
	# change_scene_to_file, because this is a modal over the menu, not a
	# destination — and swapping would need a way back that re-reads the save.
	_upgrade_screen = preload("res://ui/upgrade_screen/upgrade_screen.tscn").instantiate()
	add_child(_upgrade_screen)
	_upgrade_screen.closed.connect(_on_upgrades_closed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Same self-contained-CanvasLayer argument as the upgrade screen above: it
	# reads only the Settings autoload, so this one scene serves the menu and
	# the pause screen without either knowing about the other.
	_settings_screen = preload("res://ui/settings_screen/settings_screen.tscn").instantiate()
	add_child(_settings_screen)
	_settings_screen.closed.connect(_on_settings_closed)

	quit_button.pressed.connect(_on_quit_pressed)

	# Surfacing the persistent currencies here is the cheapest possible way to
	# make meta-progression visible before the player has played anything. It is
	# the hook the whole economy rests on — a returning player should see that
	# their last run left them better off.
	_refresh_currency()

	begin_button.grab_focus()


## Always allowed from here: there is no round running at the main menu, which
## is exactly the rule the shop gates on. See upgrade_screen.gd.
func _on_upgrades_pressed() -> void:
	_upgrade_screen.open(true)


## The currencies on the menu are read once in _ready(), so a purchase made in
## the shop would leave a stale figure behind it.
func _on_upgrades_closed() -> void:
	_refresh_currency()
	begin_button.grab_focus()


func _refresh_currency() -> void:
	currency_label.text = "Silver %d     Gold %d" % [PlayerData.silver, PlayerData.gold]


func _on_settings_pressed() -> void:
	_settings_screen.open()


## Focus has to be handed back explicitly — the screen took it on open() and
## the button that opened it is no longer focused when it closes.
func _on_settings_closed() -> void:
	settings_button.grab_focus()


func _on_begin_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
