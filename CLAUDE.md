# Medieval Horde Defense

An incremental tower-defense game in **Godot 4.6**, inspired by *Sir, We Have an Orc Problem!*
You defend a keep against overwhelming undead hordes using medieval towers. Failed runs still
earn permanent upgrades.

**Status: A1 complete — the first itch.io release is built.** Pathfinding, swarm AI, tower
building/removal/moving, the silver/gold economy, permanent upgrades, round win/lose and
`user://` persistence all work. On top of that, **progressive waves** and the **boulder
ability** now make a round something you play rather than watch: five escalating waves with a
breather between them, and a hold-to-aim ability on a 3s cooldown that is the only live input.

Not yet built: multiple enemy types, multiple maps, the horde engine rewrite, gold sinks, and
any real art or UI theme. That's A2 onward — see Build order.

---

## Direction (decided 2026-09-03 — do not re-litigate)

| Question | Decision |
|---|---|
| Theme | **Medieval** — castles, catapults, undead. |
| Player character | **Pure tower defense.** No player unit. |
| Meta-progression | **Yes** — permanent upgrades, `user://` save. Currencies are silver + gold; there is no "souls". |
| In-round play | **Cooldown abilities.** Towers are pre-placed and auto-fire; abilities are the only live input. |

**The classroom / school-horror art has been deleted** (`dd49e82`) — ~148 PNGs, 106MB, wrong
theme. It is still in git history if ever needed. Every sprite in the running game is a
100–300 byte placeholder awaiting the commissioned medieval art (a beta deliverable — see
`beta_plan.md`).

`player.gd`, `player.tscn`, `test.tscn`, `tile_map.tscn`, `oil_trap.tscn` and `build_ui.gd`
were **deleted** in the same cleanup — all verified orphans. Pure tower defense, no player unit.

**In flight: [a2_plan.md](a2_plan.md)** — enemy variety (goblin/skeleton/ogre), the zombie→goblin
rename, and the three remaining abilities. R-0/R-1/R-2 shipped; see that file for progress.

**Planned next: [a3_plan.md](a3_plan.md)** — the horde engine, targeting 1500 concurrent enemies,
bundling the TileMapLayer migration and ending with overlapping waves. **Read its opening section
before touching the separation code** — it overturns the diagnosis recorded under Performance
below.

**Roadmap: [alpha_plan.md](alpha_plan.md) -> [beta_plan.md](beta_plan.md) ->
[final_plan.md](final_plan.md)** — three release stages, 40/40/20 of remaining work. See Build
order below.

[implementation_plan.md](implementation_plan.md) is a **design reference**, not a roadmap — its
tower and enemy tables are still authoritative for what those things are, but its phase
numbering is superseded.

Tower removal + moving: [tower_editing_plan.md](tower_editing_plan.md) — **built and verified**
(commit `a22ca4a`). Closed the gap opened by making towers persist. The shipped design lives in
the Round lifecycle section below; the work order is kept for its rationale and for the two
findings recorded at the top of it.

UI and HUD work: [ui_plan.md](ui_plan.md). Zero-asset theme system; its UI-0 stage has no
dependencies and reorders the roadmap slightly (theme first, then each manager with its HUD
piece, rather than deferring all interface work to step 8).

---

## Economy (decided 2026-09-03 — supersedes implementation_plan.md §1.1)

**Nothing is bought during a round.** Towers are placed in a pre-round phase from unlocked
types into a limited number of slots. Once the round starts the loadout is locked, and the
only live input is cooldown abilities.

| Currency | Earned | Supply | Buys |
|---|---|---|---|
| **Silver** | per enemy killed | infinite, farmable by replaying | the three upgrade tracks |
| **Gold** | completing a level, **once** | finite = levels × gold per level | new tower types, new levels, extra placement slots |

Towers upgrade on exactly three axes: **range, fire-rate, damage.** Upgrades are **per tower
type and permanent** — buying archer damage buffs every archer you ever place, in every level,
forever.

Two consequences that drive tuning:

- Silver is infinite, so **the cost curve is the difficulty knob.** Escalate it exponentially
  or everything maxes on level one. Grinding is an intended mechanic, not a failure state.
- Permanent upgrades + replayable levels means **early levels stop being content** and become
  silver farms. Every level must be tuned against an assumed upgrade level.

### The state boundary — get this right first

The only expensive-to-retrofit decision in the whole design. Keep these in separate containers:

| Persistent (`user://` save, `PlayerData`) | Round-scoped (discarded, `level_controller`/`base_health`/managers) |
|---|---|
| silver, gold | `round_state`, `zombies_to_resolve` |
| upgrade level per tower type | lives (`base_health.lives`) |
| unlocked tower types | placed tower instances (`towers_by_cell`) |
| levels already cleared (gold-once ledger) | current wave + phase (`wave_manager`) |
| placement slot count | ability cooldowns + selection (`ability_manager`) |

This split is implemented, not just planned — `base_health.gd` and `level_controller.gd`'s round-lifecycle
fields never write to `PlayerData`, and nothing in `PlayerData`/`TowerStats` reads round state.

### When the save actually gets written

`PlayerData` mutators set a `_dirty` flag; they do **not** write to disk. Flushing happens at
three checkpoints, via `save_if_dirty()`:

| Checkpoint | Where | Why there |
|---|---|---|
| Round end (win *or* loss) | `level_controller._end_round()` | One write per round instead of one per kill |
| Upgrade purchase | `TowerStats.try_upgrade()` | Deliberate user action, low frequency, flush immediately |
| Quit / tree exit | `PlayerData._notification()` | Safety net for `WM_CLOSE_REQUEST` and `EXIT_TREE` |

**Do not call `save_data()` from `earn_silver()`.** It runs once per kill — hundreds of times a
round — and saving there recreates the per-frame disk I/O that was already a headline bug in
this project (see Performance / Known issues). If you add a new mutator, set `_dirty` and let
an existing checkpoint flush it.

This was originally missing entirely: `save_data()` existed and worked, but nothing in the game
ever called it, so all progression was lost on quit. The unit test passed because it called
`save_data()` by hand before reloading. Worth remembering as a pattern — verifying a function
works is not the same as verifying anything calls it.

### Tower stats are derived, not stored

Because upgrades are per-type and permanent, a tower's real damage is
`base + upgrade_bonus`, resolved **at spawn** from a central `TowerStats` service. Do not add
`@export var damage` to new towers and do not bake stats into `.tscn` files — both archer and
wizard pull from the one source. (This is also what retires the archer/wizard script asymmetry
noted under Towers.)

**Resolved:** silver earned during a round is kept even if the round is lost. This isn't a
policy switch anywhere — `PlayerData.earn_silver()` is called immediately, synchronously, per
kill, and `_end_round(false)` (the loss path) never touches `PlayerData` at all. There's no
"pending round silver" to roll back. Verified live: won a round for silver, replayed and lost a
different round, confirmed the silver from the win was still there afterward.

---

## Layout

```
zombie game prototype 1/
├── CLAUDE.md                ← this file
├── alpha_plan.md            ← roadmap: itch releases, mechanics-first (40%)
├── beta_plan.md             ← roadmap: Steam demo, final art (40%)
├── final_plan.md            ← roadmap: paid release (20%)
├── implementation_plan.md   ← design reference (tower/enemy tables); phases superseded
├── ui_plan.md                ← zero-asset UI plan (theme, HUD, screens)
├── tower_editing_plan.md    ← shipped work order (removal + moving)
├── rules_for_godot_mcp.md   ← MCP toolkit reference
├── .mcp.json                ← MCP config (see MCP setup below)
└── game/                    ← the Godot project (project.godot lives HERE, not at root)
    ├── autoload/            ← player_data.gd, tower_stats.gd (registered in project.godot)
    ├── entities/            ← COLOCATED: each thing owns a folder with its scene+script+art
    │   ├── towers/archer/       archer_tower.tscn/.gd, archer.tscn/.gd, archer*.png
    │   ├── towers/wizard/       wizard_tower.tscn, wizard.tscn/.gd, wizard*.png
    │   ├── enemies/zombie/      zombie.tscn/.gd        (→ goblin/ at the A2 rename)
    │   ├── abilities/boulder/   boulder.tscn/.gd       (A1; no PNG yet — see Known issues)
    │   └── projectiles/         arrow/, fire/
    ├── levels/              ← level_01.tscn + tilesets/my_tiles.tscn
    ├── systems/             ← level_controller.gd (shared by ALL levels), base_health.gd,
    │                          wave_manager.gd, ability_manager.gd
    ├── ui/                  ← build_sidebar/, ghost_tower/, aim_marker/, ability_bar/,
    │                          round_ui.gd, fps_counter.gd
    ├── assets/              ← SHARED only: 1_pixel.png, audio/{sfx,music}/, fonts/
    ├── testbed/             ← clean_area.tscn/.gd (quarantined harness)
    └── addons/godot_mcp_toolkit/   ← 277 files, vendored; not your code
```

**Colocation is the convention** (restructured `dd49e82`). A new tower/enemy gets its own folder
under `entities/` holding its scene, script and art together — don't scatter them into parallel
`scenes/`+`scripts/` trees. `assets/` is for genuinely shared things only. The artist brief is
literally "replace the PNG in each entity folder."

The repo root is **one level above** the Godot project. `res://` maps to `game/`.

---

## MCP setup (important)

The Godot MCP toolkit gives you live editor + runtime access: read/edit scenes and scripts,
start playtests, take screenshots, inspect live variables. It is worth using — reading
`.tscn` text is far less reliable than querying the editor.

**It only works if the Godot editor is open.** The plugin hosts a WebSocket server inside the
editor (port 6550–6560). Close the editor and the tools go dead.

`.mcp.json` sits at the **repo root** and pins `GODOT_MCP_PROJECT_PATH` to
`c:/disk/godot/projects/zombie game prototype 1/game`. That pin is required: the npm bridge
resolves which editor to talk to by matching cwd against a registry, and a session launched
from the repo root would otherwise look up the wrong path and fail with `AUTH_FAILED`.
Don't remove the env var, and don't move `.mcp.json` into `game/`.

Verify a connection with `editor_get_console` — you want to see
`[MCPRegistry] registered .../game on port 6550`.

---

## Architecture

### Flow-field pathfinding
`level_controller.gd` runs a BFS out from `EndPoint` across every non-wall cell, then converts the cost
field into one direction vector per cell. Enemies just read their cell's vector.

- **Drawn tiles are walls.** `walls_dict` is built from `my_tiles.get_used_cells(0)`.
- `my_tiles` is a TileMap of 1×1 tiles scaled 50×, so **one cell = 50 world px**.
- Towers may only be placed **on** wall tiles; enemies path through the gaps.
- Diagonals cost the same as orthogonals (`cost + 1`), which makes this a Chebyshev field.
  Known wart — see Known issues.

