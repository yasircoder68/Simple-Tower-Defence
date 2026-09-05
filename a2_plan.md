# A2 — "Enemy Variety" — Implementation Work Order

**Status: in progress — step 0 (R-0) shipped and verified. Steps 1–11 remain.**

Progress against the Sequencing table below:

| Step | State |
|---|---|
| 0 · R-0 harden the contract | ✅ **done and verified** — see *R-0: what actually shipped* |
| 1–2 · renames | not started |
| 3–7 · enemy track | not started |
| 8–10 · ability track | not started |
| 11 · tune + docs | not started |

---

## R-0: what actually shipped

Three changes, all under the old names, all additive:

1. **Group membership moved from scene data into code.** `zombie.tscn` no longer declares
   `groups=["zombie"]`; `Enemy._ready()` calls `add_to_group(GROUP)`. Nine string literals across
   six files collapsed to `Enemy.GROUP` — a typo in the const *name* is now a parse error rather
   than a silent miss.
2. **Two independent `has_method()` guards → one cached probe.** `_die()` and `_escape()` can no
   longer disagree about whether the map is scoring; a partial contract `push_error`s naming
   exactly what is missing.
3. **Map-side self-check** in `level_controller._ready()`, plus loud fallbacks in `boulder.gd` and
   `fire.gd` when the splash query drifts — discriminated by the `"map"` group, which the testbed
   deliberately isn't in, so the testbed still falls back silently and correctly.

**`class_name Enemy` was brought forward from E-1.** It is what lets six consumer files say
`Enemy.GROUP`, which is the entire point of R-0. No cycle risk: enemies duck-type the map through
`map` and never name a controller class. The class now lives in a file still called `zombie.gd` —
the CLASS is already the shared base, the FILE name is what R-2 fixes.

**The group value stays `"zombie"` until R-1.** R-0 must change nothing observable so R-1's diff
is meaningful. Once every consumer reads the const, the value is a private detail.

### The net was verified by breaking it

Per this plan's own rule — a net you haven't fallen into is not a net. `on_zombie_escaped` was
deliberately renamed to `on_zombie_escaped_TYPO`; **both** guards fired naming the exact missing
member (the map-side check at startup, the enemy-side probe per spawn). Reverted, re-ran, clean.

### A verification gap this exposed, affecting A1's record

Finding those errors required looking somewhere this project had not been looking:
**runtime `push_error` goes to `debugger_get_log`, NOT `editor_get_console`.** On Godot 4.5+ the
latter shows the *editor's* console — it catches parse and load errors (it did surface W-5's), but
not a running game's runtime errors.

Every "zero errors" claim made during A1 was read from the wrong stream. Re-verified since: a full
408-enemy round on the current build, with two boulders impacting one cluster in a single frame,
produces zero errors in the game log. **A1's conclusions stand — but they stood on weaker evidence
than was stated at the time.**

---

## Context

A1 shipped: five escalating waves, a boulder ability, 408 enemies at 60 FPS. But **there is
exactly one enemy type**, so a wave is the same fight bigger. A2 is what makes the horde
*interesting* — three enemies with genuinely different roles, plus the three cooldown abilities
deferred out of A1.

It also pays off two debts A1 deliberately left open:

- **The archer's damage upgrade track is inert** (CLAUDE.md Known issue 1). Archer damage is
  exactly 10 and goblin HP is exactly 10, so buying damage does nothing. A1 measured that raising
  goblin HP is a binary cliff that breaks the difficulty curve. The Ogre at 80 HP fixes it for
  free — 8 archer hits, so upgrades bite immediately and measurably.
- **Divine Smite had no target worth a 60s cooldown** — the reason it moved out of A1. The Ogre
  gives it one.

**Scope:** two renames, an enemy foundation, three enemy types, wave composition, a life-cost
channel, three abilities. No new autoloads, no save-format change, nothing persistent added.
`PlayerData` and `TowerStats` untouched.

**Decisions taken with the user:** Troll deferred; both renames done, machinery first; A2 ships
as one itch release.

