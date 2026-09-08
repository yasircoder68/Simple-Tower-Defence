extends CanvasLayer

## Crude, unstyled M1 UI: status readout, win/lose result, upgrade purchases.
## This is NOT the real HUD — see ui_plan.md (UI-1 for the HUD, UI-4 for
## screens). It exists only to make M1's loop playable and observable:
## place towers -> kill -> earn silver -> buy +damage -> replay -> feel it.
## Every node here is thrown away, not refactored, when UI-0/UI-1 land.

var map: Node2D = null

var silver_label: Label
var gold_label: Label
var lives_label: Label
var wave_label: Label
var controls_hint_label: Label

var breather_panel: PanelContainer
var breather_label: Label
var skip_breather_button: Button

## Mirrored from wave_started rather than read off wave_manager, so this stays
## signal-driven — the manager's wave list is its own business.
var _wave_num: int = 0
var _wave_total: int = 0

var result_panel: Panel
var result_label: Label
var play_again_button: Button

## True once the HUD owns the status readout and breather. See setup().
var _status_suppressed: bool = false

var upgrade_panel: PanelContainer
# tower_type -> track -> Button, so a refresh can update labels in place
# instead of rebuilding the panel.
var upgrade_buttons: Dictionary = {}


## suppress_status skips the parts A4's U-2 HUD took over: the status labels and
## the breather panel. Skipping CONSTRUCTION rather than hiding the nodes is
## deliberate — a hidden panel still has live signal handlers that would fight
## the HUD for the same state, and _process() would still tick a countdown.
##
## round_ui is deleted outright at U-6. Until then it keeps the result and
## upgrade panels, which U-3 and U-5 have not replaced yet.
func setup(map_ref: Node2D, suppress_status: bool = false) -> void:
	map = map_ref
	_status_suppressed = suppress_status

	PlayerData.silver_changed.connect(_on_silver_changed)
	PlayerData.gold_changed.connect(_on_gold_changed)
	PlayerData.upgrade_changed.connect(_on_upgrade_changed)
	map.base_health.life_lost.connect(_on_life_lost)
	map.round_started.connect(_on_round_started)
	map.round_ended.connect(_on_round_ended)

	map.wave_manager.wave_started.connect(_on_wave_started)
	map.wave_manager.breather_started.connect(_on_breather_started)
	map.wave_manager.all_waves_complete.connect(_on_all_waves_complete)

	if not _status_suppressed:
		_build_status_labels()
		_build_breather_panel()
	_build_upgrade_panel()
	_build_result_panel()

	_refresh_status()
	_refresh_upgrade_buttons()


# --- Construction ------------------------------------------------------

func _build_status_labels() -> void:
	var vbox := VBoxContainer.new()
	vbox.offset_left = 10
	vbox.offset_top = 90 # below FPSLabel, which runs roughly 10-80
	add_child(vbox)

	silver_label = Label.new()
	vbox.add_child(silver_label)
	gold_label = Label.new()
	vbox.add_child(gold_label)
	lives_label = Label.new()
	vbox.add_child(lives_label)
	wave_label = Label.new()
	vbox.add_child(wave_label)

	controls_hint_label = Label.new()
	# Manual break, not autowrap: left unconstrained, a single-line hint runs
	# out over the play area, and default white text over the white tilemap
	# walls goes unreadable — so it needs to stay within the ~260px column
	# every other panel already uses. AUTOWRAP_WORD's own line-break math
	# disagreed with the final glyph render by a couple pixels right at that
	# boundary and clipped a word mid-render, for both a long one-line string
	# and a shorter "should still fit" one. A fixed \n at a clean word
	# boundary is deterministic and doesn't depend on getting that measurement
	# exactly right.
	controls_hint_label.text = "Move: drag\nRemove: right-click"
	controls_hint_label.custom_minimum_size.x = 260
	vbox.add_child(controls_hint_label)


