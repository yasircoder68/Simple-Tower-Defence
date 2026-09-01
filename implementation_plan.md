# Medieval Horde Defense — Game Design & Implementation Plan

A medieval-themed incremental tower defense game inspired by *Sir, We Have an Orc Problem!*, built in Godot 4.6 (2D).

**Core Fantasy**: You are a castle commander defending your keep against overwhelming hordes of undead (zombies, skeletons, wraiths) using medieval weaponry — arrow towers, catapults, wizard towers, boiling oil, and special abilities like divine smite and dragon fire.

---

## Current State Assessment

Your prototype already has solid foundations:

| System | Status | Notes |
|---|---|---|
| Flow-field pathfinding | ✅ Working | BFS/Dijkstra with corner-cut prevention |
| Swarm zombie AI | ✅ Working | Flow-field + boids separation + wall sliding |
| Tower building (drag & drop) | ✅ Working | Ghost preview, grid snapping, validity check |
| Archer tower + homing arrows | ✅ Working | Single-target, desync'd timers |
| Wizard tower + AoE fireballs | ✅ Working | Splash damage on impact |
| Player controller | ✅ Working | Top-down movement (currently disconnected) |
| Wave spawning | ⚠️ Basic | Single wave, no progression |
| Economy / resources | ❌ Missing | Towers are free |
| Win/lose conditions | ❌ Missing | Zombies despawn at end with no penalty |
| Meta-progression (incremental) | ❌ Missing | Core mechanic of the reference game |
| UI (HUD, menus, upgrades) | ❌ Missing | Only FPS counter + start button |
| Multiple enemy types | ❌ Missing | Only zombies |
| Multiple maps | ❌ Missing | Only map1 |

---

## User Review Required

> [!IMPORTANT]
> **Theme Confirmation**: You said "medieval" — I'm interpreting this as: stone castles, arrow slits, catapults, knights, undead hordes (zombies → skeletons, wraiths, etc.), wizards, holy magic. Is this the right vibe, or did you have something more specific in mind?

> [!IMPORTANT]
> **Player Character Role**: Your prototype has a playable `CharacterBody2D` but it's disconnected from gameplay. In *Sir, We Have an Orc Problem!*, there is no player character — you just place turrets. Do you want to:
> - **A)** Remove the player character and go pure tower defense (like the reference game)
> - **B)** Keep the player character as a hero unit that can move around, attack, and interact with the battlefield
> - **C)** Something else?

> [!IMPORTANT]
> **Incremental / Roguelite Loop**: The core hook of *Sir, We Have an Orc Problem!* is that you **earn permanent upgrades even when you lose**. Failed runs still give you currency to unlock better towers, increase damage, etc. Do you want this incremental meta-progression loop? This is a major architectural decision.

---

## Open Questions

1. **Art Style**: Are you planning to use pixel art, hand-drawn, or placeholder sprites for now? This affects UI layout and scale.
2. **Scope**: Are you targeting a short game (1-2 hour completionist run, like the reference) or something longer?
3. **Enemies**: The reference game has only orcs. Do you want variety (zombies, skeletons, armored knights, siege units) or keep it simple with one enemy type that just scales in HP/speed?

---

## Proposed Changes — Phased Roadmap

### Phase 1: Core Game Loop (Fix What's Broken)

These changes fix existing issues and establish the minimum playable loop.

---

#### 1.1 — Economy System `[NEW]`

##### [NEW] [economy_manager.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/economy_manager.gd)
- Autoload singleton managing gold
- `var gold: int = 100` (starting gold)
- `signal gold_changed(new_amount)`
- `func earn(amount)` / `func spend(amount) -> bool`
- Tower costs: Archer = 50g, Wizard = 100g
- Zombies drop gold on death (base 1-3g per kill)

##### [MODIFY] [map1.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/map1.gd)
- Check `EconomyManager.spend(cost)` before placing tower
- Update ghost tower validity to include affordability

##### [MODIFY] [zombie.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/zombie.gd)
- Call `EconomyManager.earn(gold_value)` on death
- Remove file I/O logging (performance fix)

---

#### 1.2 — Base Health & Win/Lose `[NEW]`

##### [NEW] [base_health.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/base_health.gd)
- `var lives: int = 20`
- `signal life_lost(remaining)` / `signal game_over`
- When zombie reaches `end_point`, deduct 1 life instead of silently despawning

##### [NEW] [game_over_screen.tscn](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scenes/game_over_screen.tscn)
- Shows wave reached, kills, gold earned
- "Retry" and "Return to Menu" buttons

##### [MODIFY] [zombie.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/zombie.gd)
- On reaching end_point: `BaseHealth.take_damage(1)` then `queue_free()`

---

#### 1.3 — Wave Manager `[NEW]`

##### [NEW] [wave_manager.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/wave_manager.gd)
- Progressive waves with configurable escalation:
  - Wave 1: 20 zombies, speed 150
  - Wave 2: 35 zombies, speed 160, +5 HP
  - Wave N: exponential scaling
