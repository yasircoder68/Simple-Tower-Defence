# Medieval Horde Defense — Game Design & Implementation Plan

A medieval-themed incremental tower defense game inspired by *Sir, We Have an Orc Problem!*, built in Godot 4.6 (2D).

**Core Fantasy**: You are a castle commander defending your keep against overwhelming hordes of undead (zombies, skeletons, wraiths) using medieval weaponry — arrow towers, catapults, wizard towers, boiling oil, and special abilities like divine smite and dragon fire.

---

## Current State Assessment

Your prototype already has solid foundations:

| System | Status | Notes |
|---|---|---|
| Flow-field pathfinding | ✅ Working | BFS/Dijkstra with corner-cut prevention |
| Swarm zombie AI | ✅ Working (to ~250 enemies) | Flow-field + boids separation + wall sliding; see CLAUDE.md's Performance section for the open perf ceiling above that |
| Tower building (drag & drop) | ✅ Working | Ghost preview, grid snapping, validity check; now gated to the pre-round phase |
| Archer tower + homing arrows | ✅ Working | Single-target, stats resolved from `TowerStats` |
| Wizard tower + AoE fireballs | ✅ Working | Splash damage on impact, stats resolved from `TowerStats` |
| Player controller | 🗑️ Removed by decision | `player.gd`/`player.tscn`/`test.tscn` orphaned — pure tower defense, no player unit |
| Economy (silver/gold) | ✅ Working | `PlayerData` + `TowerStats`; kill → silver, first clear → gold, upgrades cost silver |
| Round lifecycle & lose condition | ✅ Working | `map1.gd`'s `RoundState`; single wave only (M2 adds progression) |
| Upgrade screen | ✅ Working (crude) | `round_ui.gd` — unstyled, thrown away at UI-0/UI-1 |
| Wave progression | ❌ Missing | M2 — single wave only right now |
| Meta-progression (incremental) | ✅ Working | Via silver/gold + `PlayerData`'s `user://` save — no separate "souls" system needed |
| UI (HUD, menus) | ⚠️ Crude only | `round_ui.gd` proves the loop; real HUD/theme is UI-0 through UI-4, `ui_plan.md` |
| Multiple enemy types | ❌ Missing | Only zombies |
| Multiple maps | ❌ Missing | Only map1 |
| Cooldown abilities | ❌ Missing | M2 — the only planned in-round player input, not built yet |

---

## Decisions (settled 2026-09-03)

The questions this section used to ask have been answered. They are no longer open.

| Question | Decision |
|---|---|
| Theme | **Medieval.** The `asserts/` classroom art is shelved, not used. |
| Player character | **Removed.** Pure tower defense — `player.gd`, `player.tscn`, `test.tscn` are orphaned by decision. |
| Meta-progression | **Yes**, via silver + gold. There is no "souls" currency. |
| In-round play | **Cooldown abilities.** Towers are pre-placed and auto-fire. |
| Upgrade scope | **Per tower type, permanent** across all levels. |

> [!WARNING]
> The economy described in the original §1.1 — gold spent to place towers, 50g archers, a build
> phase between waves — is **wrong and has been replaced**. See §1.1 below. Tower cost columns
> elsewhere in this document are stale; ignore them.

---

## Proposed Changes — Phased Roadmap

### Phase 1: Core Game Loop (Fix What's Broken)

These changes fix existing issues and establish the minimum playable loop.

---

#### 1.1 — Economy System `[REWRITTEN]`

**Nothing is purchased during a round.** Towers are placed in a pre-round phase from unlocked
types into a limited number of slots; once the round begins the loadout is locked.

| Currency | Earned | Supply | Buys |
|---|---|---|---|
| **Silver** | per enemy killed | infinite — farmable by replaying levels | the three upgrade tracks |
| **Gold** | completing a level, **once only** | finite = levels × gold per level | new tower types, new levels, extra placement slots |

Towers upgrade on three axes only: **range, fire-rate, damage** — per tower type, permanent,
applying to every tower of that type in every level.

##### ✅ [DONE] `scripts/player_data.gd`
- Autoload. The persistent save, written to `user://save.json`.
- `silver`, `gold`, `upgrades: {tower_type: {range, fire_rate, damage}}`,
  `unlocked_towers`, `cleared_levels` (the gold-once ledger), `slot_count`
- `signal silver_changed(n)` / `signal gold_changed(n)`
- `earn_silver(n)`, `spend_silver(n) -> bool`, `spend_gold(n) -> bool`
- `award_level_gold(level_id)` — no-ops if the level is already in `cleared_levels`
- Verified: fresh-save defaults, overspend rejection, gold-once ledger, a real disk
  save/reload round-trip (not just re-calling load on unchanged memory), and schema
  backfill for a save missing a newer tower's upgrade entry.