### Enemy movement
Enemies are `Area2D` and move themselves by assigning `global_position`. **There is no physics
movement anywhere** — no `move_and_slide`, no rigid bodies. Wall collision is a manual
`map.is_wall()` point test with per-axis sliding.

### Separation (the perf-critical path)
`level_controller.gd` rebuilds a **spatial grid** every physics frame: `zombie_grid` maps a 32px cell to a
plain `Array` of enemy *positions*, with `zombie_grid_nodes` holding the parallel node refs for
splash damage. Enemies read the 3×3 block around themselves for push-apart.

Three rules were learned the hard way here — violate any of them and the framerate collapses:

1. **Never merge grid cells into one candidate list.** The allocation dwarfs the work and
   defeats the early-out.
2. **Never touch a node reference in the inner loop.** `other.global_position` is a Variant
   dynamic dispatch; that alone cost ~15× at 600 enemies.
3. **Don't use `PackedVector2Array` for the cells.** It's copy-on-write, so appending to one
   stored in a Dictionary can copy the whole array per append.

### Collision layers
Named in Project Settings. Every `Area2D` sets these explicitly — **if you add a new Area2D,
set them, or you reintroduce the O(n²) collapse.**

| Layer | Name | Who is on it | Who masks it |
|---|---|---|---|
| 1 | `enemies` | enemies | tower ranges, projectiles |
| 2 | `tower_range` | archer / wizard detectors | — |
| 3 | `projectiles` | arrow / fire | — |

Enemies have **`monitoring = false`** — they detect nothing. Detection is done *to* them by
towers and projectiles. Separation comes from the grid, not from overlap queries.

### Towers
`archer_tower.tscn` → `archer` (Area2D detector + Timer) → homing `arrow`, single target.
`wizard_tower.tscn` → `wizard` (r=200) → homing `fire`, AoE 100.

Both `archer.gd` and `wizard.gd` resolve `range` / `attack_interval` / `damage` from
`TowerStats.get_stats(TOWER_TYPE)` in their own `_ready()` — **do not `@export` stats on a
tower script and do not bake them into a `.tscn`.** This retired the old archer/wizard
asymmetry (wizard_tower having no script no longer matters — neither tower owns its own
numbers now). Resolution happens once, at spawn; a tower placed before an upgrade keeps its
old stats for that round, which is correct given upgrades only happen between rounds.

Wizard's AoE splash radius (`AOE_RADIUS`, 100px) is a separate constant in `wizard.gd`, not
part of `TowerStats` — it's not one of the three upgrade tracks the player buys. If splash
size becomes upgradeable later, add it to `TowerStats` as a fourth track rather than
conflating it with `range` (which governs target *acquisition* only).

### The enemy contract (A2 R-0)

`zombie.gd` declares **`class_name Enemy`** — the class is already the shared enemy base; only the
file name is stale until A2's R-2 rename. Two things live on it that the rest of the game depends
on:

- **`Enemy.GROUP`** — the group every enemy joins, **in code**, via `add_to_group(GROUP)` in
  `_ready()`. It used to be scene data only (`groups=["zombie"]` in the `.tscn`, with no
  `add_to_group()` anywhere), which meant a new enemy scene could silently forget it and be
  invisible to every tower, the spatial grid and every AoE — with no error. Nine literals across
  six files now read this one const. **A new enemy scene must not re-declare the group in its
  `.tscn`; it gets it by extending `Enemy`.**
- **`Enemy.ROUND_CONTRACT`** — the map-side members an enemy needs in order to score. Probed
  **once at spawn**, not per call site, so `_die()` and `_escape()` can never disagree about
  whether the map is scoring. A map implementing *all* of it scores; *none* of it is the testbed
  and is legitimate; **some** of it is always a bug and `push_error`s naming what's missing.

`level_controller._ready()` runs `_assert_enemy_contract()` unconditionally, so a drifted name is
caught at game start rather than at the first kill of the first round. `boulder.gd` and `fire.gd`
likewise `push_error` when their splash query falls back **on the real map** — discriminated by
the `"map"` group, which `clean_area.tscn` deliberately isn't in.

Enemy scripts must never name a controller class — the map is duck-typed through `map`, so
`class_name Enemy` here can never form a cyclic reference with one on `level_controller`.

### Waves (A1)

`systems/wave_manager.gd`, a round-scoped child of `level_controller`. Escalation is **density
only** — `WAVE_TABLE` carries count and spawn interval per wave; enemy HP and speed are constant
across waves by decision, so the manager never touches the enemy scene beyond instantiate and
position.

- **Its own phase enum** (`IDLE → SPAWNING → CLEARING → BREATHER → DONE`) is private to the
  manager. `RoundState` deliberately gained no `BETWEEN_WAVES` value — the round stays `IN_ROUND`
  for its whole duration, so `is_valid_placement()`, `_upgrades_allowed()`, `_input()`'s tower
  branch, `remove_tower()` and `begin_move()` all keep working untouched. Placement and upgrades
  stay locked through breathers **for free**.
- **Timer-driven, never a coroutine.** The old `spawn_zombies()` awaited per zombie, producing a
  coroutine that outlived `_clear_all_zombies()` and could wake into a *fresh* round and keep
  spawning. A Timer has nothing to leak, stops on demand, and exposes its state to
  `runtime_get_script_vars`. **Don't reintroduce an await loop here.**
