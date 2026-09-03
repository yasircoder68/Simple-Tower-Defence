# Medieval Horde Defense

An incremental tower-defense game in **Godot 4.6**, inspired by *Sir, We Have an Orc Problem!*
You defend a keep against overwhelming undead hordes using medieval towers. Failed runs still
earn permanent upgrades.

**Status: prototype.** Pathfinding, swarm AI and tower building work. There is no economy,
no lives, no waves, and no win/lose condition yet — enemies reach the end and silently vanish.

---

## Direction (decided 2026-09-03 — do not re-litigate)

| Question | Decision |
|---|---|
| Theme | **Medieval** — castles, catapults, undead. |
| Player character | **Pure tower defense.** No player unit. |
| Meta-progression | **Yes** — roguelite loop, souls currency, permanent upgrades, `user://` save. |

**The `game/asserts/` art is shelved.** There are ~148 PNGs of classroom / school-horror art
(a 2D classroom pack, a "limp" character, a school interior) bought in Aug 2026. They do **not**
match the medieval direction and are unused. Every sprite in the running game is a 100–300 byte
placeholder. Don't wire the classroom art into anything; don't delete it either.

`player.gd`, `player.tscn` and `test.tscn` are **orphaned by decision**, not by accident.
They're slated for removal — don't build on them.

Full roadmap: [implementation_plan.md](implementation_plan.md). It predates these decisions,
so its "User Review Required" section is now answered by the table above.

---

## Layout

```
zombie game prototype 1/
├── CLAUDE.md                ← this file
├── implementation_plan.md   ← phased roadmap
├── rules_for_godot_mcp.md   ← MCP toolkit reference
├── .mcp.json                ← MCP config (see MCP setup below)
└── game/                    ← the Godot project (project.godot lives HERE, not at root)
    ├── scenes/              ← 15 .tscn
    ├── scripts/             ← 12 .gd
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

Asymmetry to be aware of: `archer_tower` has a script exposing `damage` / `rate_of_fire`;
`wizard_tower` has **no script**, so wizard stats are baked into `wizard.tscn`.

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
per-enemy spawn flush, `fire.gd`'s global group scan, and the separation architecture.

Still open, roughly by value:

1. `arrow.gd:12` — `queue_free()` with no `return`; keeps attaching a timer to a freed node.
   **One-word fix.** (`fire.gd` already does this correctly — copy it.)
2. `archer_tower.gd` overwrites the ±5% rate jitter `archer.gd` just applied, then starts the
   timer a second time. The per-archer rate desync is dead; only the initial delay survives.
3. Flow field charges `cost + 1` for diagonals → Chebyshev distances, so diagonal routes are
   under-priced and paths skew.
4. `is_wall()` tests only the enemy's centre point, so bodies clip wall corners.
5. `place_tower` marks exactly one cell occupied, but the wizard sprite is 9× scale — towers
   visually overlap.
6. `wizard_tower.tscn` has no script (see Towers above).
7. `TileMap` is deprecated as of Godot 4.3; this project targets 4.6. Migrate to `TileMapLayer`.
8. `map1.tscn` has a vestigial empty `TileMap` node alongside the real `my_tiles`.
9. `build_ui.gd` is a dead one-shot `@tool SceneTree` generator; its output is superseded by
   `build_sidebar.gd`, which builds the UI at runtime.
10. Enemy `z_index = 10` draws enemies over towers.
11. The TileMap physics layer generates collision shapes that nothing uses (movement is manual).
12. `asserts/` is a typo for `assets/` — cosmetic, but every resource path depends on it.
13. `.git` is ~107 MB for a small project; the deleted `.docx` files and asset-pack binaries are
    baked into history.

---

## Build order

Per `implementation_plan.md`, next up is Phase 1:

1. Economy (gold, tower costs, kill rewards)
2. Base health + game over
3. Wave manager with progressive difficulty
4. Enemy base class refactor (`enemy_base.gd`) — the plan renames `zombie` → `goblin` etc.
   under the medieval theme; that rename is **approved** but not started.

Meta-progression (souls, permanent upgrades, save/load) is Phase 3 and is confirmed in scope,
so write Phase 1–2 systems with the assumption that run state and persistent state are separate.

---

## Gotchas

- The main scene is `map1.tscn` (`uid://c4tocub30g0w`). `clean_area.tscn` is a stripped-down
  test harness that implements the same `get_flow_direction` / `is_wall` contract — if you
  change that contract, update it too, or its enemies break.
- `zombie.gd` reaches its map via `get_parent()` and reads `map.end_point` directly. Enemies
  must stay direct children of the map node.
- Spawning is triggered by a `StartButton`, not automatically. `_on_start_button_pressed`
  hides the button, so a run can only be started once.
- MCP scene edits are in-memory until `editor_save_scene()`.