##### ✅ [DONE] `scripts/tower_stats.gd`
- Resolves `base + upgrade_bonus` per tower type into final range / attack-interval / damage
- Owns the silver cost curve per track — **exponential** (`10 * 1.35^level`)
- The single source of truth for tower numbers
- `try_upgrade()` spends silver and increments atomically — verified no upgrade leaks on
  insufficient silver

##### ✅ [DONE] `scripts/archer.gd`, `scripts/wizard.gd`, `scripts/archer_tower.gd`
- Removed `@export var damage`/`rate_of_fire`/`wizard_radius`/`fire_damage_radius`; both
  towers query `TowerStats.get_stats(TOWER_TYPE)` in their own `_ready()` instead
- `archer_tower.gd` no longer pushes stats onto the archer after instancing — this also
  fixed a pre-existing bug where it clobbered `archer.gd`'s own rate jitter
- `archer.tscn`'s `CollisionShape2D` scale corrected 4×→1× to match the new
  direct-radius assignment (was compensating for a hardcoded shape radius that no
  longer exists)
- Level-0 stats verified identical to the pre-refactor game (no balance change) via a
  live playtest: resolved damage/range/interval matched exactly, and an upgrade bought
  mid-session applied to the next tower placed
- `wizard_tower.tscn` having no script of its own no longer matters — retires that
  asymmetry

##### ✅ [DONE] `scripts/zombie.gd`
- `_die()` calls `map.on_zombie_killed(silver_reward)` (has_method-guarded), which calls
  `PlayerData.earn_silver()` — routed through the map rather than calling PlayerData
  directly, so the map can also track `zombies_to_resolve` for round-completion. See
  CLAUDE.md's Round lifecycle section.

##### ✅ [DONE] `scripts/map1.gd`
- Placement gated on `round_state == PRE_ROUND` **and** `PlayerData.slot_count`, not on
  affordability (nothing costs anything to place — see the economy table above)
- The ghost preview, validity check and grid snapping all survive unchanged
- Verified live: a 5th placement attempt at the default `slot_count` (4) is rejected, and
  raising `slot_count` un-blocks the identical cell — confirms the rejection is the slot
  cap, not a coincidentally-invalid cell

**Tuning consequences.** Silver being infinite makes the cost curve the entire difficulty knob;
grinding is intended, not a failure state. Permanent upgrades plus replayable levels means
early levels become silver farms rather than content, so every level must be tuned against an
assumed upgrade level.

**Resolved:** silver earned during a round is kept even on a loss — see CLAUDE.md's Tower
stats / state-boundary section for why this falls out of the architecture rather than needing
its own rule.

---

#### ✅ [DONE] 1.2 — Round Lifecycle & Lose Condition `[REWRITTEN — was "Base Health & Win/Lose"]`

Built as part of M1, not a separate BaseHealth-plus-game_over_screen pair — see
[CLAUDE.md](CLAUDE.md)'s "Round lifecycle" architecture section for the full design and
[base_health.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/base_health.gd) /
[map1.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/map1.gd) /
[round_ui.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/round_ui.gd)
for the code. Differences from the original plan, and why:

- **No `game_over_screen.tscn`.** `round_ui.gd`'s result panel covers win/lose/replay for M1 —
  crude and unstyled on purpose (real screens are UI-4, `ui_plan.md`). "Wave reached" doesn't
  apply yet (single wave, M1 scope); kills/gold-earned are visible via the status readout.
- **`base_health.gd` is round-scoped, not an autoload.** Lives reset every round
  (`base_health.reset()`, called from `_start_round()`) and are never written to
  `PlayerData`/`user://` — see the state boundary table. An autoload BaseHealth would have
  made that boundary easy to violate by accident.
- **`take_damage(1)` became `on_zombie_escaped()`** on `map1`, not a method on BaseHealth that
  zombies call directly — the map needed to intercept the event anyway (to track
  `zombies_to_resolve` for round-completion), so zombies talk to the map, and the map talks to
  `base_health`.
- **A round can win with escapes in it.** Completion is "every spawned zombie resolved,
  win or lose" — not "zero zombies got through." Confirmed live: a 25-zombie round with 3
  escapes (17/20 lives) still resolved as a win.

---

#### 1.3 — Wave Manager `[NEW]`

##### [NEW] [wave_manager.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/wave_manager.gd)
- Progressive waves with configurable escalation:
  - Wave 1: 20 zombies, speed 150
  - Wave 2: 35 zombies, speed 160, +5 HP
  - Wave N: exponential scaling
- Inter-wave breather (10-15s). **Not** a build phase — placement happens once, before the
  round; nothing can be placed or bought between waves.
