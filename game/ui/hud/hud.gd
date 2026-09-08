extends CanvasLayer

## The in-round HUD. A4's U-2, and the first permanent piece of interface this
## project has had — it replaces round_ui's status labels and breather panel,
## which were explicitly throwaway.
##
## ENTIRELY SIGNAL-DRIVEN. Nothing here polls the game state, because every
## number it shows already has a signal behind it: PlayerData.silver_changed,
## gold_changed, base_health.life_lost, wave_manager.wave_started, and so on.
## That was true before this file existed — A1 and A2 built the managers
## signal-first specifically so the HUD would cost nothing to wire.
##
## The one exception is the breather countdown, which reads a Timer in _process.
## That is deliberate: a Timer's time_left changes every frame, and emitting a
## signal per frame to move one label would be worse than reading it.
##
## THIS NODE MUST NOT BE PROCESS_MODE_ALWAYS. It inherits, so it freezes with
## the rest of the game when the pause screen opens. An ALWAYS HUD would keep
## ticking its countdown behind a paused game. See ui/pause_menu/pause_menu.gd
## for the whole pause policy.

var map: Node2D = null

@onready var fps_label: Label = $Root/TopLeft/FpsLabel
@onready var silver_value: Label = $Root/TopLeft/Stats/Grid/SilverValue
@onready var gold_value: Label = $Root/TopLeft/Stats/Grid/GoldValue
@onready var lives_value: Label = $Root/TopLeft/Stats/Grid/LivesValue
@onready var wave_value: Label = $Root/TopLeft/Stats/Grid/WaveValue
@onready var controls_hint: Label = $Root/TopLeft/ControlsHint
@onready var upgrades_button: Button = $Root/TopLeft/UpgradesButton

@onready var breather_panel: PanelContainer = $Root/Breather
@onready var breather_label: Label = $Root/Breather/Rows/BreatherLabel
@onready var skip_button: Button = $Root/Breather/Rows/SkipButton

## Debug readout, off in a shipped build. Kept because the perf work needs it —
## but see the note in _ready() about what was removed with it.
@export var show_fps: bool = false

## Opens the upgrade shop. The level controller connects this rather than the
## HUD reaching for the screen itself — the HUD displays, it does not navigate.
signal upgrades_requested

## Mirrored from wave_started rather than read off wave_manager, so this stays
## signal-driven — the manager's wave list is its own business.
var _wave_num: int = 0
var _wave_total: int = 0


func setup(map_ref: Node2D) -> void:
	map = map_ref

	PlayerData.silver_changed.connect(_on_silver_changed)
	PlayerData.gold_changed.connect(_on_gold_changed)
	map.base_health.life_lost.connect(_on_life_lost)
	map.round_started.connect(_on_round_started)
	map.round_ended.connect(_on_round_ended)

	map.wave_manager.wave_started.connect(_on_wave_started)
	map.wave_manager.breather_started.connect(_on_breather_started)
	map.wave_manager.all_waves_complete.connect(_on_all_waves_complete)

	refresh()


func _ready() -> void:
	# The FPS readout used to live as a loose Label in level_01.tscn running
	# ui/fps_counter.gd, which ALSO did:
	#
	#     if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()
	#
	# That made Escape quit the game, and it survived U-1 shipping a pause
	# screen on the same key — Input.is_action_just_pressed() POLLS, so the
	# pause screen's set_input_as_handled() could not suppress it. Pressing
	# Escape opened the pause menu and quit the process in the same frame.
	#
	# Absorbed here without the quit. Escape is the pause key now, and quitting
	# is a deliberate choice from the pause screen.
	fps_label.visible = show_fps
	skip_button.pressed.connect(_on_skip_breather_pressed)
	upgrades_button.pressed.connect(func(): upgrades_requested.emit())
	breather_panel.hide()


func _process(_delta: float) -> void:
	if show_fps:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()

	# Polled rather than signalled: a Timer's time_left changes every frame, and
	# firing a signal per frame to move one label would be worse than reading
	# it. Guarded on visibility so it costs nothing the rest of the round.
	if breather_panel.visible and map != null:
		breather_label.text = "Next wave in %ds" % ceili(map.wave_manager.get_breather_remaining())


# --- Signal handlers ----------------------------------------------------

func _on_silver_changed(_n: int) -> void:
	refresh()


func _on_gold_changed(_n: int) -> void:
	refresh()


func _on_life_lost(_remaining: int) -> void:
	refresh()


func _on_wave_started(wave_num: int, wave_total: int, _enemy_count: int) -> void:
	_wave_num = wave_num
	_wave_total = wave_total
	# Hidden here as well as in the skip handler: a breather also ends by simply
	# timing out, and that path never touches the button.
	breather_panel.hide()
	refresh()


func _on_breather_started(_seconds: float) -> void:
	breather_panel.show()


func _on_all_waves_complete() -> void:
	breather_panel.hide()


func _on_skip_breather_pressed() -> void:
	map.wave_manager.skip_breather()
	# Hidden immediately rather than waiting for wave_started, following the
	# rule Play Again learned the hard way: hide UI state in the handler that
	# changes it, don't assume a lifecycle signal covers every entry point.
	breather_panel.hide()


func _on_round_started() -> void:
	# Cleared here, then repopulated microseconds later by wave_started —
	# _start_round() emits round_started before wave_manager.begin().
	_wave_num = 0
	_wave_total = 0
	refresh()


func _on_round_ended(_won: bool, _gold_awarded: int, _silver_earned: int) -> void:
	# A round can end DURING a breather — a loss on the escape that drains the
	# last life — which would otherwise leave the countdown ticking under the
	# result screen.
	breather_panel.hide()
	refresh()


## Back to a fresh PRE_ROUND readout. Called from start_new_round(), which does
## NOT emit round_started (only the Start button's _start_round() does), so
## nothing else would clear this state.
##
## It resets the WAVE COUNTERS as well as refreshing, and that is the whole
## point of it existing separately from refresh(): a bare refresh() left the HUD
## reading "Wave 5/5" while sitting in PRE_ROUND with no round running. Caught
## by testing the Play Again path rather than assuming it — the exact same
## asymmetry that has now bitten this project three times.
func reset_for_new_round() -> void:
	_wave_num = 0
	_wave_total = 0
	refresh()


## refresh() alone is safe to call mid-round; it never touches the wave counters,
## which are owned by wave_started.
func refresh() -> void:
	if map == null:
		return
	silver_value.text = str(PlayerData.silver)
	gold_value.text = str(PlayerData.gold)
	lives_value.text = "%d/%d" % [map.base_health.lives, map.base_health.max_lives]
	wave_value.text = "%d/%d" % [_wave_num, _wave_total] if _wave_total > 0 else "-"
	# Dimmed rather than hidden outside the build phase: the controls still
	# exist, they are just not usable right now, and a hint that vanishes reads
	# as a bug rather than as a state.
	var between_rounds: bool = map.round_state == map.RoundState.PRE_ROUND
	controls_hint.modulate.a = 1.0 if between_rounds else 0.4
	# HIDDEN rather than disabled outside the build phase. A disabled shop button
	# invites the click the authoritative guard then has to refuse; not offering
	# it at all states more clearly that upgrading is a between-rounds activity.
	# The guard in upgrade_screen.gd exists regardless — a disabled Button is not
	# a rule, and click_node walks straight past one.
	upgrades_button.visible = between_rounds