- **Waves are strictly sequential** — N+1 starts only after N fully resolves. Two reasons: it caps
  concurrent enemies at one wave's size (keeping under the perf ceiling), and it means a dying
  enemy unambiguously belongs to the current wave, so one counter suffices. Overlapping waves
  would need a wave tag on every enemy and per-wave decrements — a real deferred cost, not a
  dodged one.
- **How the round ends without the manager reaching into `_end_round()`:** `_start_wave()` tops up
  `map.zombies_to_resolve` with the new wave's count, and `_begin_breather()` pre-reserves the
  *next* wave's count before the gap opens. On the last wave nothing tops it up, so it reaches 0
  naturally and `level_controller`'s existing `_check_round_complete()` ends the round won —
  through the exact M1 path (gold-once ledger, save flush, `round_ended`). The two counters
  decrement on the same events and the wave-boundary overwrite re-syncs them, so they cannot
  drift.
- **Miss the pre-reservation and you get "victory after wave 1"** — `_check_round_complete()` runs
  on the very resolution that clears a wave, and would see a counter of 0 during the breather.
  This bit twice during implementation; it is the failure mode to watch for here.
- Level authoring is two exports: `wave_count` (rows used) and `difficulty_scale` (multiplier on
  count only — spawn interval is pacing, not difficulty).

### Abilities (A1)

`systems/ability_manager.gd`, also round-scoped. A1 ships **one** entry in its `ABILITIES`
registry — the boulder — but the registry, per-ability cooldown dict and selection bar exist
already, because migrating one ability is far cheaper than migrating four in A2.

- **`entities/abilities/boulder/`** — hold LMB to aim, release to drop; 3s cooldown, ~0.5s arc,
  radius 70, damage 15. A plain `Node2D`, **not** an `Area2D`: it queries the spatial grid at
  impact, so it needs no collision shape and adds no monitoring body to a 150-enemy wave.
- **Routed through `_unhandled_input()`, not `_input()`** — and that distinction is load-bearing.
  `_input()` runs *before* GUI handling, so a click on the ability bar would start an aim and
  throw on release at whatever sits behind the bar. Controls consume clicks that land on them, so
  unhandled input only sees the game world. (The tower drag in `_input()` has the same hazard and
  gets away with it: a sidebar click resolves to a cell where nothing is placed.)
- **`can_cast()` reads `round_state` live**, mirroring `is_valid_placement()` and
  `_upgrades_allowed()`. It is not a cached flag, because `reset()` is called both entering a
  round *and* leaving one (`start_new_round()`), so a cached flag would arm the boulder during
  the build phase.
- **`ui/aim_marker/`** draws its circle and reads the radius from the *selected* ability's payload
  script, so the preview cannot drift from the real blast.
- **`ui/ability_bar/`** is its own scene, deliberately not part of throwaway `round_ui.gd` — it is
  a permanent UI element (ui_plan UI-1), so building it inside the throwaway means building it
  twice. `build_sidebar` is the precedent.
- Boulder kills route through `zombie._die()` → `map.on_zombie_killed()` like any other kill;
  silver needed no wiring.

### Round lifecycle

`level_controller.gd` owns a `RoundState` enum (`PRE_ROUND` → `IN_ROUND` → `ROUND_WON`/`ROUND_LOST`).
`_start_round()` calls `wave_manager.begin()`; the flat `spawn_zombies()` path was deleted at the
A1 handover.

- **Placement** only succeeds in `PRE_ROUND` (`is_valid_placement` checks `round_state` first)
  and is capped at `PlayerData.slot_count`. `_start_round()` force-cancels any in-progress drag.
- **Towers can be removed and moved, both `PRE_ROUND`-only, both free** — see
  `tower_editing_plan.md` for the full design. `remove_tower(cell)` frees the cell outright; no
  refund, because placement itself is free and the freed slot *is* the refund. `begin_move()` /
  `finish_move()` / `cancel_move()` reposition the existing node rather than destroy-and-recreate,
  so a bug in the restore path can't lose a tower. `towers_by_cell` (Vector2i -> tower node) is
  the single source of truth for what's placed and where — it replaced an earlier
  `occupied_cells` + `placed_towers` pair that had to be kept in sync by hand on every op.
  `finish_move()`/`cancel_move()` are deliberately self-contained (they clear `dragging_type`
  and hide the ghost themselves) rather than leaving that to each caller — a caller that forgot
  those two lines would leave the game stuck mid-drag for a real player. `_input()` now branches
  on LMB-press-over-an-occupied-cell (pick up) and RMB-release-over-an-occupied-cell (remove) in
  addition to the original press-drag-release placement flow.
- **Enemies report their own fate.** `zombie.gd`'s `_die()` calls
  `map.on_zombie_killed(silver_reward)`; `_escape()` calls `map.on_zombie_escaped()`. Both are
  `has_method`-guarded on the map side, so `clean_area.tscn`'s stripped-down test harness (no
  round lifecycle at all) still runs zombies unmodified.
- **A round completes when `zombies_to_resolve` hits 0** — every spawned zombie has been either
  killed or has escaped. "Won" means "you didn't run out of lives," **not** "zero escapes." A
  round with 25 spawned and 3 escaped (17 lives left) is still a win.
