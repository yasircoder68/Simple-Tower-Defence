extends Node
## User preferences. A5-3.
##
## A THIRD STATE CATEGORY, and deliberately NOT PlayerData. CLAUDE.md's state
## boundary splits persistent PROGRESS (silver, upgrades, the gold-once ledger)
## from ROUND-SCOPED state (lives, waves, placed towers). Preferences are
## neither. Putting them in PlayerData would mean reset_progress() wipes the
## player's resolution along with their save, and would drag them through the
## save format for no reason. Separate file, separate lifetime.
##
## APPLIED BEFORE ANYTHING IS DRAWN. This is an autoload, so _ready() runs
## before the boot scene (the main menu) is instantiated — which is exactly the
## "applied on boot, before the main menu is shown" requirement, for free.
##
## AUDIO IS NOT HERE YET, ON PURPOSE. A5-2 owns the bus layout and the pooled
## player, and no audio files have been supplied. When it lands, add a
## `[audio]` section with linear 0-1 values and convert with linear_to_db() at
## APPLY time. **Never store dB** — it is a display-hostile log scale, and a
## slider that stores dB cannot represent silence.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_DISPLAY := "display"

## Offered in the windowed resolution dropdown. All 16:9, matching the project's
## 1280x720 base — with stretch/mode = canvas_items and aspect = keep, picking
## one scales the whole game rather than revealing more world, so any 16:9 size
## is safe and none of them changes what the player can see.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

## Emitted after any change is applied, so open screens can re-sync without
## polling. Same signal-driven discipline as every other manager here.
signal changed

var fullscreen: bool = false
var vsync: bool = true
var resolution_index: int = 0


func _ready() -> void:
	load_settings()
	apply()


# --- Persistence ------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	# A missing file is the normal first-run case, not an error: the defaults
	# above are already a valid configuration.
	if cfg.load(SETTINGS_PATH) != OK:
		return
	fullscreen = bool(cfg.get_value(SECTION_DISPLAY, "fullscreen", fullscreen))
	vsync = bool(cfg.get_value(SECTION_DISPLAY, "vsync", vsync))
	resolution_index = clampi(
		int(cfg.get_value(SECTION_DISPLAY, "resolution_index", resolution_index)),
		0, RESOLUTIONS.size() - 1)


## Written immediately rather than through a dirty flag. The argument is the one
## CLAUDE.md makes for TowerStats.try_upgrade(): this is a deliberate, rare user
## action, not something that fires hundreds of times a round like earn_silver().
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_DISPLAY, "fullscreen", fullscreen)
	cfg.set_value(SECTION_DISPLAY, "vsync", vsync)
	cfg.set_value(SECTION_DISPLAY, "resolution_index", resolution_index)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("Settings: could not write %s (error %d)" % [SETTINGS_PATH, err])


# --- Apply ------------------------------------------------------------------

func apply() -> void:
	apply_vsync()
	_apply_window()


## Split out because systems/bench.gd force-disables vsync for a measurement run
## and must put it back afterwards. Without this, one bench run would silently
## override the player's choice for the rest of the session and never restore it.
func apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = RESOLUTIONS[resolution_index]
	DisplayServer.window_set_size(size)
	# Re-centre, or growing the window leaves it hanging off the screen edge
	# with its title bar out of reach.
	var screen: int = DisplayServer.window_get_current_screen()
	DisplayServer.window_set_position(
		DisplayServer.screen_get_position(screen)
		+ (DisplayServer.screen_get_size(screen) - size) / 2)


# --- Mutators ---------------------------------------------------------------

func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	_apply_window()
	save_settings()
	changed.emit()


func set_vsync(value: bool) -> void:
	if value == vsync:
		return
	vsync = value
	apply_vsync()
	save_settings()
	changed.emit()


func set_resolution_index(index: int) -> void:
	var clamped: int = clampi(index, 0, RESOLUTIONS.size() - 1)
	if clamped == resolution_index:
		return
	resolution_index = clamped
	# No-op while fullscreen, which is correct: the choice is remembered and
	# takes effect the moment the player leaves fullscreen.
	if not fullscreen:
		_apply_window()
	save_settings()
	changed.emit()


func resolution_name(index: int) -> String:
	var r: Vector2i = RESOLUTIONS[index]
	return "%d x %d" % [r.x, r.y]
