# Medieval Horde Defense

An incremental tower-defense game in **Godot 4.6**, inspired by *Sir, We Have an Orc Problem!*
You defend a keep against overwhelming undead hordes using medieval towers. Failed runs still
earn permanent upgrades.

**Status: playable core loop (M1 complete).** Pathfinding, swarm AI, tower building, the
silver/gold economy, permanent upgrades, round win/lose and `user://` persistence all work —
you can place towers, kill for silver, clear a level for gold, buy upgrades, and replay.

Not yet built: **progressive waves** (single wave only), **cooldown abilities** (the sole
planned in-round input), multiple enemy types, multiple maps, and any real art or UI theme.
That's M2 onward — see Build order.

---

## Direction (decided 2026-09-03 — do not re-litigate)

| Question | Decision |
|---|---|
| Theme | **Medieval** — castles, catapults, undead. |
| Player character | **Pure tower defense.** No player unit. |
| Meta-progression | **Yes** — permanent upgrades, `user://` save. Currencies are silver + gold; there is no "souls". |
| In-round play | **Cooldown abilities.** Towers are pre-placed and auto-fire; abilities are the only live input. |

**The `game/asserts/` art is shelved.** There are ~148 PNGs of classroom / school-horror art
(a 2D classroom pack, a "limp" character, a school interior) bought in Aug 2026. They do **not**
match the medieval direction and are unused. Every sprite in the running game is a 100–300 byte
placeholder. Don't wire the classroom art into anything; don't delete it either.

`player.gd`, `player.tscn` and `test.tscn` are **orphaned by decision**, not by accident.
They're slated for removal — don't build on them.

Full roadmap: [implementation_plan.md](implementation_plan.md). It predates these decisions,
so its "User Review Required" section is now answered by the table above.

Tower removal + moving: [tower_editing_plan.md](tower_editing_plan.md) — a ready-to-implement
work order, not yet built. Closes the gap opened by making towers persist (there is currently
no way to remove or reposition a placed tower).

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

| Persistent (`user://` save, `PlayerData`) | Round-scoped (discarded, `map1`/`base_health`) |
|---|---|
| silver, gold | `round_state`, `zombies_to_resolve` |
| upgrade level per tower type | lives (`base_health.lives`) |
| unlocked tower types | placed tower instances (`map1.towers_by_cell`) |
| levels already cleared (gold-once ledger) | current wave (M2 — not built yet) |
| placement slot count | ability cooldowns (M2 — not built yet) |

This split is implemented, not just planned — `base_health.gd` and `map1.gd`'s round-lifecycle
fields never write to `PlayerData`, and nothing in `PlayerData`/`TowerStats` reads round state.

### When the save actually gets written

`PlayerData` mutators set a `_dirty` flag; they do **not** write to disk. Flushing happens at
three checkpoints, via `save_if_dirty()`:

| Checkpoint | Where | Why there |
|---|---|---|
| Round end (win *or* loss) | `map1._end_round()` | One write per round instead of one per kill |
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
├── implementation_plan.md   ← phased roadmap
├── ui_plan.md                ← zero-asset UI plan (theme, HUD, screens)
├── rules_for_godot_mcp.md   ← MCP toolkit reference
├── .mcp.json                ← MCP config (see MCP setup below)
└── game/                    ← the Godot project (project.godot lives HERE, not at root)
    ├── scenes/              ← 15 .tscn
    ├── scripts/             ← 16 .gd — 4 autoload-or-round-owned (player_data, tower_stats,
    │                           base_health, round_ui) added for M1, none are scene-attached
    ├── asserts/             ← art (sic — typo is load-bearing, paths reference it)
    └── addons/godot_mcp_toolkit/   ← 277 files, vendored; not your code