- **A loss short-circuits.** The instant `lives <= 0`, `_end_round(false)` fires immediately —
  it does not wait for the remaining spawned-but-unresolved zombies to individually escape or
  die. Those get force-cleared via `_clear_all_zombies()`, and `wave_manager.abort()` stops both
  the spawn and breather timers so nothing feeds a round that already ended.
  Note `on_zombie_escaped()` returns *before* forwarding to `wave_manager.on_enemy_resolved()`,
  so the loss wins the race against a wave completing on the same escape. That is deliberate, and
  it means `zombies_to_resolve` and `wave_remaining` can differ by exactly 1 at the moment of a
  loss. Harmless — the round is over — but it reads like a desync if you find it cold.
- **`start_new_round()`** (the "Play Again" flow) returns to `PRE_ROUND` **keeping the tower
  layout** — a layout you built survives replaying the level, and you can keep adding to it up
  to `slot_count`. Only a map change resets placement, which happens for free because loading
  a different level scene destroys those nodes. If levels ever swap in-place without a scene
  reload, call `_clear_placed_towers()` at that point. Note this also means towers do **not**
  survive quitting the app — they live in the scene, not in `PlayerData`.
- **Persisted towers must be re-stat'd.** Towers resolve from `TowerStats` at spawn, so a
  tower placed before an upgrade would keep stale numbers now that it survives the round.
  `_start_round()` calls `get_tree().call_group("tower_unit", "refresh_stats")` before the
  first spawn; `archer.gd`/`wizard.gd` both join `tower_unit` and expose `refresh_stats()`.
  **Any new tower script must do both**, or it silently ignores upgrades.
- **`start_new_round()` does not emit `round_started`** (only `_start_round()`, the Start
  button, does). `round_ui.gd` learned this the hard way: hide UI state reactively in the
  handler that changes it, don't assume a lifecycle signal covers every entry point back to
  the same state.
- **Upgrades are locked outside `PRE_ROUND`**, enforced in two places: the buttons' `disabled`
  flag, and an authoritative guard in `round_ui._on_upgrade_pressed()`. The guard is not
  redundant — a disabled Button still runs its `pressed` handler if something emits the signal
  directly (which `input_simulate`'s `click_node` does, and which silently defeated the first
  version of this test).
- **Gold-once is enforced by `PlayerData.award_level_gold`**, not by `level_controller` — `_end_round(true)`
  calls it and only forwards the *actual* amount paid (0 on a replay) through `round_ended`'s
  `gold_awarded` param. Never infer "gold was paid" from `won == true` alone.

`round_ui.gd` is the M1-only status/result/upgrade UI — a single CanvasLayer, explicitly
throwaway, replaced wholesale by UI-0/UI-1 (`ui_plan.md`). Its buttons are given explicit
`.name`s (`UpgradeButton_<type>_<track>`, `PlayAgainButton`) specifically so they're
addressable by path for testing — anonymous procedurally-created `Control`s otherwise get
auto-generated names like `@Button@42`, gettable at runtime via
`node.find_child("Name", true, false)` but not guessable in advance.

---

## Conventions

- **Tabs** for indentation (Godot standard).
- Comments explain *why*, not *what* — especially around the perf-critical separation code.
- Type-annotate locals in hot loops. `:=` inference fails on values read out of untyped
  containers, which is a compile error, not a warning.
- Debug output goes through `print()` gated on an export flag (`level_controller.gd` has `debug_logging`).
  **Never `FileAccess.open("res://…", WRITE)`** — see Known issues #1.
- Prefer MCP `node_set_property` + `editor_save_scene` over hand-editing `.tscn`.

---

## Performance: the open problem

Measured on this machine, `level_01`, enemies spawned instantly:

| Enemies | FPS (before fixes) | FPS (now) |
|---|---|---|
| 50 | 53 | **60** |
| 152 (A1 wave 5, live round) | — | **60** |
| 200 | — | **57** |
| 600 | 2 | **4** |

**The practical budget is ~200–250 enemies.** Beyond that the framerate falls off a cliff, and
the falloff is super-linear in *density*, not in count.

The cost is isolated to `zombie.gd::_separation()`. Confirmed by probe: at 600 enemies, with
separation disabled the game runs at **60 FPS** (rendering 600 sprites is free); enabling it
drops to 2–4.

**Ruled out** — don't spend time re-testing these, they were each tried and measured:

- Area2D overlap queries (replaced with the spatial grid — helped, not enough)
- Merged candidate-list allocation (removed)
- Node-reference dynamic dispatch in the inner loop (removed; 1 → 4 FPS)
- Capping candidates examined per frame at 24 (**no change at all** — the tell that the
  remaining cost is not the inner loop)
- `PackedVector2Array` copy-on-write on append (switched to plain Arrays; no change)
- Per-frame `map.get("zombie_grid")` dictionary fetch (cached the reference; no change)
- Flow-field lookup / TileMap `local_to_map` calls (60 FPS with these alone)
- Rendering and the physics broadphase (60 FPS with `_physics_process` disabled)

> [!WARNING]
> **The "recommended next attempt" below is disputed and probably wrong. Read
> [a3_plan.md](a3_plan.md) before acting on it.** A per-enemy accounting done during A3 planning
> found the cost is dominated by **16–25 `Vector2i`-keyed Dictionary operations and ~11 `Vector2i`
> constructions per enemy per frame** — roughly 10,800 probes/frame at 600 enemies. A manager loop
> removes **one** Callable dispatch out of that and touches none of the hashing. It is a genuine
> win and a prerequisite for later work, but it is not the fix, and following it as written would
> most likely produce a sixth consecutive "no change".
>
> The same accounting explains the 24-cap null result below: the nine-cell scaffolding is paid **in
> full by an enemy with zero neighbours**, so no inner-loop cap can reduce it. This paragraph gets
> rewritten with measured numbers at a3_plan's M-1.