## Countdown to the next wave, plus a way out of it. Occupies the top-centre
## slot the StartButton uses — the two are never visible at once, since the
## button only shows in PRE_ROUND and a breather only happens mid-round.
func _build_breather_panel() -> void:
	# Content-sized, for the same reason as the upgrade panel below. This one
	# was not visibly broken by UI-0's theme - but measuring it found the VBox
	# minimum height was 60 inside exactly 60px of space. ZERO slack: it renders
	# correctly today and clips the Skip button on the next palette change.
	# "It looks fine" is the reasoning that produced the upgrade panel's bug.
	#
	# GROW_DIRECTION_BOTH is what lets a content-sized Control stay centred:
	# anchored to the horizontal midpoint with zero offsets, it expands equally
	# in both directions instead of growing off to the right.
	breather_panel = PanelContainer.new()
	breather_panel.anchor_left = 0.5
	breather_panel.anchor_right = 0.5
	breather_panel.offset_left = 0
	breather_panel.offset_right = 0
	breather_panel.offset_top = 20
	breather_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	breather_panel.custom_minimum_size.x = 220
	_hide_breather()
	add_child(breather_panel)

	var vbox := VBoxContainer.new()
	breather_panel.add_child(vbox)

	breather_label = Label.new()
	breather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(breather_label)

	skip_breather_button = Button.new()
	skip_breather_button.name = "SkipBreatherButton"
	skip_breather_button.text = "Skip"
	skip_breather_button.pressed.connect(_on_skip_breather_pressed)
	vbox.add_child(skip_breather_button)


func _build_upgrade_panel() -> void:
	# PanelContainer, not Panel: it sizes ITSELF to its content, so the panel
	# cannot be outgrown by its own buttons.
	#
	# The previous version hardcoded a 240px height (offset_bottom 495) against
	# Godot's DEFAULT button metrics. UI-0's theme gives every button content
	# margins, and the six upgrade buttons immediately overflowed the panel
	# background by three rows - visible on the very first run after the theme
	# landed. Bumping the number would defer the identical bug to the next
	# palette change, which is exactly what a generated theme exists to make
	# cheap; sizing to content removes the failure mode instead.
	#
	# The inner VBox needs no anchors or insets either: the theme's `panel`
	# stylebox carries the content margins, so padding is a palette value
	# rather than four magic numbers per panel.
	upgrade_panel = PanelContainer.new()
	upgrade_panel.position = Vector2(10, 255) # status vbox runs 90-245
	upgrade_panel.custom_minimum_size.x = 260 # the column width every panel uses
	add_child(upgrade_panel)

	var vbox := VBoxContainer.new()
	upgrade_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Upgrades (Silver)"
	vbox.add_child(title)

	for tower_type in PlayerData.TOWER_TYPES:
		var tower_label := Label.new()
		tower_label.text = String(tower_type).capitalize()
		vbox.add_child(tower_label)

		upgrade_buttons[tower_type] = {}
		for track in PlayerData.UPGRADE_TRACKS:
			var btn := Button.new()
			btn.name = "UpgradeButton_%s_%s" % [tower_type, track]
			btn.pressed.connect(_on_upgrade_pressed.bind(tower_type, track))
			vbox.add_child(btn)
			upgrade_buttons[tower_type][track] = btn


func _build_result_panel() -> void:
	result_panel = Panel.new()
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -150
	result_panel.offset_right = 150
	result_panel.offset_top = -60
	result_panel.offset_bottom = 60
	result_panel.hide()
	add_child(result_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	result_panel.add_child(vbox)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_label)

	play_again_button = Button.new()
	play_again_button.name = "PlayAgainButton"
	play_again_button.text = "Play Again"
	play_again_button.pressed.connect(_on_play_again_pressed)
	vbox.add_child(play_again_button)


# --- Signal handlers -----------------------------------------------------

func _on_upgrade_pressed(tower_type: String, track: String) -> void:
	# Authoritative check, not just the button's disabled flag. A disabled
	# Button ignores real clicks, but anything that emits `pressed` directly
	# (test harnesses, future keybinds, a stray signal connection) would sail
	# past it — and "no upgrades mid-round" is a rule, not a UI hint.
	if not _upgrades_allowed():
		return

	# try_upgrade() spends silver and increments atomically; on failure
	# (insufficient silver) nothing changes and no signal fires, so the
	# buttons simply stay as they were — correct, no separate error UI
	# needed for M1.
	TowerStats.try_upgrade(tower_type, track)


func _on_silver_changed(_n: int) -> void:
	_refresh_status()
	_refresh_upgrade_buttons() # affordability (button disabled state) depends on silver


func _on_gold_changed(_n: int) -> void:
	_refresh_status()


func _on_upgrade_changed(_tower_type: String, _track: String, _level: int) -> void:
	_refresh_upgrade_buttons()


func _on_life_lost(_remaining: int) -> void:
	_refresh_status()


## Upgrades are a between-rounds activity. Mirrors the same rule placement
## follows in map1.is_valid_placement().
func _upgrades_allowed() -> bool:
	return map.round_state == map.RoundState.PRE_ROUND