```

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
`map1.gd` runs a BFS out from `EndPoint` across every non-wall cell, then converts the cost
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
`map1.gd` rebuilds a **spatial grid** every physics frame: `zombie_grid` maps a 32px cell to a
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

### Round lifecycle

`map1.gd` owns a `RoundState` enum (`PRE_ROUND` → `IN_ROUND` → `ROUND_WON`/`ROUND_LOST`) and
is the level controller — there is no separate `wave_manager.gd` yet (that's M2; M1 is
deliberately single-wave).

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
  die. Those get force-cleared via `_clear_all_zombies()`. `spawn_zombies()`'s loop also checks
  `round_state` between spawns, so it stops feeding a round that already ended.
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
- **Gold-once is enforced by `PlayerData.award_level_gold`**, not by `map1` — `_end_round(true)`
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
- Debug output goes through `print()` gated on an export flag (`map1.gd` has `debug_logging`).
  **Never `FileAccess.open("res://…", WRITE)`** — see Known issues #1.
- Prefer MCP `node_set_property` + `editor_save_scene` over hand-editing `.tscn`.

---

## Performance: the open problem

Measured on this machine, `map1`, enemies spawned instantly:

| Enemies | FPS (before fixes) | FPS (now) |
|---|---|---|
| 50 | 53 | **60** |
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

**Recommended next attempt:** stop giving every enemy its own `_physics_process`. Move the
whole horde into a single manager loop on `map1` that updates all enemies in one tight pass.
That removes 600 per-node script invocations and 600 sets of cross-object `map.` dispatches
per frame, which is the largest remaining structural cost. If that isn't enough, the horde
needs to leave GDScript entirely (MultiMesh + a compute-style update, or GDExtension).

Do not claim the perf problem is fixed without a measured 600-enemy screenshot.

---

## Known issues

Fixed and verified: collision layers, the `res://` export crash, per-frame disk I/O, the
per-enemy spawn flush, `fire.gd`'s global group scan, the separation architecture, the
archer's jitter-clobbering (retired along with the @export stats it was fighting over), and
the archer/wizard stat asymmetry (both now resolve from `TowerStats`).

Still open, roughly by value:

1. `arrow.gd:12` — `queue_free()` with no `return`; keeps attaching a timer to a freed node.
   **One-word fix.** (`fire.gd` already does this correctly — copy it.)
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
5. `TileMap` is deprecated as of Godot 4.3; this project targets 4.6. Migrate to `TileMapLayer`.
6. `map1.tscn` has a vestigial empty `TileMap` node alongside the real `my_tiles`.
7. `build_ui.gd` is a dead one-shot `@tool SceneTree` generator; its output is superseded by
   `build_sidebar.gd`, which builds the UI at runtime.
8. Enemy `z_index = 10` draws enemies over towers.
9. The TileMap physics layer generates collision shapes that nothing uses (movement is manual).
10. `asserts/` is a typo for `assets/` — cosmetic, but every resource path depends on it.
11. `.git` is ~107 MB for a small project; the deleted `.docx` files and asset-pack binaries are
    baked into history.
12. `archer.tscn` and `wizard.tscn` carry stale scene-level property overrides (`damage`,
    `wizard_radius`, `rate_of_fire`, `fire_damage_radius`) left over from the pre-`TowerStats`
    exports. Confirmed harmless — Godot silently no-ops setting a property that no longer
    exists on the attached script, verified against a clean console log across a full
    playtest — but worth stripping from the `.tscn` text next time either file is open, so a
    future reader doesn't mistake them for live data.

---

## Build order

Milestones supersede `implementation_plan.md`'s phase ordering, which was written against the
old buy-towers-with-gold economy.

**M1 — close the economic loop (~8h).** Build this first; it proves the design.
1. ✅ `PlayerData` autoload — the persistent table above, save/load to `user://`
2. ✅ `TowerStats` — base stats + upgrade levels → final stats. Silver cost curve:
   `10 * 1.35^level`. Base/level-0 stats set to match the pre-refactor game exactly
   (range 200 both towers, archer 10dmg/0.5s, wizard 3dmg/1.0s/AoE-100) — no balance
   change, just a new source for the same numbers.
3. ✅ Refactor archer + wizard to pull from it. Verified live: fresh-spawn stats match
   `TowerStats` exactly, an upgrade bought mid-session applies to the next tower placed
   (not retroactively — correct, since upgrades only happen between rounds), and a
   one-shot kill confirmed the full chain (`TowerStats` → archer → arrow → `take_damage`).
