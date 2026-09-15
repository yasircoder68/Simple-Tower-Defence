extends Node
## Pooled sound effects. A5-2. Registered as the `Audio` autoload.
##
## THE RULE THIS FILE EXISTS TO ENFORCE (a5_plan, "THE RULE THAT GOVERNS BOTH AUDIO AND
## EFFECTS"): wave 5 kills 152 enemies in bursts and four towers fire ~32 shots a second.
## A fresh AudioStreamPlayer per event would mean voice exhaustion, clipping, and node churn
## of exactly the kind A3 spent a stage buying headroom against. So every sound gets:
##
##   1. a FIXED POOL of players, built once here - the pool size IS the hard cap;
##   2. a minimum RETRIGGER interval, below which a request is dropped outright;
##   3. +/- PITCH JITTER, so forty identical death squeaks do not fatigue the ear.
##
## Jitter is cosmetic, which puts it on the right side of CLAUDE.md's "cosmetic randomness
## is fine; damage randomness is not" line - and it draws from a PRIVATE RandomNumberGenerator,
## so a sound never advances the global RNG that tower targeting (randi()) reads.
##
## MISSING FILES ARE A SILENT NO-OP, by spec, so sounds can land one at a time. A misspelled
## sound NAME is not a missing file - it is a bug at the call site, and it push_errors.
##
## PAUSE - MEASURED, not assumed (2026-09-10). This node inherits the pause mode like
## everything else. A gameplay voice that is PLAYING when a pause begins freezes on the spot
## and resumes on unpause: one sat at 0.003s through a whole pause while a UI voice beside it
## advanced to 0.525s. Two things that are easy to get wrong:
##   - Godot pauses a player's stream on the pause NOTIFICATION, i.e. when the pause BEGINS.
##     A pausable voice STARTED during a pause plays anyway. The first version of that test
##     started both voices after pausing, saw both advance, and proved nothing. Harmless
##     here: no gameplay code can request a sound while the tree is paused.
##   - Sounds flagged `ui` get PROCESS_MODE_ALWAYS, so a click already sounding when Escape
##     lands finishes cleanly instead of freezing and replaying its tail on resume. Those
##     players are the only always-on nodes this file adds.
##
## TIME. The retrigger clock is delta-accumulated in _process(), never Time.get_ticks_msec()
## (CLAUDE.md's pause rule). It freezes during a pause, which is harmless: nothing on the
## gameplay side can request a sound while paused, and ui sounds have no retrigger gap.

const SFX_DIR := "res://assets/audio/sfx/"
const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"

## voices: fixed pool size, the hard cap. gap: minimum seconds between accepted plays.
## jitter: +/- pitch fraction. ui: plays while the tree is paused.
## Pools follow firing rates: archer_shot is 130 ms at up to ~32/sec (about four overlapping,
## so 4 voices only steals at full four-tower rate); enemy_death is 180 ms in bursts, capped at 6.
const SOUNDS := {
	"ui_click": {"voices": 2, "gap": 0.0, "jitter": 0.0, "ui": true},
	"upgrade_buy": {"voices": 2, "gap": 0.05, "jitter": 0.03, "ui": true},
	"tower_place": {"voices": 2, "gap": 0.05, "jitter": 0.06},
	"archer_shot": {"voices": 4, "gap": 0.05, "jitter": 0.10},
	"wizard_cast": {"voices": 3, "gap": 0.08, "jitter": 0.08},
	"fire_explode": {"voices": 3, "gap": 0.06, "jitter": 0.10},
	"enemy_death": {"voices": 6, "gap": 0.03, "jitter": 0.12},
	"life_lost": {"voices": 2, "gap": 0.25, "jitter": 0.0},
	"wave_start": {"voices": 1, "gap": 1.0, "jitter": 0.0},
	"round_won": {"voices": 1, "gap": 1.0, "jitter": 0.0},
	"round_lost": {"voices": 1, "gap": 1.0, "jitter": 0.0},
	"boulder_cast": {"voices": 1, "gap": 0.2, "jitter": 0.05},
	"boulder_impact": {"voices": 1, "gap": 0.2, "jitter": 0.05},
	"rain_of_arrows": {"voices": 1, "gap": 0.5, "jitter": 0.0},
}