- Inter-wave build phase (10-15 seconds to place towers)
- `signal wave_started(wave_num)` / `signal wave_cleared` / `signal all_waves_complete`
- Bonus gold between waves

##### [MODIFY] [map1.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/map1.gd)
- Replace current `spawn_zombies()` with WaveManager integration
- Remove `_on_start_button_pressed` direct spawning

---

### Phase 2: Medieval Content & Combat Depth

---

#### 2.1 — New Tower Types

| Tower | Type | Cost | Mechanic |
|---|---|---|---|
| Archer Tower | Single-target | 50g | Fast arrows, low damage (existing) |
| Wizard Tower | AoE splash | 100g | Fireballs (existing) |
| **Catapult** | AoE + slow | 150g | Boulders deal high damage in a radius, briefly slow enemies |
| **Boiling Oil** | Ground AoE | 75g | Placed on path, damages enemies walking over it (DoT zone) |
| **Holy Shrine** | Buff/Support | 200g | Boosts nearby towers' attack speed by 20% |

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

#### 2.3 — Tower Upgrades (In-Run)

##### [NEW] [tower_upgrade_system.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/tower_upgrade_system.gd)
- Click placed tower → upgrade panel appears
- 3 upgrade tiers per tower (costs escalate)
- Each tier increases damage, range, or fire rate
- Sell tower for 60% refund

---

### Phase 3: Incremental Meta-Progression

This is what makes the reference game addictive — earning permanent upgrades across runs.

---

#### 3.1 — Persistent Currency & Upgrades

##### [NEW] [meta_progression.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/meta_progression.gd)
- Autoload singleton
- `var souls: int` — permanent currency earned per run (based on kills + waves survived)
- Save/load to `user://save.json`
- Permanent upgrade tree:
  - **+10% Tower Damage** (repeatable, escalating cost)
  - **+1 Starting Gold** (repeatable)
  - **+1 Base HP** (repeatable)
  - **Unlock Catapult Tower** (one-time)
  - **Unlock Holy Shrine** (one-time)
  - **+5% Attack Speed** (repeatable)

##### [NEW] [upgrade_menu.tscn](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scenes/upgrade_menu.tscn)
- Between-runs upgrade shop screen
- Shows earned souls, available upgrades, costs

---

#### 3.2 — Main Menu & Run Flow

##### [NEW] [main_menu.tscn](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scenes/main_menu.tscn)
- "Begin Defense" → starts run
- "Upgrades" → opens upgrade shop
- "Quit"

##### [NEW] [run_manager.gd](file:///c:/disk/godot/projects/zombie%20game%20prototype%201/game/scripts/run_manager.gd)
- Manages run lifecycle: Menu → Level → Game Over → Souls Earned → Upgrade Shop → Menu
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

#### 4.2 — Special Abilities (Cooldown-Based)

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

## Immediate Bug Fixes (Should Do Now)

> [!WARNING]
> These issues exist in your current code and should be fixed regardless of which phase you start:

1. **`map1.gd`** writes to `res://zombie_pos.txt` every frame in `_process()` — causes unnecessary disk I/O. Remove or gate behind a debug flag.
2. **`fire.gd`** iterates ALL zombies in scene tree on impact (`get_tree().get_nodes_in_group("zombie")`) — use `Area2D` overlap check instead for O(nearby) instead of O(all).
3. **Folder typo**: Assets are in `res://asserts/` instead of `res://assets/` — cosmetic but confusing.

---

## Verification Plan

### Automated Tests
- Flow-field correctness: spawn zombie at start, verify it reaches end
- Economy: verify tower placement deducts gold, kills earn gold
- Wave progression: verify wave count increments and difficulty scales

### Manual Verification
- Play through 5+ waves to confirm difficulty curve feels right
- Verify game-over triggers correctly when lives reach 0
- Test tower placement on all valid/invalid cells
- Performance test with 500+ zombies on screen (target: 60fps)

---

## Recommended Build Order

| Priority | Work Item | Effort |
|---|---|---|
| 🔴 1 | Bug fixes (disk I/O, fire.gd AoE perf) | 1 hour |
| 🔴 2 | Economy system (gold) | 2-3 hours |
| 🔴 3 | Base health + game over | 2 hours |
| 🔴 4 | Wave manager | 3-4 hours |
| 🟡 5 | Enemy base class refactor | 3 hours |
| 🟡 6 | New tower types (catapult, oil, shrine) | 4-5 hours |
| 🟡 7 | New enemy types | 3-4 hours |
| 🟡 8 | HUD | 3 hours |
| 🟢 9 | Tower upgrades (in-run) | 4 hours |
| 🟢 10 | Meta-progression + save/load | 5-6 hours |
| 🟢 11 | Main menu + run flow | 3 hours |
| 🟢 12 | Special abilities | 4-5 hours |
| 🟢 13 | Polish (VFX, SFX, screen shake) | Ongoing |
| 🟢 14 | Additional maps | 3-4 hours each |