## Ticks the breather countdown. Polled rather than signalled: a Timer's
## time_left changes every frame and firing a signal per frame for one label
## would be worse than reading it.
func _process(_delta: float) -> void:
	if breather_panel == null or not breather_panel.visible:
		return
	var remaining: float = map.wave_manager.get_breather_remaining()
	breather_label.text = "Next wave in %ds" % ceili(remaining)


func _on_wave_started(wave_num: int, wave_total: int, _enemy_count: int) -> void:
	_wave_num = wave_num
	_wave_total = wave_total
	# Hide here as well as in the skip handler: a breather also ends by simply
	# timing out, and that path never touches the button.
	_hide_breather()
	_refresh_status()


func _on_breather_started(_seconds: float) -> void:
	if breather_panel != null:
		breather_panel.show()


func _on_all_waves_complete() -> void:
	_hide_breather()


func _on_skip_breather_pressed() -> void:
	map.wave_manager.skip_breather()
	# Hidden immediately rather than waiting for wave_started, following the
	# same rule Play Again learned: hide UI state in the handler that changes
	# it, don't assume a lifecycle signal covers every entry point.
	_hide_breather()


func _on_round_started() -> void:
	result_panel.hide()
	# Cleared here, then repopulated microseconds later by wave_started —
	# _start_round() emits round_started before wave_manager.begin().
	_wave_num = 0
	_wave_total = 0
	_refresh_status()
	_refresh_upgrade_buttons() # lock them for the duration of the round


func _on_round_ended(won: bool, gold_awarded: int, silver_earned: int) -> void:
	var headline := ""
	if won and gold_awarded > 0:
		headline = "Round Won!"
	elif won:
		headline = "Round Won (already cleared)"
	else:
		headline = "Round Lost"

	# Always report the haul, including on a loss — silver earned before dying
	# is kept, and saying so is the point of showing it.
	var earnings := "Earned: %d silver" % silver_earned
	if gold_awarded > 0:
		earnings += "  +  %d gold" % gold_awarded

	result_label.text = "%s\n%s" % [headline, earnings]
	result_panel.show()
	# A round can end DURING a breather — a loss on the escape that drains the
	# last life — which would otherwise leave the countdown ticking over the
	# result screen.
	_hide_breather()
	_refresh_status()
	_refresh_upgrade_buttons()


func _on_play_again_pressed() -> void:
	# Hide immediately rather than waiting for the next round_started — that
	# signal fires from _start_round() (the Start button), not from
	# start_new_round() (this button), so it wouldn't fire until the player
	# presses Start again, leaving the result panel stuck on screen.
	result_panel.hide()
	_hide_breather()
	_wave_num = 0
	_wave_total = 0
	map.start_new_round()
	# base_health.reset() doesn't emit life_lost, so nothing else would refresh
	# the lives label back to full here.
	_refresh_status()
	_refresh_upgrade_buttons() # back in PRE_ROUND, so unlock them


## Null-safe: the breather panel is not built when the HUD owns it.
func _hide_breather() -> void:
	if breather_panel != null:
		breather_panel.hide()


# --- Refresh ---------------------------------------------------------------

func _refresh_status() -> void:
	# The HUD owns these labels when suppressed, and they were never built.
	if _status_suppressed:
		return
	silver_label.text = "Silver: %d" % PlayerData.silver
	gold_label.text = "Gold: %d" % PlayerData.gold
	lives_label.text = "Lives: %d/%d" % [map.base_health.lives, map.base_health.max_lives]
	if _wave_total > 0:
		wave_label.text = "Wave %d/%d" % [_wave_num, _wave_total]
	else:
		wave_label.text = "Wave: -"
	controls_hint_label.modulate.a = 1.0 if _upgrades_allowed() else 0.4


func _refresh_upgrade_buttons() -> void:
	for tower_type in upgrade_buttons.keys():
		for track in upgrade_buttons[tower_type].keys():
			var btn: Button = upgrade_buttons[tower_type][track]
			var level := PlayerData.get_upgrade_level(tower_type, track)
			var cost := TowerStats.get_upgrade_cost(tower_type, track)
			btn.text = "%s Lv%d — %d silver" % [String(track).capitalize(), level, cost]
			# Locked mid-round: the loadout, stats included, is fixed once a
			# round starts. Towers only re-read TowerStats at round start.
			btn.disabled = not _upgrades_allowed() or cost > PlayerData.silver
