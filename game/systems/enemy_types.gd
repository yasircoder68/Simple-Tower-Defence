extends RefCounted

## The single source of truth for enemy numbers, resolved by Enemy at spawn.
##
## Mirrors how TowerStats owns tower numbers and archer/wizard pull from it: a
## `.tscn` carries identity and visuals, never stats. Do NOT add `@export var
## speed` back to an enemy script or bake numbers into a scene — the whole point
## is that adding the next enemy is a row here plus a scene, with no script.
##
## NUMBERS ONLY, AND NO preload() ANYWHERE IN THIS FILE. enemy.gd preloads this,
## so if this file preloaded the enemy scenes (which use enemy.gd) that would be
## a cyclic reference and GDScript would refuse it. The SCENE registry lives in
## wave_manager.gd instead — two dicts, deliberately in two different layers.
##
## Not an autoload: this holds no state and reads nothing. TowerStats is an
## autoload only because it consults PlayerData for upgrade levels.

## Defaults for every field, so a type entry only states what makes it unusual.
## A new enemy that is "a goblin but tougher" is two keys, not six.
const DEFAULTS := {
	"max_hp": 10,
	"speed": 100.0,
	"silver_reward": 2,
	## Lives lost when this enemy reaches the end. The channel that carries it
	## arrives in E-2; until then everything costs 1 regardless.
	"life_cost": 1,
	## Skips the push-apart entirely — an early-out, so such an enemy is
	## *cheaper* than a goblin, not more expensive. For A2's skeleton, which
	## slides through the horde rather than jostling with it.
	"ignore_separation": false,
	## Scales how hard this enemy is pushed BY others. It still pushes them
	## normally, because it still contributes its position to the grid — that
	## asymmetry is what lets a heavy part the crowd, and it costs one float
	## multiply on the receiving side with no change to the spatial grid.
	"separation_weight": 1.0,
}

const TYPES := {
	## Values carried over from the pre-registry game EXACTLY, so E-1 introduces
	## no balance change — the same discipline M1 used for tower stats.
	##
	## speed 100 is the value goblin.tscn overrode; the old script default was
	## 200 and implementation_plan.md §2.2's table also says 200. Both are wrong
	## for the shipped game. Carrying either would silently double enemy speed
	## and re-tune the whole difficulty curve.
	"goblin": {},
}


## Resolves a type id to its full stat set, defaults filled in.
## Unknown ids push_error and return the defaults, mirroring
## TowerStats.get_stats() rather than crashing a spawn mid-wave.
static func get_stats(enemy_id: String) -> Dictionary:
	if not TYPES.has(enemy_id):
		push_error("EnemyTypes: unknown enemy_id '%s' — check for a typo, or a new enemy missing a TYPES entry. Falling back to defaults." % enemy_id)
		return DEFAULTS.duplicate()

	var stats := DEFAULTS.duplicate()
	stats.merge(TYPES[enemy_id], true)
	return stats