- `signal wave_started(wave_num)` / `signal wave_cleared` / `signal all_waves_complete`
- Bonus gold between waves

##### [MODIFY] [map1.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/map1.gd)
- Replace current `spawn_zombies()` with WaveManager integration
- Remove `_on_start_button_pressed` direct spawning

---

### Phase 2: Medieval Content & Combat Depth

---

#### 2.1 — New Tower Types

| Tower | Type | Gold unlock | Mechanic |
|---|---|---|---|
| Archer Tower | Single-target | starter | Fast arrows, low damage (existing) |
| Wizard Tower | AoE splash | starter | Fireballs (existing) |
| **Catapult** | AoE + slow | TBD | Boulders deal high damage in a radius, briefly slow enemies |
| **Boiling Oil** | Ground AoE | TBD | Placed on path, damages enemies walking over it (DoT zone) |
| **Holy Shrine** | Buff/Support | TBD | Boosts nearby towers' attack speed by 20% |

Unlock prices are **TBD**: gold supply is finite and bounded by level count, so these can't be
priced until the number of levels is known.

##### [NEW] `scenes/catapult_tower.tscn`, `scripts/catapult_tower.gd`, `scenes/boulder.tscn`, `scripts/boulder.gd`
##### [NEW] `scenes/oil_trap.tscn`, `scripts/oil_trap.gd`
##### [NEW] `scenes/holy_shrine.tscn`, `scripts/holy_shrine.gd`

---

#### 2.2 — Enemy Variety

All enemies belong to a dark fantasy goblin horde theme.

| Enemy | HP | Speed | Special | Role |
|---|---|---|---|---|
| **Goblin** | 10 | 200 | None | Fodder — huge numbers, easy to kill |
| **Skeleton** | 6 | 280 | Spawns in packs of 4, ignores boids separation (slides through horde) | Rusher — punishes slow-firing towers |
| **Ogre** | 80 | 100 | Takes 3 lives on arrival | High-stakes target — must kill |
| **Troll** | 1000 | 70 | Enrages at 50% HP (moves faster, turns red) | Boss — needs everything thrown at it |

##### [NEW] `scenes/goblin.tscn`, `scripts/goblin.gd`
##### [NEW] `scenes/skeleton.tscn`, `scripts/skeleton.gd`
##### [NEW] `scenes/ogre.tscn`, `scripts/ogre.gd`
##### [NEW] `scenes/troll.tscn`, `scripts/troll.gd`

##### [NEW] [enemy_base.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/enemy_base.gd)
- Base class that all enemies inherit from
- Refactored from current `zombie.gd`
- Contains: flow-field following, boids separation (can be toggled per enemy), wall-sliding, `take_damage()`
- Properties: `hp`, `speed`, `lives_cost` (lives lost on reaching end), `gold_value` (gold dropped on death), `ignore_separation` (bool)

##### [DELETE] [zombie.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/zombie.gd)
##### [DELETE] [zombie.tscn](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scenes/zombie.tscn)
- Replaced by `goblin.gd` / `goblin.tscn` which extends `enemy_base.gd`

---

#### 2.3 — Tower Upgrades `[REWRITTEN — was "In-Run"]`

> [!WARNING]
> This section previously described clicking a placed tower mid-round to buy tiered upgrades,
> and selling towers for a 60% refund. **Both are gone.** Nothing is bought or sold during a
> round, and upgrades never attach to an individual tower.

Upgrades are bought on the **upgrade screen between rounds** (§3.1), cost **silver**, and apply
**per tower type, permanently** — buying archer damage buffs every archer in every level,
forever. There is no per-instance upgrade state, and therefore nothing to save per tower and
no refund mechanic.

The three tracks are the whole system: **range, fire-rate, damage.** Resolution lives in
`TowerStats` (§1.1), which towers query at spawn.

---

### Phase 3: Incremental Meta-Progression

This is what makes the reference game addictive — earning permanent upgrades across runs.

---

#### 3.1 — Persistent Progression `[REWRITTEN]`

Persistence is **not** a separate Phase 3 system — `PlayerData` (§1.1) already is the save, and
exists from M1. What lands here is the screen that spends what it holds.

##### [NEW] `scenes/upgrade_screen.tscn`
- **Silver** → the three tracks per tower type: range, fire-rate, damage.
  Repeatable, exponential cost.
- **Gold** → one-time unlocks: new tower types, new levels, extra placement slots.
  Finite supply, so these are build-defining choices rather than a completion checklist.
- Shows current silver / gold, each track's level, and the next cost

##### The state boundary
Keep these in separate containers — the only expensive-to-retrofit decision in the design:

| Persistent (`user://`) | Round-scoped (discarded) |
|---|---|
| silver, gold | lives, current wave |
| upgrade level per tower type | kills, silver earned this round |
| unlocked tower types | ability cooldowns |
| cleared levels (gold-once ledger) | placed tower instances |
| placement slot count | |

---

#### 3.2 — Main Menu & Run Flow

##### [NEW] [main_menu.tscn](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scenes/main_menu.tscn)
- "Begin Defense" → starts run
- "Upgrades" → opens upgrade shop
- "Quit"

##### [NEW] [run_manager.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/run_manager.gd)
- Manages the loop: Level Select → Pre-round Placement → Round → Result (silver always, gold on
  first clear) → Upgrade Screen → Level Select
- Tracks per-run stats (kills, waves, gold earned)

---

### Phase 4: Polish & Juice

---

#### 4.1 — HUD

##### [NEW] [hud.tscn](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scenes/hud.tscn)
- Gold display (top-left)
- Wave counter ("Wave 3/20")
- Lives display (hearts or castle icon)
- Kill counter
- Tower build sidebar (refactored from current)

---

#### 4.2 — Special Abilities (Cooldown-Based) `[PROMOTED — not polish]`

> [!IMPORTANT]
> Filed under Phase 4 when this document assumed a classic build-during-the-wave loop. With
> towers pre-placed and no mid-round spending, **abilities are the only live input a round
> has** — without them a round is watched, not played. Build these in **M2**, alongside waves
> and lives, not as a polish pass.

| Ability | Cooldown | Effect |
|---|---|---|
| **Rain of Arrows** | 30s | Massive arrow barrage in target area |
| **Divine Smite** | 60s | Lightning bolt, huge single-target damage |
| **Dragon Fire** | 90s | Dragon strafing run across the map |

##### [NEW] `scripts/ability_manager.gd`, `scenes/ability_bar.tscn`

---

#### 4.3 — Visual & Audio Polish
- Tower placement SFX + enemy death SFX
- Screen shake on large AoE hits
- Particle effects for projectile impacts, enemy deaths
- Medieval UI theme (parchment textures, stone borders)

---

### Phase 5: Maps & Replay Value

- **Map 2**: Forest path with branching routes
- **Map 3**: Castle courtyard, multiple entry points
- Map selection from main menu
- Each map has unique tilemap layout but shares the same flow-field system

---

## Immediate Bug Fixes `[SUPERSEDED — see CLAUDE.md's Known issues]`

The three items originally here are stale. Two are fixed (the per-frame disk write, `fire.gd`'s
global scan); the third (`asserts/` typo) is still open. **CLAUDE.md's "Known issues" section is
the current, maintained list** — this document doesn't duplicate it going forward, to avoid the
two drifting apart again.

---

## Verification Plan `[PARTIALLY SUPERSEDED]`

The items below describing gold-to-place, wave progression, and a 500-zombie 60fps target are
**stale** — gold isn't spent on placement (see §1.1), waves don't progress yet (M2), and
500 zombies at 60fps is a known **unmet** target (CLAUDE.md's Performance section: practical
budget is ~200–250 enemies, and the gap is a real open problem, not a rounding error).

What M1 actually verified, live, against the running game rather than by inspection — this is
the model for how future milestones should be checked, not a one-time record:

- Tower stats resolve identically to the pre-refactor game at upgrade level 0 (no accidental
  balance change), and an upgrade purchase changes the next-placed tower's stats
- The slot cap rejects a placement over the limit, and un-blocks the identical cell when the
  cap is raised (ruling out a coincidentally-invalid test cell before trusting the result)
- A full round: place → start → kill → earn silver → win → gold awarded once → replay → gold
  **not** re-awarded (the ledger) → buy an upgrade via a real button click → lose a round by
  letting zombies through unopposed → lives hit exactly 0 → round ends without waiting for
  every zombie to individually resolve

### Automated Tests
- Flow-field correctness: spawn zombie at start, verify it reaches end
- Round lifecycle: win awards gold once per level; loss ends the round the instant lives hit 0
- (Still needed) Wave progression, once M2 builds it: verify wave count increments and scales

### Manual Verification
- Play through progressive waves once M2 exists, to confirm the difficulty curve feels right
- Test tower placement on every valid/invalid cell, including at and over the slot cap
- Performance test at the ~200–250 enemy practical ceiling, not 500 — see CLAUDE.md before
  attempting to raise that ceiling; six prior optimization attempts are already ruled out there

---

## Recommended Build Order

Superseded by the milestones in [CLAUDE.md](CLAUDE.md#build-order) — M1 closes the economic
loop, M2 makes the round a game, M3 adds breadth, M4 is the UI pass. The per-item effort
estimates below the old table were written against the buy-towers-with-gold economy and no
longer apply.