Read [CLAUDE.md](CLAUDE.md) first — *Separation (the perf-critical path)*, *Waves (A1)*,
*Abilities (A1)*, *Known issues* 1 and 1b, and *Gotchas*.

---

## The central risk: a rename that fails silently

This is not an ordinary rename. Six couplings are **string literals**, so renaming a definition
without its literal produces no error at all:

| Site | Literal | Failure if missed |
|---|---|---|
| `zombie.gd:28` | `if "zombie_grid" in map` | separation silently disabled |
| `zombie.gd:124` | `has_method("on_zombie_killed")` | **kills stop awarding silver** |
| `zombie.gd:132` | `has_method("on_zombie_escaped")` | **escapes stop costing lives** |
| `boulder.gd:63`, `fire.gd:52` | `has_method("get_zombies_in_radius")` | AoE falls back to a full scene scan |
| `zombie.tscn:9` | `groups=["zombie"]` | **total blackout** — nothing targets, indexes or damages |

The last is the worst and the least obvious: **`zombie.gd` never calls `add_to_group()`.** Group
membership exists only as scene data, consumed by 9 call sites across 6 files. A2 adds two more
`.tscn` files, each able to forget the group independently.

**Two aggravating factors.** The testbed cannot catch any of this — `clean_area.gd` deliberately
lacks every one of these members, so it works whether the rename finished or not; it is a
silent-failure zone, not a canary. And the current design fails *partially*: kills work while
lives are silently free.

**So step 0 is not the rename. It is building the net.**

---

## Two renames, not one

| | Rename A — machinery | Rename B — entity |
|---|---|---|
| `zombie_grid` → `enemy_grid`, `zombies_to_resolve` → `enemies_to_resolve`, `on_zombie_killed` → `on_enemy_killed`, `on_zombie_escaped` → `on_enemy_escaped`, `get_zombies_in_radius` → `get_enemies_in_radius`, `_clear_all_zombies` → `_clear_all_enemies`, group `"zombie"` → `"enemy"` | `entities/enemies/zombie/` → `goblin/`, files, node name `Zombie` → `Goblin`, scene path strings, `clean_area`'s exports |

The machinery is consumed by archer, wizard, arrow, fire, boulder and level_controller — every one
means *any enemy*. `goblin_grid` would be wrong within one commit.

**The codebase already half-agrees.** A1 named its hook `on_enemy_resolved()`, its signal carries
`enemy_count`, and `project.godot:63` names collision layer 1 `"enemies"`. A1 reached for the
neutral word every time it wrote something new. This finishes a seam already drawn.

---

## Enemy foundation

**One shared script with `class_name Enemy`, numbers in a const registry, per-type `.tscn` for
visuals only, event-level virtual hooks — and no per-frame virtual hooks, ever.**

```
Enemy (class_name, extends Area2D)      ← the ENTIRE movement implementation
  ├─ const GROUP, const SEPARATION_RADIUS   (single-sourced; level_controller reads it)
  ├─ @export var enemy_id: String           (identity, set per-.tscn)
  ├─ resolved at _ready() from EnemyTypes:
  │     max_hp, speed, silver_reward, life_cost,
  │     ignore_separation, separation_weight
  ├─ _physics_process / _separation / _move_with_wall_slide / take_damage
  │     — flags checked INLINE, no dispatch
  └─ virtual hooks, empty in base:  _on_spawn()  _on_damaged(amount)  _on_death()
```

**Why no overridable `_separation()`.** CLAUDE.md's recommended next perf attempt is to move the
whole horde into a single manager loop on `level_controller`. Type differences that survive that
rewrite are **data the loop can branch on** (`ignore_separation`, `separation_weight`), not methods
it must dispatch. `if ignore_separation: return Vector2.ZERO` ports across; a subclass override
has to be untangled.