4. ✅ Round lifecycle — `base_health.gd` (round-scoped lives, never persisted) +
   `map1.gd`'s `RoundState` enum (`PRE_ROUND`/`IN_ROUND`/`ROUND_WON`/`ROUND_LOST`).
   Placement locks the instant a round starts; `zombie.gd` reports its own fate via
   `map.on_zombie_killed(silver_reward)` / `map.on_zombie_escaped()` (has_method-guarded,
   so `clean_area.tscn`'s stripped-down map still works unmodified). A round completes
   the moment every spawned zombie is resolved, by kill **or** escape — "win" means "you
   didn't run out of lives," not "zero escapes."
5. ✅ Lose condition — `lives <= 0` ends the round immediately, force-clears every
   zombie still alive (`_clear_all_zombies()`), and the spawn loop checks `round_state`
   between spawns so it stops feeding a resolved round rather than continuing to spawn
   in the background.
6. ✅ Crude upgrade screen — `round_ui.gd`, one CanvasLayer covering all three M1 UI
   needs (status readout, win/lose result + Play Again, and per-track upgrade buttons
   for both tower types). Explicitly throwaway — UI-0/UI-1 replace every node in it.

**Verified live**, full loop, real button clicks (not just direct method calls): placed
towers on a path-adjacent wall cell for genuine combat, won with 6 kills (12 silver, 0
escapes), replayed the same level for a **second** win to confirm the gold-once ledger
(paid 10g the first time, correctly 0g and "already cleared" on replay while silver still
accrued), bought a real upgrade via `UpgradeButton_archer_damage` (silver 12→2, level
0→1, button label refreshed), then removed all towers and let 25 zombies through
unopposed to confirm the loss path (lives hit exactly 0, round ended before all 25
resolved, the remaining survivors were force-cleared, no gold awarded). Also confirmed
the slot cap (`PlayerData.slot_count`, default 4) actually blocks a 5th placement, and
that raising `slot_count` un-blocks the identical cell — ruled out a coincidentally
invalid cell before trusting the result.

**Two further bugs found in the post-M1 audit** (both invisible to the tests that "verified"
M1 — recorded here because the class of mistake matters more than the fix):

1. **Nothing ever saved.** `save_data()` had exactly one caller: `reset_progress()`. Every
   mutator changed memory only, so a normal quit dropped all silver, gold, upgrades and the
   cleared-levels ledger. The M1 verification missed it by calling `save_data()` manually
   before reloading — proving serialization worked, never proving the game invoked it.
   The nastier consequence was economic, not just lost progress: `cleared_levels` was wiped
   every quit, so **relaunching re-awarded first-clear gold on every level**, turning
   deliberately-finite gold into an infinite farm. Fixed with the dirty-flag + checkpoint
   scheme described in the Economy section; verified by quitting and relaunching for real.
2. **Stale lives on the pre-round HUD.** `start_new_round()` didn't reset `base_health`, so
   after a loss the readout sat at "Lives: 0/20" until Start was pressed. Gameplay was
   correct (`_start_round()` resets); only the display lied. Fixed by resetting in
   `start_new_round()` too and refreshing the label (`base_health.reset()` emits nothing).

**One real bug found during the M1 build pass itself:** `start_new_round()` (the "Play Again"
handler) doesn't emit `round_started` — only `_start_round()` (the Start button) does —
so the result panel stayed on screen after Play Again until the *next* round actually
began. Fixed by hiding it directly in `round_ui.gd`'s button handler rather than relying
on the signal. Caught by clicking through the real flow, not by reading the code — if
you add another "return to pre-round" entry point later, check it hides the result panel
itself; don't assume `round_started` covers it.

At the end of M1: place towers → kill → earn silver → buy +damage → replay → feel the
difference. Single wave, no abilities, no art. **This is done and playable now.** If the
loop isn't satisfying, that's a design problem to raise before Phase 2 content, not a
missing-feature problem.

**M2 — make the round a game (~7h).** Progressive waves, lives, the three cooldown abilities.

**M3 — breadth (~6h).** Gold unlocks, level select, a second map.

**M4 — UI pass (~5h).** Theme + real screens, per [ui_plan.md](ui_plan.md).

Build UI *after* gameplay: a Godot `Theme` cascades project-wide, so retrofitting style is
cheap. Retrofitting **structure** is not — so make managers signal-driven from day one
(`silver_changed`, `wave_started`), even when the only listener is a raw `Label`.

The enemy rename (`zombie` → `goblin` etc. under the medieval theme) is approved but not
started.

---

## Gotchas

- The main scene is `map1.tscn` (`uid://c4tocub30g0w`). `clean_area.tscn` is a stripped-down
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