**Recommended next attempt (disputed — see above):** stop giving every enemy its own
`_physics_process`. Move the
whole horde into a single manager loop on `level_controller` that updates all enemies in one tight pass.
That removes 600 per-node script invocations and 600 sets of cross-object `map.` dispatches
per frame, which is the largest remaining structural cost. If that isn't enough, the horde
needs to leave GDScript entirely (MultiMesh + a compute-style update, or GDExtension).

**Do not claim the perf problem is fixed without a measured 600-enemy screenshot** — and, from A3
onward, a `us_per_enemy` figure from the bench harness. FPS alone is vsync-quantised: anything from
3 ms to 16.6 ms of work reports "60", so an optimisation on the flat part of the curve reads as "no
change" whether it worked or not. Only two rows of the table above carry information at all.

---

## Repo history — rewritten 2026-09-04

`git filter-repo` purged the shelved asset packs and old `.docx` files from **all** history:
**`.git` went 107 MB → 875 KB** (122x). Force-pushed to `origin`; all 7 branches survived.

**Every commit hash before 2026-09-04 changed.** Any hash cited in an older document, commit
message or chat log is dead — map by commit *message*, not by hash. A pre-rewrite clone is
incompatible and must be re-cloned.

A full pre-purge backup sits at `C:\disk\godot\projects\zombie-game-BACKUP-prepurge`
(109 MB). Safe to delete once you're satisfied nothing was lost.

---

## Known issues

Fixed and verified: collision layers, the `res://` export crash, per-frame disk I/O, the
per-enemy spawn flush, `fire.gd`'s global group scan, the separation architecture, the
archer's jitter-clobbering (retired along with the @export stats it was fighting over), the
archer/wizard stat asymmetry (both now resolve from `TowerStats`), and — in A1 — `arrow.gd`'s
missing `return` after `queue_free()` plus the enemy/tower draw order (towers now `z_index = 20`,
enemies 10, aim marker 25, boulder 30).

Still open, roughly by value:

1. **The archer's damage upgrade track is inert.** Archer base damage is 10 and zombie HP is
   exactly 10, so buying damage changes nothing (12 and 14 still one-shot a 10 HP enemy). Wizard
   is unaffected (damage 3, four hits). **Measured, and deliberately not fixed:** raising zombie
   HP is a binary cliff, not a dial — at HP 16 the archer needs two shots, roughly halving its
   DPS, and a fresh-save round goes from a comfortable win to a loss at wave 4. A2's Ogre (80 HP)
   and Troll (1000 HP) fix this for free. Don't "helpfully" raise zombie HP to fix the track.
1b. **Freed-node access through the spatial grid — FIXED, but read this before touching the
   grid.** `zombie_grid_nodes` caches node references at rebuild time; splash damage reads
   them later in the same frame, by which point other kills may have freed them. This crashed
   in real play (`get_zombies_in_radius: Invalid access ... 'previously freed'`, two wizards on
   a dense cluster). Guarded now in three places: skip queued/invalid on grid rebuild, and
   `is_instance_valid()` in both `get_zombies_in_radius()` and `fire.gd`'s damage loop. Any new
   consumer of `zombie_grid_nodes` needs the same guard — the positions array (`zombie_grid`)
   is safe, only the node-reference one is hazardous.
2. Flow field charges `cost + 1` for diagonals → Chebyshev distances, so diagonal routes are
   under-priced and paths skew.
3. `is_wall()` tests only the enemy's centre point, so bodies clip wall corners.
4. `place_tower` marks exactly one cell occupied, but the wizard sprite is 9× scale — towers
   visually overlap.
5. `TileMap` is deprecated as of Godot 4.3 (project targets 4.6). **Migration is deliberately
   deferred — do not "helpfully" do it.** Deprecated is not removed; it works fine in 4.6. The
   horde engine rewrite in alpha tears through the same pathfinding code (`get_used_cells(0)`,
   `local_to_map`, `map_to_local`, `get_used_rect`), so migrating separately destabilises that
   code twice. **Bundle it with the horde rewrite, or do it immediately before building levels
   2–15 — whichever comes first.** Note the `0` in `get_used_cells(0)` is a layer index that
   ceases to exist under `TileMapLayer`, where the node *is* the layer.
6. The TileMap physics layer generates collision shapes that nothing uses (movement is manual).
7. `archer.tscn` still carries a leftover `position = Vector2(329, 98)`, dead because
   `archer_tower.gd` repositions the archer after `add_child`. Harmless, cosmetic.
8. **The boulder has no PNG of its own.** It uses the shared `assets/1_pixel.png` with a brown
   modulate, the same placeholder pattern `zombie.tscn` uses. The folder exists, so the artist
   brief ("replace the PNG in each entity folder") just needs a `boulder.png` dropped in.

**Fixed in the `dd49e82` restructure:** the vestigial `TileMap` node, dead `build_ui.gd`, the
`asserts/` typo (now `assets/`), and the stale `damage`/`wizard_radius` scene overrides.

---

## Build order

