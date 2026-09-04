extends Node

## Autoload. The single source of truth for tower numbers.
##
## Resolves base stats + permanent upgrade level into final range / attack
## interval / damage, queried by a tower AT SPAWN via get_stats(). New tower
## scripts must not @export their own stats and tower .tscn files must not
## bake stat overrides — everything comes from here so an upgrade bought once
## applies to every tower of that type, in every level, immediately.
##
## Also owns the silver cost curve for the upgrade screen (§3.1 of
## implementation_plan.md) — tune costs here, nowhere else.

## range: detection/target-acquisition radius, world px.
## attack_interval: seconds between shots — LOWER is faster. This is the
## upgrade track the player calls "fire-rate"; see UPGRADE_BONUS below for
## why the sign is inverted.
## damage: flat damage per hit (wizard's is per-target before AoE falloff;
## fire.gd currently applies no falloff, full damage to everything in radius).
const BASE_STATS := {
	"archer": {"range": 200.0, "attack_interval": 0.5, "damage": 10},
	"wizard": {"range": 200.0, "attack_interval": 1.0, "damage": 3},
}

## Added per upgrade level. attack_interval's bonus is NEGATIVE — leveling
## the "fire_rate" track makes the tower fire faster, i.e. lowers the
## interval — and is floored by MIN_ATTACK_INTERVAL so it can never reach
## zero (an interval of 0 would fire every physics frame).
const UPGRADE_BONUS := {
	"archer": {"range": 15.0, "attack_interval": -0.03, "damage": 2},
	"wizard": {"range": 15.0, "attack_interval": -0.05, "damage": 1},
}

const MIN_ATTACK_INTERVAL := 0.1

## Silver cost curve: cost to raise a track from its current level to the
## next is BASE_UPGRADE_COST * COST_GROWTH^level. Silver is infinite, so this
## curve is the entire difficulty knob for the upgrade economy — see the
## Economy section of CLAUDE.md before changing these.
const BASE_UPGRADE_COST := 10
const COST_GROWTH := 1.35


## Resolves tower_type's current stats from PlayerData's upgrade levels.
## Returns {"range": float, "attack_interval": float, "damage": int}.
func get_stats(tower_type: String) -> Dictionary:
	if not BASE_STATS.has(tower_type):
		push_error("TowerStats: unknown tower_type '%s' — check for a typo, or a new tower missing a BASE_STATS entry" % tower_type)
		return {"range": 0.0, "attack_interval": 1.0, "damage": 0}

	var base: Dictionary = BASE_STATS[tower_type]
	var bonus: Dictionary = UPGRADE_BONUS.get(tower_type, {})

	var range_level := PlayerData.get_upgrade_level(tower_type, "range")
	var rate_level := PlayerData.get_upgrade_level(tower_type, "fire_rate")
	var damage_level := PlayerData.get_upgrade_level(tower_type, "damage")

	var final_range: float = base["range"] + bonus.get("range", 0.0) * range_level
	var final_interval: float = base["attack_interval"] + bonus.get("attack_interval", 0.0) * rate_level
	var final_damage: int = base["damage"] + bonus.get("damage", 0) * damage_level

	return {
		"range": final_range,
		"attack_interval": max(final_interval, MIN_ATTACK_INTERVAL),
		"damage": final_damage,
	}


## Silver cost to raise tower_type's track by one level from where it is now.
func get_upgrade_cost(tower_type: String, track: String) -> int:
	var level := PlayerData.get_upgrade_level(tower_type, track)
	return int(round(BASE_UPGRADE_COST * pow(COST_GROWTH, level)))


## Attempts to buy one level of tower_type's track: spends silver via
## PlayerData and only increments the upgrade level on success. Returns
## false with no state change if silver is insufficient. This is the only
## function that should ever raise an upgrade level — never call
## PlayerData.increment_upgrade() directly from UI code.
func try_upgrade(tower_type: String, track: String) -> bool:
	var cost := get_upgrade_cost(tower_type, track)
	if not PlayerData.spend_silver(cost):
		return false
	PlayerData.increment_upgrade(tower_type, track)
	# Deliberate purchase — flush it now rather than risk losing it to a crash
	# before the next round-end checkpoint. Low frequency, so the write is cheap.
	PlayerData.save_if_dirty()
	return true
