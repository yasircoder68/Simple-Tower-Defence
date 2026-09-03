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

var result_panel: Panel
var result_label: Label
var play_again_button: Button

var upgrade_panel: Panel
# tower_type -> track -> Button, so a refresh can update labels in place
# instead of rebuilding the panel.
var upgrade_buttons: Dictionary = {}


func setup(map_ref: Node2D) -> void:
	map = map_ref

	PlayerData.silver_changed.connect(_on_silver_changed)
	PlayerData.gold_changed.connect(_on_gold_changed)
	PlayerData.upgrade_changed.connect(_on_upgrade_changed)
	map.base_health.life_lost.connect(_on_life_lost)
	map.round_started.connect(_on_round_started)
	map.round_ended.connect(_on_round_ended)

	_build_status_labels()
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


func _build_upgrade_panel() -> void:
	upgrade_panel = Panel.new()
	upgrade_panel.offset_left = 10
	upgrade_panel.offset_top = 180
	upgrade_panel.offset_right = 270
	upgrade_panel.offset_bottom = 420
	add_child(upgrade_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
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


func _on_round_started() -> void:
	result_panel.hide()
	_refresh_status()


func _on_round_ended(won: bool, gold_awarded: int) -> void:
	if won and gold_awarded > 0:
		result_label.text = "Round Won! +%d Gold" % gold_awarded
	elif won:
		result_label.text = "Round Won (already cleared — no gold)"
	else:
		result_label.text = "Round Lost"
	result_panel.show()
	_refresh_status()


func _on_play_again_pressed() -> void:
	# Hide immediately rather than waiting for the next round_started — that
	# signal fires from _start_round() (the Start button), not from
	# start_new_round() (this button), so it wouldn't fire until the player
	# presses Start again, leaving the result panel stuck on screen.
	result_panel.hide()
	map.start_new_round()
	# base_health.reset() doesn't emit life_lost, so nothing else would refresh
	# the lives label back to full here.
	_refresh_status()


# --- Refresh ---------------------------------------------------------------

func _refresh_status() -> void:
	silver_label.text = "Silver: %d" % PlayerData.silver
	gold_label.text = "Gold: %d" % PlayerData.gold
	lives_label.text = "Lives: %d/%d" % [map.base_health.lives, map.base_health.max_lives]


func _refresh_upgrade_buttons() -> void:
	for tower_type in upgrade_buttons.keys():
		for track in upgrade_buttons[tower_type].keys():
			var btn: Button = upgrade_buttons[tower_type][track]
			var level := PlayerData.get_upgrade_level(tower_type, track)
			var cost := TowerStats.get_upgrade_cost(tower_type, track)
			btn.text = "%s Lv%d — %d silver" % [String(track).capitalize(), level, cost]
			btn.disabled = cost > PlayerData.silver
