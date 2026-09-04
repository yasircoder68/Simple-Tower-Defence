extends Node

## Autoload. The single persistent save — everything that survives between rounds.
##
## Round-scoped state (lives, current wave, kills this round, ability cooldowns,
## placed tower instances) does NOT belong here. See CLAUDE.md's state boundary
## table before adding a field to this file.

signal silver_changed(new_amount: int)
signal gold_changed(new_amount: int)
signal upgrade_changed(tower_type: String, track: String, new_level: int)

const SAVE_PATH := "user://save.json"

## Tower types with an upgrade table. Extend when a new tower ships.
const TOWER_TYPES := ["archer", "wizard"]
const UPGRADE_TRACKS := ["range", "fire_rate", "damage"]

const DEFAULT_UNLOCKED_TOWERS := ["archer", "wizard"]
const DEFAULT_SLOT_COUNT := 4

## Silver: earned per kill, infinite supply, spent on upgrades.
var silver: int = 0

## Gold: earned once per level on first clear, finite supply, spent on unlocks.
var gold: int = 0

## tower_type -> { "range": int, "fire_rate": int, "damage": int }
## Values are upgrade LEVELS, not stat values — TowerStats resolves levels to numbers.
var upgrades: Dictionary = {}

var unlocked_towers: Array = DEFAULT_UNLOCKED_TOWERS.duplicate()

## Level ids already awarded gold. The gold-once ledger — award_level_gold() checks
## this before paying out, so replaying a level never grants gold twice.
var cleared_levels: Array = []

var slot_count: int = DEFAULT_SLOT_COUNT

## Set by every mutator, cleared by save_data(). Exists so a round's worth of
## kills costs ONE disk write instead of one per kill — earn_silver() runs
## hundreds of times a round, and saving inside it would recreate the per-kill
## disk I/O that was already a headline bug in this project once.
var _dirty: bool = false


func _ready() -> void:
	_ensure_upgrade_defaults()
	load_data()


## Autoloads get EXIT_TREE at shutdown, and CLOSE_REQUEST when the window's X
## is used. Both are covered so quitting never silently drops progress — this
## is the safety net, not the primary save path (see save_if_dirty callers).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_if_dirty()


func _ensure_upgrade_defaults() -> void:
	for tower_type in TOWER_TYPES:
		if not upgrades.has(tower_type):
			upgrades[tower_type] = {}
		for track in UPGRADE_TRACKS:
			if not upgrades[tower_type].has(track):
				upgrades[tower_type][track] = 0


# --- Silver -------------------------------------------------------------

func earn_silver(amount: int) -> void:
	if amount <= 0:
		return
	silver += amount
	_dirty = true
	silver_changed.emit(silver)


func spend_silver(amount: int) -> bool:
	if amount <= 0 or amount > silver:
		return false
	silver -= amount
	_dirty = true
	silver_changed.emit(silver)
	return true


# --- Gold -----------------------------------------------------------------

## Pays out gold for a level's first clear. Returns false (and pays nothing) if
## that level has already been cleared — this is the entire gold-once rule.
func award_level_gold(level_id: String, amount: int) -> bool:
	if level_id in cleared_levels:
		return false
	cleared_levels.append(level_id)
	_dirty = true
	if amount > 0:
		gold += amount
		gold_changed.emit(gold)
	return true


func spend_gold(amount: int) -> bool:
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	_dirty = true
	gold_changed.emit(gold)
	return true


func has_cleared(level_id: String) -> bool:
	return level_id in cleared_levels


# --- Upgrades ---------------------------------------------------------------

func get_upgrade_level(tower_type: String, track: String) -> int:
	if not upgrades.has(tower_type):
		return 0
	return upgrades[tower_type].get(track, 0)


## Raises one upgrade track by one level. Does not check or spend silver — the
## upgrade screen calls TowerStats for the cost, spends via spend_silver(), and
## only calls this on success.
func increment_upgrade(tower_type: String, track: String) -> int:
	if not upgrades.has(tower_type):
		upgrades[tower_type] = {}
	var new_level: int = upgrades[tower_type].get(track, 0) + 1
	upgrades[tower_type][track] = new_level
	_dirty = true
	upgrade_changed.emit(tower_type, track, new_level)
	return new_level


# --- Unlocks ----------------------------------------------------------------

func unlock_tower(tower_type: String) -> void:
	if not tower_type in unlocked_towers:
		unlocked_towers.append(tower_type)
		_dirty = true


func is_tower_unlocked(tower_type: String) -> bool:
	return tower_type in unlocked_towers


# --- Persistence --------------------------------------------------------

## Writes only when something actually changed. Callers should use this at
## checkpoints; save_data() is the unconditional version.
func save_if_dirty() -> void:
	if _dirty:
		save_data()


func save_data() -> void:
	var data := {
		"silver": silver,
		"gold": gold,
		"upgrades": upgrades,
		"unlocked_towers": unlocked_towers,
		"cleared_levels": cleared_levels,
		"slot_count": slot_count,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("PlayerData: could not open %s for write (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_dirty = false


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("PlayerData: could not open %s for read (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PlayerData: save file is corrupt (not a JSON object) — ignoring, starting fresh")
		return

	silver = int(parsed.get("silver", 0))
	gold = int(parsed.get("gold", 0))
	if typeof(parsed.get("upgrades", null)) == TYPE_DICTIONARY:
		upgrades = parsed["upgrades"]
	if typeof(parsed.get("unlocked_towers", null)) == TYPE_ARRAY:
		unlocked_towers = parsed["unlocked_towers"]
	if typeof(parsed.get("cleared_levels", null)) == TYPE_ARRAY:
		cleared_levels = parsed["cleared_levels"]
	slot_count = int(parsed.get("slot_count", DEFAULT_SLOT_COUNT))

	# Fresh saves, or saves from before a new tower type shipped, are missing
	# entries — backfill them rather than crash on a missing key later.
	_ensure_upgrade_defaults()


## Wipes progression back to a fresh save. Does not touch round-scoped state —
## nothing here needs to, since none is stored on this node.
func reset_progress() -> void:
	silver = 0
	gold = 0
	upgrades.clear()
	unlocked_towers = DEFAULT_UNLOCKED_TOWERS.duplicate()
	cleared_levels.clear()
	slot_count = DEFAULT_SLOT_COUNT
	_ensure_upgrade_defaults()
	save_data()
