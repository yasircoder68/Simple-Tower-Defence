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
	## How big a target this enemy is, in world px, for projectile hit tests.
	## Carries the geometry that used to live in each scene's CollisionShape2D,
	## deleted by A3's S-1 when enemies stopped being Area2D. The values are the
	## half-extents of those boxes, so the hit test is unchanged rather than
	## re-tuned: goblin's 64x64 box at scale 0.5 was 32x32, hence 16.
	##
	## A projectile adds its OWN radius to this - area-vs-area collision summed
	## both, and forgetting that made every tower miss (S-1's first attempt lost
	## a round that had comfortably won before).
	"hit_radius": 16.0,
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

	## The rusher. Frail and fast, and it IGNORES SEPARATION — which is what
	## makes it slide through a goblin crowd instead of queueing behind it, so
	## it reaches the choke first and punishes slow-firing towers.
	##
	## ignore_separation is an early-out, so a skeleton is CHEAPER per frame
	## than a goblin, not dearer. Worth knowing before assuming a rusher wave
	## costs more to simulate.
	"skeleton": {
		"max_hp": 6,
		"speed": 280.0,
		"ignore_separation": true,
		## Box was 24x35 (scale 0.38 x 0.55); the mean half-extent, since one
		## radius cannot express a rectangle.
		"hit_radius": 15.0,
	},

	## The heavy that must not be allowed through.
	##
	## 80 HP is eight archer shots at base damage 10, which is what finally makes
	## the archer's DAMAGE upgrade track do something — see CLAUDE.md Known
	## issue 1. Against a 10 HP goblin, +2 damage changes nothing; against an
	## ogre it removes a whole shot.
	##
	## separation_weight 0.15 means the crowd barely shifts it, while it still
	## pushes others normally (it contributes its position to the grid like
	## anything else). That asymmetry is what lets it plough a lane through the
	## goblins — and it costs one float multiply, with no change to the spatial
	## grid at all.
	##
	## life_cost 3 is the whole point of E-2's channel. Three leaked ogres is
	## nine of twenty lives.
	"ogre": {
		"max_hp": 80,
		"silver_reward": 12,
		"life_cost": 3,
		"separation_weight": 0.15,
		## Box was 70x70 (scale 1.1). More than twice a goblin's, which is why a
		## single shared hit radius could not stand in for all three.
		"hit_radius": 35.0,
	},
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
