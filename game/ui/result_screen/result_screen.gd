extends CanvasLayer

## The end-of-round screen. A4's U-3, and the one piece of interface A4 exists
## for.
##
## THE POINT OF THIS FILE, stated plainly because it is easy to trim away as
## copywriting: **a fresh save LOSES level_01 at wave 4, by explicit design
## decision (2026-09-06).** So a new player's first game is a loss. The old
## result panel said "Round Lost / Earned: 422 silver" and nothing else — and
## "earned" reads as *earned and then lost with the round*, which is exactly
## backwards. The silver is banked permanently and is what buys the win.
##
## A player who quits there quits because the interface lied to them about the
## game's central mechanic. Saying so is not decoration; it is the difference
## between a roguelite loop and an apparent dead end.
##
## Signal-driven off round_ended(won, gold_awarded, silver_earned) — no new
## backend. gold_awarded is already the ACTUAL amount paid (0 on a replay,
## because PlayerData.award_level_gold enforces gold-once), so this must never
## infer "gold was paid" from won == true.

const Palette := preload("res://ui/palette.gd")

## Back to the main menu. WITHOUT THIS BUTTON THE MENU IS UNREACHABLE after the
## first round: pausing is disarmed the moment a round ends (pause_menu.setup(false)
## in _end_round), so Escape does nothing here and Play Again would be the only
## way out of the level forever.
signal menu_requested

var map: Node2D = null

@onready var panel: PanelContainer = $Root/Center/Card
@onready var headline: Label = $Root/Center/Card/Rows/Headline
@onready var stats: Label = $Root/Center/Card/Rows/Stats
@onready var reassurance: Label = $Root/Center/Card/Rows/Reassurance
@onready var play_again_button: Button = $Root/Center/Card/Rows/PlayAgainButton
@onready var menu_button: Button = $Root/Center/Card/Rows/MenuButton

## Waves reached, mirrored from wave_started rather than read off the manager,
## keeping this signal-driven like the HUD.
var _wave_num: int = 0
var _wave_total: int = 0


func setup(map_ref: Node2D) -> void:
	map = map_ref
	map.round_started.connect(_on_round_started)
	map.round_ended.connect(_on_round_ended)
	map.wave_manager.wave_started.connect(_on_wave_started)


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	menu_button.pressed.connect(func(): menu_requested.emit())
	hide()


func _on_wave_started(wave_num: int, wave_total: int, _enemy_count: int) -> void:
	_wave_num = wave_num
	_wave_total = wave_total


func _on_round_started() -> void:
	_wave_num = 0
	_wave_total = 0
	hide()


func _on_round_ended(won: bool, gold_awarded: int, silver_earned: int) -> void:
	if won:
		headline.text = "Victory"
		headline.theme_type_variation = &"ResultWon"
	else:
		headline.text = "Defeat"
		headline.theme_type_variation = &"ResultLost"

	var lines: Array[String] = []
	lines.append("Waves survived   %d / %d" % [_wave_num, _wave_total])
	lines.append("Enemies killed   %d" % map.kills_this_round)
	lines.append("Silver earned    %d" % silver_earned)
	if gold_awarded > 0:
		lines.append("Gold awarded     %d" % gold_awarded)
	elif won:
		# Distinguished from "no gold" so a replay does not look like a bug.
		# Gold is finite and paid once per level; silver is the farmable one.
		lines.append("Gold             already claimed")
	stats.text = "\n".join(lines)

	# THE LINE THIS SCREEN EXISTS FOR. Only shown on a loss, because that is the
	# only time a player has reason to believe they lost their progress.
	reassurance.visible = not won
	if not won:
		reassurance.text = "You keep every silver you earned.\nSpend it on upgrades, then try again."

	play_again_button.text = "Play Again" if won else "Upgrade & Retry"
	show()
	play_again_button.grab_focus()


func _on_play_again_pressed() -> void:
	# Hidden immediately rather than waiting for the next round_started — that
	# fires from _start_round() (the Start button), not from start_new_round()
	# (this button), so it would not fire until the player pressed Start again,
	# leaving this screen stuck over the build phase. round_ui learned this the
	# hard way, and the HUD learned it again at U-2.
	hide()
	map.start_new_round()