**Goblin, Skeleton and Ogre need no script of their own** — three `.tscn` files differing only in
sprite modulate, scale and `enemy_id`. That *is* "adding the next one is cheap". Only a type with
genuine behaviour (the Troll's enrage) gets a subclass.

This mirrors the house pattern: `archer.gd` has `const TOWER_TYPE` and pulls from
`TowerStats.get_stats()`. Registry-as-const-dict is already used twice (`TowerStats.BASE_STATS`,
`AbilityManager.ABILITIES`) — use it a third time rather than introducing Resource files.

**Circular-preload hazard — resolve before writing a line.** If `enemy_types.gd` preloads
`goblin.tscn`, which uses `enemy.gd`, which preloads `enemy_types.gd`, GDScript refuses it.
**Split by layer:** `systems/enemy_types.gd` holds *numbers only, no preloads*; the scene preloads
live in `wave_manager.gd`, where `ZOMBIE_SCENE` already is. Add a startup check that the two key
sets match.

### Stat table

| | max_hp | speed | silver | life_cost | ignore_sep | sep_weight |
|---|---|---|---|---|---|---|
| Goblin | 10 | **100** | 2 | 1 | false | 1.0 |
| Skeleton | 6 | 280 | 2 | 1 | **true** | 1.0 |
| Ogre | 80 | 100 | 12 | **3** | false | **0.15** |

**Trap — goblin speed is 100, not 200.** `zombie.gd:12` declares `@export var speed = 200.0` but
`zombie.tscn:15` overrides it to `100.0`. The shipped game runs at 100; implementation_plan §2.2's
table says 200. Carry **100** into the registry or you silently double enemy speed and rebalance
everything. Same discipline M1 used ("base stats set to match the pre-refactor game exactly").
Then **delete the `@export`**, so nobody thinks the inspector matters — same rule as tower stats.

---

## Carrying per-type data through uniform systems

### Life cost — cheap, because half of it already exists

`base_health.gd:23` already reads `lose_life(amount: int = 1)`. Only the call chain lacks a
channel: `Enemy._escape()` → `map.on_enemy_escaped(life_cost)` →
`base_health.lose_life(life_cost)`. Default argument keeps the testbed working and makes the
commit purely additive.

> **Guard this in a code comment:** `enemies_to_resolve` must still decrement by **exactly 1**.
> One spawned unit is one resolution unit; life cost is a damage number, not a count. Decrementing
> by 3 for an ogre desyncs `wave_remaining` and ends the round early — the "victory after wave 1"
> class of bug, re-entering through a new door.

The loss short-circuit already handles it: `lives = max(lives - 3, 0)` then `lives <= 0`.

**Expect a tuning consequence:** A1 measured four lives lost across a 408-enemy round. Three
leaked ogres is nine. The 20-life budget stops being generous — which is the point — so
`difficulty_scale = 1.6` must be re-measured, not inherited.

### Wave composition

`WAVE_TABLE` rows gain a `groups` array; `count` stops being authored and becomes **derived**:

```gdscript
{"groups": [{"type": "goblin", "count": 45}, {"type": "skeleton", "count": 8}],
 "spawn_interval": 0.09}
```

**Explicit groups, not weighted random.** This project verifies by measurement — randomised
composition makes every measurement noisy and every regression unreproducible. And "a heavy that
must not be allowed through" means *exactly one ogre in wave 3*, which weights cannot express.

1. Resolve group counts once in `_build_waves()` and derive `count` from the same numbers.
   **Assert `count == plan.size()`** — a one-off disagreement either hangs the round forever or
   resolves it early.
2. Decide `maxi(1, …)` per group deliberately: it means a 1-ogre group can never be scaled away.
   Probably right; don't inherit it by accident.
3. `_start_wave()` builds a flat `Array[String]` spawn plan of length `count`; `_spawn_one()`
   indexes it by `_spawned_this_wave`. Timer, phases, counter split and breather pre-reservation
   are all untouched.

**Deterministic interleave, not shuffle** — distribute each group evenly so the ogre isn't stapled
to the end, and so two runs of a wave are identical. Skeleton "packs of 4" falls out free: emit
them in runs in the plan; the existing 0.04–0.15s interval delivers them near-simultaneously.
**No change to the spawn timer.**

### The separation grid — leave it alone

`SEPARATION_RADIUS = 32.0` is simultaneously four things: grid cell size, query span divisor, the
enemy's own cell-key divisor, and force falloff distance. A per-type radius above 32 silently
misses neighbours, because the enemy scans a fixed 3×3 block. Fixing that means a variable-size
scan **in the hottest loop in the game** — the one still at 4 FPS at 600 enemies after six failed
optimisation attempts. The grid also stores bare `Vector2` deliberately; tagging entries re-opens
the measured lesson that Variant-shaped work in that loop cost 15×. And **A3 rewrites this layer
entirely** — per-type grid work done now is thrown away.

The gameplay need is ~80% met by two data flags needing no grid change:

- **`ignore_separation`** (skeleton) — an early-out; *faster* than a goblin.
- **`separation_weight`** — multiply the *result* of `_separation()` before adding it to the flow
  direction. An ogre at 0.15 barely gets pushed, so the crowd flows around it while it ploughs
  through. One float multiply, receiving side only. It still contributes its position to the grid,
  so it still pushes others — exactly the asymmetry wanted, for free.

Take one free hygiene fix: make `Enemy.SEPARATION_RADIUS` the single definition and have
`level_controller` reference it, retiring the duplicated-const-that-must-stay-equal.

### Tower targeting — a deliberate non-change

`zombies[randi() % zombies.size()]` gives an ogre no priority. **Do not add targeting priority.**
The design answer to "a heavy that must not be allowed through" is Divine Smite — the player's
ability, not the towers' AI. Priority targeting would quietly nullify the ogre's threat, undoing
the enemy just built. Note that `archer.gd:48-56` ≡ `wizard.gd:47-56`; extract nothing.

---

## The three abilities

**A1's registry generalises well.** Per-id cooldowns (90s and 3s already cannot collide),
selection, number keys, the bar (`for ability_id in manager.ABILITIES` — four slots free), the
`_unhandled_input` routing, and the "payload owns its own numbers" contract all carry unchanged.
Adding an ability is one dict entry plus one payload folder, as B-4 promised.

**Rain of Arrows** (30s, area over time) — fits perfectly, **zero system change**. Duration is
internal to the payload: tick `map.get_enemies_in_radius()` instead of querying once. **Build this
first — it is the commit that proves the registry works.** Requires `is_instance_valid()` on
**every tick**, not just once: a 3-second barrage re-reads a grid rebuilt 180 times with enemies
freed out from under it.

**Divine Smite** (60s, single target) — fits, with one honest compromise. `cast(id, world_pos)`
gives a position, not a target. Give it a small acquisition radius (~40) and have the payload pick
the **highest-HP enemy** inside it. Eight lines, entirely in the payload; the small circle marker
is an honest preview of the acquisition area. **A whiff consumes the cooldown** — the boulder
already does, and refusing would force the manager to know about targets.

**Dragon Fire** (90s, strafing run) — the one place the system strains.

- *Direction:* **fix the axis in A2** — left→right through the clicked Y. Drag-to-aim needs a
  second aim point and marker rotation; out of scope.
- *Positioning:* costs nothing. The payload reads its own `global_position` in `_ready()` as the
  aim point and repositions off-screen — the boulder already establishes "root parks at the aim
  point, sprite travels"; the dragon inverts which part moves. **No manager change.**
- *The marker:* **the one real system change.** `aim_marker.gd` hardcodes `draw_circle`. Read an
  optional `SHAPE` const off the payload script exactly as `RADIUS` already is, default
  `"circle"`, and `match` in `_draw()`. Add `"strip"`. ~15 lines, one file. Shape must obey the
  same rule as radius: the preview cannot be able to drift from the real blast.

### A new bug class A2 introduces

**Payloads can now outlive the round.** The boulder lives 0.5s; a 3-second barrage and a ~2-second
strafing run can be alive when `_end_round(false)` force-clears the board. `is_instance_valid()`
prevents the crash but not the wrongness.

> **Shared rule, established now while there are three payloads and not seven:** any multi-tick
> payload checks `map.round_state == IN_ROUND` at the top of each tick and frees itself otherwise.

### Two tuning consequences to decide, not inherit

- **A 90s cooldown in a ~2.5-minute round is one cast, maybe two.** Rain lands ~4×, Smite ~2×,
  Dragon ~1×. That is a real statement — these are specials, not verbs — and it's correct, but
  know it going in.
- **`reset()` zeroes every cooldown**, so all four are available at wave 1, when they're least
  needed and most wasted. One-line lever:
  `cooldowns[id] = entry.get("initial_cooldown", 0.0)` in `_reset_cooldowns()`.
- Minor UI: a 90s veil drains ~0.7 px/s and reads as static. Add a numeric countdown to a slot
  when remaining > 10s.

---

## Sequencing

Twelve commits. **Every one leaves the game launchable and playable.**

| # | Commit | Files | Done when |
|---|---|---|---|
| 0 | ✅ **R-0 · Harden the contract.** Group joined in code via one const; guards → one cached probe + partial-contract `push_error`; map-side self-check. **No rename.** | `zombie.gd`, `zombie.tscn`, `boulder.gd`, `fire.gd`, `arrow.gd`, `archer.gd`, `wizard.gd`, `level_controller.gd` | ✅ Plays identically; net verified by deliberately breaking it. Self-check is **unconditional**, not gated on `debug_logging` as originally specced — a drifted contract should be loud in every build, and it costs one `has_method()` loop at startup. |
| 1 | **R-1 · Machinery rename** → `enemy_*`, group `"enemy"`. Mechanical. | same 12 files | Grep for machinery names returns 0. Full round **on level_01, not the testbed**, specifically exercising the **escape** path (no towers, watch lives drain). |
| 2 | **R-2 · Entity rename** → goblin. Folder, files, node name, path strings, testbed exports. | `entities/enemies/goblin/*`, `wave_manager.gd`, `clean_area.gd/.tscn` | `grep -ri zombie game/ --exclude-dir=addons` returns 0. Round identical; testbed launches. |
| 3 | **E-1 · Enemy base + registry, goblin only.** `enemy_types.gd`, stats resolved at `_ready()`, new flags at defaults, hooks empty, `SEPARATION_RADIUS` single-sourced. (`class_name Enemy` already landed in R-0 — it was the enabler for `Enemy.GROUP`.) | `enemy.gd`, `enemy_types.gd`, `goblin.tscn`, `level_controller.gd` | A round is **numerically identical**: same result, comparable lives, 60 FPS at peak. Goblin resolves to speed **100**, hp 10, silver 2. |
| 4 | **E-2 · Life-cost channel.** `on_enemy_escaped(life_cost := 1)`. Purely additive. | `enemy.gd`, `level_controller.gd` | `life_cost = 3` on a live goblin costs 3 lives **and decrements `enemies_to_resolve` by exactly 1**. |
| 5 | **E-3 · Wave composition.** `groups`, derived `count`, spawn plan array. Still 100% goblin. | `wave_manager.gd` | Totals match pre-change exactly (408 at scale 1.6). `count == plan.size()` asserted. |
| 6 | **E-4 · Skeleton.** Registry entry, `.tscn`, `ignore_separation`, pack runs. Waves 2+. | `enemy_types.gd`, `skeleton.tscn`, `wave_manager.gd` | Skeletons visibly slide through the crowd and reach the choke first. FPS holds. |
| 7 | **E-5 · Ogre.** hp 80, `life_cost 3`, `separation_weight 0.15`, bigger sprite, higher silver. Waves 3+. | `enemy_types.gd`, `ogre.tscn`, `wave_manager.gd` | One escaped ogre costs exactly 3 lives. Archer needs 8 hits — **buy a damage upgrade and measure it drop to 7.** That is Known issue 1 closing. |
| 8 | **A-1 · Rain of Arrows.** Registry entry, area-over-time payload, the shared round-ended rule. | `ability_manager.gd`, `entities/abilities/rain_of_arrows/` | Ticks over duration; silver routes normally; bar shows 2 slots, key `2` selects; **clicking slot 2 casts nothing**; no `previously freed`. |
| 9 | **A-2 · Divine Smite.** Acquisition radius, highest-HP target. No marker change. | `ability_manager.gd`, `entities/abilities/divine_smite/` | Smites an ogre out of a goblin crowd. Whiff still consumes cooldown. |
| 10 | **A-3 · Dragon Fire.** Fixed-axis run; `aim_marker` gains `SHAPE` + `"strip"`. | `ability_manager.gd`, `entities/abilities/dragon_fire/`, `ui/aim_marker/aim_marker.gd` | Run damages along the band; boulder's circle unchanged; a round ending mid-run neither crashes nor damages cleared enemies. |
| 11 | **Tune + verify + docs.** Composition, life budget vs ogres, `difficulty_scale` re-measure, `initial_cooldown`. Update CLAUDE.md (layout, separation, Known issues 1/1b, the `set_group("zombie", …)` gotcha), alpha_plan A2 → ✅. | numbers + docs | Proof cases below pass. |

**Ordering rules:**

- **R-0 → R-1 → R-2 block everything.** Do not write a new payload or enemy before R-1, or you
  write three new files against `get_zombies_in_radius` and rename them too.
- **After R-2, E (3–7) and A (8–10) are independent** and touch disjoint files — except A-2's
  *verification* wants E-5's Ogre. Two people: parallel, rejoin at 11.
- **E-1 and E-2 are the A1 Step 0 pattern** — additive seams changing nothing observable, so the
  risky commits (E-3 accounting, E-5 balance) land against a proven-unmoved foundation.

---

## Verification

Per CLAUDE.md's *Gotchas*: `execute_code` with `scope_path` `/root/map1` for manager methods;
`click_node` by **runtime-resolved** path (`find_child(...).get_path()` — procedural parents are
auto-named and indices shift); `runtime_get_script_vars` for phase and counters.
`get_global_mouse_position()` is not drivable by `input_simulate` — cast abilities by calling
`cast(id, pos)` directly. Confirm via state, never `dispatched: true`. Hold a round open with a
zero-enemy wave; freeze the horde with `set_group(Enemy.GROUP, "speed", 0.0)` — but sample a live
enemy's position, since it freezes them where they are. No perf claim without a measured
screenshot.

**Two proof cases that will not show up by simply playing:**

1. **Lose during a wave with an ogre and skeletons mid-flight → Play Again → Start.** No ghost
   spawns, no stale spawn plan, both counters zero at PRE_ROUND. E-3's plan array is new
   round-scoped state that `reset()` must clear — the exact shape of the bug A1's Timer fix
   prevented.
2. **Rain ticking, Dragon crossing, a boulder impacting and two fireballs landing on one dense
   cluster in the same frame — then lose the round during it.** No `previously freed`, no damage
   applied to force-cleared enemies. A1 proved four simultaneous boulders; A2 raises the bar
   because payloads now persist across the round boundary.

---

## Out of scope — named so they are not drifted into

- **The Troll boss** and any boss-wave structure. A2 owes it only the empty `_on_damaged()` hook;
  it then becomes a `.tscn`, a registry entry and a six-line subclass whenever scheduled.
- Per-type separation radius, mass, or any spatial-grid change (A3 owns this layer)
- Tower targeting priority (Divine Smite is the answer)
- Drag-to-aim direction for Dragon Fire
- De-duplicating `archer.gd`/`wizard.gd` targeting blocks
- Overlapping waves; anything raising the concurrent-enemy ceiling (A3)
- `TileMapLayer` migration (A3, bundled — Known issue 5)
- Point-hitbox AoE vs large sprites (cosmetic under placeholder art)