## Per-sound counters: played / throttled (dropped by the retrigger gap) / stolen (pool full,
## a busy voice restarted). Int increments on events only, never per frame. They exist so the
## cap is VERIFIED in a real wave rather than assumed - read them with runtime_get_script_vars
## on /root/Audio.
var stats: Dictionary = {}

var _pools: Dictionary = {}  # name -> Array of AudioStreamPlayer; empty = file not supplied
var _cursor: Dictionary = {}  # name -> next voice to steal, round-robin
var _last_play: Dictionary = {}  # name -> _clock at the last accepted play
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	# Settings applied its volumes in its own _ready(), which runs BEFORE this one (autoloads
	# ready in registration order). If the layout file was missing, that pass found no SFX
	# bus; re-apply now that the buses are guaranteed to exist.
	if has_node("/root/Settings"):
		get_node("/root/Settings").apply_audio()
	_rng.seed = 0xA5A2
	for sound_name in SOUNDS:
		_build_pool(sound_name)
	# Every button in the game clicks, procedurally created ones included, with no
	# per-screen wiring to forget. The cost is one cast per node ADDED to the tree -
	# an event, not a per-frame cost.
	get_tree().node_added.connect(_on_node_added)
	# node_added alone is NOT enough, and testing caught it: the BOOT scene's nodes enter
	# the tree before any autoload's _ready() runs, so they are never reported. The level's
	# StartButton stayed silent while a shop button built later in _ready() clicked - and in
	# real play the boot scene is the main menu, so Begin/Upgrades/Settings/Quit would all
	# have been mute until the menu was reloaded. One deferred sweep hooks whatever already
	# exists; the is_connected() guard in _on_node_added() makes the overlap harmless.
	_hook_buttons_in.call_deferred(get_tree().root)


func _process(delta: float) -> void:
	_clock += delta


## Fire-and-forget. `pitch` multiplies the jitter, so a caller can reuse one file as a
## variant: tower removal is tower_place at 0.78.
func play(sound_name: String, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound_name):
		push_error("Audio: no sound named '%s' - a typo at the call site, not a missing file." % sound_name)
		return
	var pool: Array = _pools[sound_name]
	if pool.is_empty():
		return  # file not supplied yet: silent by design
	var cfg: Dictionary = SOUNDS[sound_name]
	var counters: Dictionary = stats[sound_name]
	if _clock - float(_last_play[sound_name]) < float(cfg["gap"]):
		counters["throttled"] += 1
		return
	_last_play[sound_name] = _clock

	var player: AudioStreamPlayer = null
	for p in pool:
		if not p.playing:
			player = p
			break
	if player == null:
		var i: int = _cursor[sound_name]
		player = pool[i]
		_cursor[sound_name] = (i + 1) % pool.size()
		counters["stolen"] += 1

	var jitter: float = cfg["jitter"]
	player.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	player.play()
	counters["played"] += 1


func _build_pool(sound_name: String) -> void:
	var cfg: Dictionary = SOUNDS[sound_name]
	stats[sound_name] = {"played": 0, "throttled": 0, "stolen": 0}
	_cursor[sound_name] = 0
	_last_play[sound_name] = -1.0e9
	_pools[sound_name] = []
	var path := SFX_DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	for i in int(cfg["voices"]):
		var p := AudioStreamPlayer.new()
		p.name = "%s_%d" % [sound_name, i]
		p.stream = stream
		p.bus = BUS_SFX
		if cfg.get("ui", false):
			p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pools[sound_name].append(p)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	# default_bus_layout.tres normally provides this bus. Recreated here so a missing or
	# clobbered layout - the editor rewrites that file whenever its Audio panel is edited -
	# degrades to correct routing, instead of every player silently falling back to Master.
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


## One pass over a subtree through the same per-node hook. Called deferred from _ready(), so
## it runs after every node that exists at boot has entered the tree.
func _hook_buttons_in(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_buttons_in(child)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play("ui_click")