**The roadmap is now three release stages**, each publicly shippable:

| Stage | Ships to | Graphics | Share of remaining work |
|---|---|---|---|
| [alpha_plan.md](alpha_plan.md) | itch.io, across multiple updates | rough / placeholder | 40% |
| [beta_plan.md](beta_plan.md) | Steam, as a free demo | **final quality** | 40% |
| [final_plan.md](final_plan.md) | Steam, paid release | final | 20% |

Two things that fall out of that and catch people:

- **Art is a beta deliverable, not a final one.** The demo must look finished, so the
  commission has to be briefed during alpha to arrive in time.
- **Alpha is a series of releases, not a gate.** Ship early and repeatedly; the first public
  build only needs progressive waves and the cooldown abilities on top of what already exists.

The **horde engine rewrite** (massive battles, replacing the ~250-enemy ceiling documented under
Performance) lands mid-alpha. It is the largest single item in the roadmap and the biggest
technical unknown — timebox it and keep the current GDScript horde as a fallback, so worst case
the game has smaller battles rather than no schedule.

### Pre-alpha — complete

**M1 — the economic loop.** ✅ Done and verified live.
`PlayerData` (persistent save), `TowerStats` (base + upgrade → final stats, silver curve
`10 * 1.35^level`), both towers refactored to resolve from it, the `RoundState` lifecycle with
`base_health`, the lose condition, and the throwaway `round_ui`. Base/level-0 stats were set to
match the pre-refactor game exactly, so the refactor introduced no balance change.

**Tower removal + moving.** ✅ Done and verified live (`a22ca4a`), per
[tower_editing_plan.md](tower_editing_plan.md).

### Alpha

**A1 — "it's a game now".** ✅ Done and verified live, per [a1_plan.md](a1_plan.md). Twelve
commits: the manager seam, the boulder (cooldown → entity → aiming → registry + bar), then the
wave machine (phases → counters → breather → reset guards → handover), then HUD and tuning.
A full round is 408 enemies across 5 waves at 60 FPS, ending won or lost from a single Start
press.

Three things A1 taught that generalise:

1. **Make the seam commit purely additive.** Step 0 wired every hook both tracks would need but
   deleted nothing, so the old flat spawner kept the game playable while the wave machine was
   built beside it. An earlier draft of the plan deleted `spawn_zombies()` up front — that would
   have left the game with no enemies at all for eight commits.
2. **Tuning assumptions don't survive contact.** The plan assumed `max_lives` had to rise from 20
   to 30 (20 lives against 255 enemies looked like an 8% leak tolerance). Measured: a fresh save
   lost **four** lives across the whole round, because a choke point means almost nothing leaks.
   The change was dropped.
3. **A test hook that skips the real path is worse than no hook.** `force_clear_wave()` stepped
   waves 1→5 correctly while never ending the round, because it bypassed the
   `_check_round_complete()` that real resolutions trigger. It would have reported five waves
   working with round-end completely untested.

**A2 — enemy variety.** 🚧 In progress; see [a2_plan.md](a2_plan.md) for the work order and
step-by-step state. Step 0 (harden the enemy contract) is shipped and verified.

A fourth lesson, from A2's R-0, which generalises past this project: **verify the safety net by
breaking it.** The contract guards were only trusted after a member was deliberately misspelled
and both nets were watched firing with the exact missing name. That exercise is also what
surfaced the `debugger_get_log` vs `editor_get_console` gap under Gotchas — a net that had never
been tripped, checked through a stream that could not have shown it, would have been worth
nothing.

Three bugs found in the M1 audit are worth remembering for the class of mistake, not the fix:

1. **Nothing ever saved.** `save_data()` had exactly one caller — `reset_progress()`. Every
   mutator changed memory only, so a normal quit dropped all progress. The M1 tests missed it by
   calling `save_data()` by hand before reloading: they proved serialization worked, never that
   the game invoked it. Worse, `cleared_levels` was wiped each quit, so relaunching re-awarded
   first-clear gold — turning deliberately-finite gold into an infinite farm.
2. **Stale lives on the pre-round HUD.** `start_new_round()` didn't reset `base_health`, so after
   a loss the readout sat at "Lives: 0/20" until Start was pressed. Gameplay was correct; only
   the display lied.
3. **`start_new_round()` doesn't emit `round_started`** (only `_start_round()` does), so the
   result panel stayed on screen after Play Again. Fixed by hiding it in the handler that
   changes the state rather than trusting a lifecycle signal to cover every entry point.

The enemy rename (`zombie` → `goblin` under the medieval theme) is approved and scheduled for
**A2**, alongside the new enemy types and the three remaining abilities.

`implementation_plan.md` is now a **design reference**, not a roadmap — its phase numbering is
superseded by the three stages above, but its tower and enemy design tables are still the source
of truth for what those things are.

Build UI *after* gameplay: a Godot `Theme` cascades project-wide, so retrofitting style is
cheap. Retrofitting **structure** is not — so make managers signal-driven from day one
(`silver_changed`, `wave_started`), even when the only listener is a raw `Label`.

---

## Gotchas

- **The scene file is `levels/level_01.tscn` but its ROOT NODE is still named `map1`** — renaming
  a file doesn't rename the node inside it. So the runtime path is still `/root/map1`, and
  `get_node("/root/level_01")` fails. Rename the node when convenient; until then expect the
  mismatch.
- **Runtime errors go to `debugger_get_log`, NOT `editor_get_console`.** On Godot 4.5+
  `editor_get_console` shows the *editor's* console: it catches parse and load errors, but a
  running game's `push_error`/runtime errors do not appear there. **Checking the wrong stream and
  reporting "zero errors" is the easiest false negative available in this project** — it happened
  through all of A1 before being caught in A2's R-0. Use `debugger_get_log` (optionally
  `text_filter: "ERROR"`) to verify a playtest; use `editor_get_console` for compile/parse state.
- **`node_call_method` is editor-only.** For a *running* game it is `execute_code`. Bind the map
  with `scope_path` (`/root/map1`) to call its methods unqualified and to dodge the Variant
  property-chaining limitation.
- **A new `class_name` is invisible until the editor rescans.** `script_check` reports
  `Identifier 'Enemy' not declared` on every consumer until you call `editor_refresh`. Not a code
  error — a stale filesystem cache.
- **A ~5s round trip is longer than a 12s breather feels.** Three consecutive polls showing an
  unchanged wave and an empty board is usually a breather, not a stall. Read `phase` before
  concluding anything is stuck.
- **Autoloads are unreachable as bare identifiers in `execute_code`** — `PlayerData.silver` fails
  with "Invalid named index". Address them by node path: `get_node("/root/PlayerData").get("silver")`.
- **An explicit `.name` on a button is not enough to make its path guessable.** `round_ui`'s
  buttons are named, but their procedurally created *parents* are not — the real path looks like
  `RoundUI/@Panel@24/@VBoxContainer@25/PlayAgainButton`, and the indices shift whenever a panel is
  added. Resolve at runtime with `find_child("Name", true, false).get_path()`, then feed that to
  `click_node`.
- **`set_anchors_preset()` alone leaves a procedurally created Control at size (0,0)** — children
  anchored to it then centre on an empty rect and land off-screen. Set `anchor_*` **and**
  `offset_*` explicitly. Cost an hour on the ability bar.
- **MCP round trips are ~5 seconds.** Anything shorter-lived than that cannot be observed by
  polling — a 3s cooldown always reads as 0 by the next call. Two techniques that work:
  `get_tree().set("paused", true)` to freeze mid-animation for a screenshot, and holding a round
  open indefinitely by giving the wave manager nothing to resolve.
- **To hold a round open for inspection:** with no enemies alive, `_check_round_complete()` never
  fires, so the round sits in `IN_ROUND` forever. `get_tree().set_group("zombie", "speed", 0.0)`
  freezes the horde in place — but it freezes them *where they currently are*, not at the spawn
  point, so sample a live zombie's position rather than assuming where the cluster is.
- The main scene is `levels/level_01.tscn` (`uid://c4tocub30g0w`). `testbed/clean_area.tscn` is a stripped-down
  test harness that implements the same `get_flow_direction` / `is_wall` contract — if you
  change that contract, update it too, or its enemies break.
- `zombie.gd` reaches its map via `get_parent()` and reads `map.end_point` directly. Enemies
  must stay direct children of the map node.
- Spawning is triggered by a `StartButton`, not automatically. `_on_start_button_pressed`
  hides it and calls `_start_round()`; `start_new_round()` (Play Again) shows it again — a
  round can be replayed indefinitely, this is no longer one-shot.
- MCP scene edits are in-memory until `editor_save_scene()`.
- `execute_code`'s expression-only sandbox can't run statements (`var`, `for`, lambdas with
  `return`), can't chain property access on a returned object (`node.get_child(0).damage`
  fails — use `runtime_get_script_vars`/`node_get_property`, or `.get("damage")` on a
  directly-addressed node instead), and can't call `load()`/`preload()`. To mutate state that
  needs a loop, either issue one call per iteration or lean on a Dictionary/Array method that
  does the iteration internally (e.g. `dict.merge({...}, true)` beats a loop of `dict[k] = v`).
- **`input_simulate`'s `click_node` emits `pressed` directly and bypasses a Button's `disabled`
  flag** — a disabled button still runs its handler under this tool. Never trust a widget's
  disabled state as the only guard; verify state after a forced action instead, and put an
  authoritative check in the handler itself for anything that's a real rule (see
  `round_ui._on_upgrade_pressed()`).
- **`get_global_mouse_position()` is not reliably driven by `input_simulate`'s `mouse_motion` /
  `mouse_button` `position`/`world_position` fields in this environment** — repeated attempts to
  calibrate it (linear regression on known screen->world pairs, the `click` composite) produced
  inconsistent, sometimes physically nonsensical results (negative scale, mismatched axes). It
  appeared to read some leftover value unrelated to the injected coordinate. This means **you
  cannot reliably drive a click-and-drag onto a *specific* world cell via MCP input simulation**
  — don't spend time calibrating it further; it burned a real amount of effort during the tower
  move/remove work before being identified as a tooling limitation, not a code defect. What
  *does* work: `click_node` for Buttons (exact node path, no coordinates), and driving game-state
  transitions directly via `execute_code` calling the same functions `_input()` would call
  (`begin_move()`, `place_tower()`, etc.) — this exercises the real logic, just not the input
  routing that dispatches to it. If you need to verify `_input()`'s own branching, a coordinate
  that only needs to land "somewhere invalid" (e.g. far off the tilemap) is more likely to
  produce a meaningful result than one that needs to land on a specific valid cell — but confirm
  what actually happened via state, not just an event's `dispatched: true`.
