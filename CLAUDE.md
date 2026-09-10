# Medieval Horde Defense

An incremental tower-defense game in **Godot 4.6**, inspired by *Sir, We Have an Orc Problem!*
You defend a keep against overwhelming undead hordes using medieval towers. Failed runs still
earn permanent upgrades.

**Status: A1 and A2 complete. A3 PARKED and its remaining work MOVED TO BETA (2026-09-07) —
see [beta_plan.md](beta_plan.md)'s *The horde engine*. A4 (MVP UI) is NEXT and is planned in
full — [a4_plan.md](a4_plan.md).**

A3 shipped one thing before it was parked: **D-1**, which replaced the pairwise separation scan
with a crowd-density field — **−40.7% `us_per_enemy`** at 600 packed, ceiling ~250 -> ~420, no
behavioural change. The horde moves as a continuum now.

**Why it was parked — read this before reviving it.** Waves top out at **152 concurrent enemies**,
which the game already ran at 60 FPS *before* any of A3's work. The enemy ceiling was invisible to
every player, while the actual blocker on shipping sat untouched. **Performance was never what was
stopping this game from being released.** Pathfinding, swarm AI, tower building/removal/moving,
the silver/gold economy, permanent upgrades, round win/lose and `user://` persistence all work.
A1 added **progressive waves** and the **boulder ability** — five escalating waves with a
breather, and a hold-to-aim ability on a 3s cooldown that is the only live input.

A2 so far: the zombie→goblin rename plus the type-neutral `enemy_*` machinery rename, a shared
`class_name Enemy` base with a stat registry, a per-enemy life-cost channel, wave composition,
and **three enemy types — goblin, skeleton, ogre**. Plus a self-measuring bench harness pulled
forward from A3, and **A-1 Rain of Arrows** — the second ability, and the one that introduced
directional (rotatable) aiming.

**A-2 Divine Smite and A-3 Dragon Fire moved from A2 to A6** (2026-09-06) — they were never
blocking A2's headline of enemy variety, and A-1 already built the machinery both need.

Not yet built: the horde engine rewrite, MVP UI, the last two abilities, gold sinks, multiple maps,
any real art. See Build order, and [a2_plan.md](a2_plan.md) for
step-by-step state.

**The game has not shipped to itch yet** — a Windows export exists, but there is no main menu,
no pause, and the upgrade panel is a debug readout bolted to the play screen. That is **A4**.

---

## Direction (decided 2026-09-03 — do not re-litigate)

| Question | Decision |
|---|---|
| Theme | **Medieval** — castles, catapults, undead. |
| Player character | **Pure tower defense.** No player unit. |
| Meta-progression | **Yes** — permanent upgrades, `user://` save. Currencies are silver + gold; there is no "souls". |
| In-round play | **Cooldown abilities.** Towers are pre-placed and auto-fire; abilities are the only live input. |
| Horde movement | **Fluid, not individuals** (decided 2026-09-07) — the horde should read like water pulled through a maze. **Half-delivered:** D-1 made the push a continuum (no pairwise step); the *routing* half — congestion feeding back into the flow field — moved to beta with the rest of the horde engine. |

**The classroom / school-horror art has been deleted** (`dd49e82`) — ~148 PNGs, 106MB, wrong
theme. It is still in git history if ever needed. Every sprite in the running game is a
100–300 byte placeholder awaiting the commissioned medieval art (a beta deliverable — see
`beta_plan.md`).

`player.gd`, `player.tscn`, `test.tscn`, `tile_map.tscn`, `oil_trap.tscn` and `build_ui.gd`
were **deleted** in the same cleanup — all verified orphans. Pure tower defense, no player unit.

**In flight: [a2_plan.md](a2_plan.md)** — enemy variety (goblin/skeleton/ogre), the zombie→goblin
rename, and Rain of Arrows. The other two abilities moved to A6; see that file for progress.

**Planned next: [a4_plan.md](a4_plan.md) — A4, MVP UI.** Main menu, pause, and a real upgrade
screen. It is the only thing between this project and an itch release, and it is fully planned:
scope, the seven-step ladder, the pause policy, and the acceptance flow (menu -> play -> lose ->
*understand the silver was kept* -> upgrade -> win).

**[a3_plan.md](a3_plan.md) is PARKED and is now a record, not a work order** — the horde engine
moved to [beta_plan.md](beta_plan.md) on 2026-09-07. **Read a3_plan's opening section before
touching the crowd code anyway:** it holds D-1's full measurement record and four dead ends that
were each bought expensively, and it overturns the diagnosis recorded under Performance below.

Dissolving A3 orphaned two items, both rehomed: the **TileMapLayer migration is now A7's** (see
Known issue 5) and **overlapping waves is now A6's** (D-1's headroom means it no longer needs the
horde rewrite).

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

**This is now a release blocker, not a polish task.** A1 is built and exported but has not
shipped, because the game has no main menu, no pause, and an upgrade panel bolted to the play
screen. `alpha_plan.md` gained a dedicated stage — **A4 — MVP UI** — to fix exactly that, which
renumbered the old A4/A5 to A5/A6. **A second renumber followed on 2026-09-08**, when A5 —
the pre-ship polish stage (tower art + settings menu) — was inserted, pushing those two to A6/A7.

**A4 IS COMPLETE (2026-09-08) — see [a4_plan.md](a4_plan.md).** All six steps shipped: theme,
pause, HUD, result screen, main menu, upgrade screen, and `round_ui.gd` deleted. **The ship gate is
met:** the game boots to a menu, plays, pauses, ends on a result screen that tells a losing player
their silver was kept, has an upgrade shop reachable from two places, and shows no debug UI
anywhere. **A4 was the only thing blocking an itch release.**

**A5 — pre-ship polish — is IN PROGRESS: [a5_plan.md](a5_plan.md).** Art, audio, effects, a
settings menu, player-controlled camera zoom/pan, and export hygiene. It carries the **asset
manifest**: 12 art files, 16 audio files, 9 effects, with exact paths and pixel sizes.

**Where it stands (2026-09-09):** the **art import is 10/12 done and verified** — both towers with
firing animations, all three enemies with run animations, arrow, fireball and boulder, plus the
build ghost and sidebar icons. **Outstanding: the wall and floor tiles.** A grass floor was built
and then removed by decision; the generator approach is recorded in a5_plan if it is revisited.

**A5-1 IS DONE (2026-09-10).** The export no longer carries developer tooling: pck **961 KB ->
287 KB**, and the exported process holds **zero network sockets** (verified by `netstat` on its PID,
and by its own log containing no MCP lines where an editor run logs `listening on 127.0.0.1:6570`).
The WebSocket listener turned out to be **already guarded** by the addon; the real leak was orphaned
`.gdc` bytecode under `script_export_mode=2`, closed with a hand-written `exclude_filter`. The game
is now **"Medieval Horde Defense"**, not "game". See a5_plan.md's A5-1 DONE block.

**A5-2 through A5-4 are NOT started**, and one of them is blocked:
- **There is still no audio at all**, and none has been supplied, so A5-2 and the audio half of the
  settings screen are blocked on files. Three things
from it that contradict older notes: `/root/map1` **survives** a main menu if scenes are replaced
rather than nested; pause needs **one** `PROCESS_MODE_ALWAYS` exception rather than four
per-system rules; and A4 deliberately takes only `ui_plan`'s UI-0 + a trimmed UI-1 + UI-4, leaving
UI-2/3/5 to beta.

*(`ui_plan.md`'s "souls" reference was corrected on 2026-09-08 — silver and gold only.)*

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
| silver, gold | `round_state`, `enemies_to_resolve` |
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
├── a4_plan.md               ← DONE: MVP UI (menu, pause, HUD, result, upgrades)
├── a5_plan.md               ← NEXT: pre-ship polish + the ASSET MANIFEST
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
    │   ├── enemies/enemy.gd     ← the SHARED base (class_name Enemy). NOT in a per-type
    │   │                          folder: goblin/skeleton/ogre are scenes pointing at it.
    │   │                          The one documented exception to colocation.
    │   ├── enemies/goblin/      goblin.tscn        (no script of its own)
    │   ├── enemies/skeleton/    skeleton.tscn      (ditto)
    │   ├── enemies/ogre/        ogre.tscn          (ditto)
    │   ├── abilities/boulder/   boulder.tscn/.gd       (A1; no PNG yet — see Known issues)
    │   ├── abilities/rain_of_arrows/  rain_of_arrows.tscn/.gd  (A2's A-1; reuses the
    │   │                          archer's arrow.png — a documented colocation exception)
    │   └── projectiles/         arrow/, fire/
    ├── levels/              ← level_01.tscn + tilesets/my_tiles.tscn
    ├── systems/             ← level_controller.gd (shared by ALL levels), base_health.gd,
    │                          wave_manager.gd, ability_manager.gd, enemy_types.gd,
    │                          bench.gd (dev-only horde benchmark)
    ├── ui/                  ← palette.gd + build_theme.gd -> game_theme.tres (A4's U-0),
    │                          pause_menu/ (U-1), hud/ (U-2), result_screen/ (U-3),
    │                          main_menu/ (U-4, THE BOOT SCENE), upgrade_screen/
    │                          (U-5), build_sidebar/, ghost_tower/, aim_marker/,
    │                          ability_bar/
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

**There are TWO tilemaps in `level_01`, and only one of them is the game.** `my_tiles` is the
**logic layer** — 50px cells, `visible = false`, and the ONLY thing `level_controller` reads
(`@onready var tile_map: TileMap = $my_tiles`). `grass_biome` is **cosmetic only** — 8px cells at
scale 1.0, drawn but never queried. The two lattices do not divide evenly (50 / 8 = 6.25), so they
cannot be merged by a scale value; that is why the split exists.

`my_tiles`'s wall cells are **DERIVED from `grass_biome`**, not hand-drawn: a 50px cell is a wall
when its wall-grass area >= its floor-grass area, computed by exact rectangle overlap. On the
2026-09-09 map that yields **175 wall cells and 156 floor cells**, and the painted walls seal the
play area with no leaks — so no artificial boundary ring is needed, and towers stay buildable
only where wall art actually is. Because the logic lattice is 6.25x coarser than the art, the
collision edge can sit up to **25px** from the grass edge the player sees. That is the accepted cost
of the split; it goes away only when the tiles are re-authored at 16px / scale 3.125 per a5_plan's
manifest, at which point one lattice can serve both.

### Enemy movement
Enemies are `Area2D` and move themselves by assigning `global_position`. **There is no physics
movement anywhere** — no `move_and_slide`, no rigid bodies. Wall collision is a manual
`map.is_wall()` point test with per-axis sliding.

### Separation is a DENSITY FIELD, not a neighbour scan (A3's D-1)

**Enemies never look at each other.** `enemy.gd::_separation()` and its 3×3 grid scan were deleted
in D-1. The horde is now a continuum:

1. `level_controller._rebuild_enemy_grid()` **scatters** each enemy's mass of 1.0 into
   `_enemy_density`, a flat `PackedFloat32Array`, using cloud-in-cell (bilinear) weights — 4 writes,
   O(1), no pairwise anything.
2. Each enemy **gathers** the local gradient through `map.get_density_push(pos)` — 4 reads — and
   moves down it.

Measured **−40.7%** `us_per_enemy` at 600 packed, and it is what makes the horde read as fluid
rather than as N individuals shoving. See a3_plan.md's *D-1*.

Rules that still bite here:

1. **NEVER alias `_enemy_density` into a local, and never let an enemy cache it.**
   `PackedFloat32Array` is copy-on-write, so a second holder makes the next write deep-copy the
   whole array — per enemy, per frame. That is why the push is fetched through a **method call**
   rather than by exposing the array. It is the same trap that made `PackedVector2Array` unusable
   for the old grid cells.
2. **Subtract the self-force.** An enemy reads a field containing its own deposit, and the CIC
   self-contribution is not zero — leaving it in pulls every enemy identically toward a cell
   corner and **crystallises the horde onto a 32px lattice**. It is removed analytically in
   `get_density_push()`. The invariant: **one enemy alone on the map must get exactly
   `Vector2.ZERO`.** Test that first if the crowd ever looks wrong.
3. **Scatter and gather must share one lattice.** Both go through `_density_coords()`. A half-cell
   disagreement is a silent constant bias in every push direction.
4. **`enemy_grid_nodes` still exists and is still needed** — splash damage and tower targeting ask
   *which* nodes are nearby, which a density field cannot answer. Only the separation path became a
   field read. Its old twin `enemy_grid` (parallel enemy *positions*) is **deleted**; it had exactly
   one reader and that reader is gone.
5. **Never touch a node reference in a per-enemy loop.** `other.global_position` is a Variant
   dynamic dispatch; that alone cost ~15× at 600 enemies under the old scan, and the rebuild loop
   still pays one such read per enemy.

The two registry flags map straight across, and both were verified by probe, not by reading code:
`separation_weight` (ogre 0.15) scales the **gradient response**, so the ogre still ploughs a lane
while depositing full mass; `ignore_separation` (skeleton) **skips the gather**, so the skeleton
still slides through a crowd it still shifts. The scatter loop has no type branch at all.

### Collision layers
Named in Project Settings. Every `Area2D` sets these explicitly — **if you add a new Area2D,
set them, or you reintroduce the O(n²) collapse.**

| Layer | Name | Who is on it | Who masks it |
|---|---|---|---|
| 1 | `enemies` | enemies | tower ranges, projectiles |
| 2 | `tower_range` | archer / wizard detectors | — |
| 3 | `projectiles` | arrow / fire | — |

**Layers 1 and 2 are now unused.** A3's S-1 made enemies plain `Node2D` — they have no physics
presence at all — and towers find them through `map.get_enemies_in_radius()` instead of
`get_overlapping_areas()`. Projectiles hit by distance test, not `area_entered`. The layer numbers
are deliberately NOT renumbered; the tower CollisionShape2D nodes are left in their scenes as
vestigial. **A new Area2D still needs its layers set** — the O(n^2) warning below stands for
anything that rejoins the broadphase.

Enemies have **`monitoring = false`** — they detect nothing. Detection is done *to* them by
towers and projectiles. Crowd push comes from the density field, not from overlap queries.

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

### Enemy types (A2)

**`systems/enemy_types.gd`** is the single source of truth for enemy numbers — a `DEFAULTS` dict
plus a `TYPES` dict where each entry states only what makes it unusual (`"goblin": {}` inherits
everything). `Enemy._resolve_stats()` reads it at `_ready()`, exactly as the towers resolve from
`TowerStats`.

**Nothing is `@export`ed except `enemy_id`.** A `.tscn` carries identity and visuals, never stats
— so a new enemy is a registry row plus a scene with **no script of its own**. Goblin, skeleton
and ogre all point at `enemy.gd`.

| | max_hp | speed | silver | life_cost | ignore_sep | sep_weight |
|---|---|---|---|---|---|---|
| goblin | 10 | 100 | 2 | 1 | false | 1.0 |
| skeleton | 6 | 280 | 2 | 1 | **true** | 1.0 |
| ogre | **80** | 100 | 12 | **3** | false | **0.15** |

- **`ignore_separation`** is an early-out, so a skeleton is *cheaper* per frame than a goblin, not
  dearer. It slides through the crowd instead of queueing behind it.
- **`separation_weight`** scales how hard an enemy is pushed *by* others while it still pushes
  them normally (it contributes its position to the grid like anything else). That asymmetry lets
  the ogre plough a lane, and costs one float multiply with **no change to the spatial grid**.
- **The two registry halves live in different files deliberately.** `enemy_types.gd` holds numbers
  and contains **no `preload`**; the scene preloads live in `wave_manager.ENEMY_SCENES`. If the
  stats file preloaded the scenes (which use `enemy.gd`, which preloads the stats) GDScript would
  refuse the cycle. `wave_manager._assert_registries_agree()` checks the key sets match at setup.
- **Behaviour hooks** `_on_spawn()` / `_on_damaged(amount)` / `_on_death()` are empty in the base
  and **event-level, never per-frame**. Type differences that survive A3's manager-loop rewrite
  are *data it can branch on*, not methods it must dispatch. Don't add a per-frame virtual.

### The enemy contract (A2 R-0)

`entities/enemies/enemy.gd` declares **`class_name Enemy`** — the shared base for every enemy
type. Two things live on it that the rest of the game depends on:

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
  `map.enemies_to_resolve` with the new wave's count, and `_begin_breather()` pre-reserves the
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

### Abilities (A1, extended by A2's A-1)

`systems/ability_manager.gd`, round-scoped. Two entries in its `ABILITIES` registry: the boulder
(A1) and Rain of Arrows (A2's A-1). The registry, per-ability cooldown dict and selection bar were
built in A1 for one ability precisely so the second cost almost nothing — and that mostly held.

**What adding an ability actually costs, measured on A-1:**

- A **point-aimed** ability is **one registry entry plus one payload folder**, with no other change
  to `ability_manager`. A-1 shipped that way first and every consumer worked untouched: the bar
  built its slot, `KEY_2` selected, the aim marker sized itself.
- A new **aiming model** costs `ability_manager` and `aim_marker` too — **once per model, not once
  per ability.** A-1's rectangle is what proved this half. The next directional ability is a
  registry row again.

**Aim modes.** `"aim_mode"` in a registry entry, defaulting to `"point"`:

| Mode | Behaviour |
|---|---|
| `"point"` (default) | Marker follows the cursor; release casts where it sits. Boulder. |
| `"directional"` | Press pins an anchor, moving the cursor **rotates** the payload about it, release casts. Rain of Arrows. |

**Preview geometry is read off the payload script**, never duplicated in the manager — the rule
that keeps the aim preview from drifting from the real damage volume. `SHAPE` is an **optional**
const (`"circle"` default, plus `"rect"`), read via **`get_script_constant_map()`** rather than
`payload.SHAPE`: a missing optional constant is an *error* under direct access but a clean default
through the map. `boulder.gd` declares only `RADIUS` and never had to learn any of this existed.

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
- **`entities/abilities/rain_of_arrows/`** — A2's A-1. A **rotatable rectangle** (`LENGTH` 260 ×
  `WIDTH` 90) that ticks 4 damage every 0.25s for 3s, on a 30s cooldown. Press pins the base edge,
  the cursor swings the far end around it, release casts. **Length is fixed and the cursor sets the
  angle only**, so the covered area cannot be inflated by dragging further.
  - **Containment is `to_local()` plus an axis-aligned box test** — `0 ≤ x ≤ LENGTH`,
    `abs(y) ≤ WIDTH/2`. Rotation falls out of the node transform for free, so no angle is stored
    twice and there is no trigonometry to get wrong.
  - **The grid is queried from the rectangle's CENTRE with its half-diagonal** (~138px), not from
    the base with its full length (260). Much tighter bound, so the box test rejects far fewer.
  - **Falling arrows are cosmetic only.** Damage is the box test; where a sprite lands has no
    effect on it. Keep it that way — tying damage to the visual would put `randf()` inside a
    system this project verifies by exact measurement.
- **`ui/aim_marker/`** draws the *selected* ability's shape and dimensions, handed in by the
  manager from the payload script that owns them, so the preview cannot drift from the real blast.
  `SHAPE` was specced for A-3 and landed at A-1; it is general, not a Rain-specific branch, so
  Dragon Fire can inherit it rather than shipping its planned fixed left→right axis.
- **`ui/ability_bar/`** is its own scene, deliberately not part of the since-deleted `round_ui.gd` — it is
  a permanent UI element (ui_plan UI-1), so building it inside the throwaway means building it
  twice. `build_sidebar` is the precedent.
- Ability kills route through `enemy.gd`'s `_die()` → `map.on_enemy_killed()` like any other kill;
  silver needed no wiring for either payload.

**The multi-tick payload rule (A2's A-1).** Boulder lives 0.5s, but a 3s barrage — and A-3's
strafing run — can still be alive when a round ends. So:

> **Any payload that ticks more than once checks the round at the top of every tick and frees
> itself otherwise**, and re-checks `is_instance_valid()` on **every** tick, not once at spawn.

`in`-guarded on `round_state`, so `clean_area.tscn` — which has no round lifecycle — still runs
payloads unmodified, the same tolerance `enemy.gd` extends it. `is_instance_valid()` per tick
matters because a 3s barrage reads a grid rebuilt ~180 times underneath it: Known issue 1b
stretched over time rather than over a single frame.

**A payload must not read `global_position` or `global_rotation` in `_ready()`.** `cast()` calls
`add_child()` — which runs `_ready()` — **before** assigning either, so a payload reading its own
transform there sees the origin and a zero angle. Boulder touches only `sprite.position` in
`_ready()` and reads `global_position` at impact; rain reads both per tick. **This is the single
easiest way to break a new ability**, and directional aiming doubled the surface.

### Pause (A4's U-1)

**The entire policy is one line: everything inherits; only `ui/pause_menu/` is
`PROCESS_MODE_ALWAYS`.**

Nothing else in the project sets `process_mode` at all, so `get_tree().paused = true` already
stops the horde, both of `wave_manager`'s Timers, `ability_manager`'s cooldown tick and node-bound
Tweens. Verified by state, not by looking: an enemy position and an ability cooldown were both
byte-identical after 12s paused, and the breather `Timer` sat **0.93s from firing for 15 seconds**
without firing, then resumed normally.

Three things that a later change could quietly break:

- **Never give the HUD `PROCESS_MODE_ALWAYS`** — it would keep animating behind the pause screen.
  Keep it on its own `CanvasLayer` at the default mode.
- **The pause input handler must live on the `ALWAYS` node.** On a paused node it never runs, and
  the only way out of a pause is to kill the process.
- **Every cooldown, timer and duration must be DELTA-ACCUMULATED, never a wall-clock deadline.**
  `Time.get_ticks_msec()` targets survive a pause and snap to zero on resume. `ability_manager`
  does `remaining = max(remaining - delta, 0.0)`, which is why it freezes correctly.

`pause_menu` emits `resume_requested` / `restart_requested` / `quit_requested`; `level_controller`
decides what they mean. **Restart goes through `start_new_round()`** — the same path "Play Again"
uses — and `resume()` runs *before* the signal, because restarting into a still-paused tree is a
soft lock that looks exactly like a crash. Pausing is armed only inside a round, matching the rule
that abilities are inert outside `IN_ROUND`.

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
- **Enemies report their own fate.** `enemy.gd`'s `_die()` calls
  `map.on_enemy_killed(silver_reward)`; `_escape()` calls `map.on_enemy_escaped(life_cost)`. Both are
  `has_method`-guarded on the map side, so `clean_area.tscn`'s stripped-down test harness (no
  round lifecycle at all) still runs enemies unmodified.
- **A round completes when `enemies_to_resolve` hits 0** — every spawned enemy has been either
  killed or has escaped. "Won" means "you didn't run out of lives," **not** "zero escapes." A
  round with 25 spawned and 3 escaped (17 lives left) is still a win.
- **A loss short-circuits.** The instant `lives <= 0`, `_end_round(false)` fires immediately —
  it does not wait for the remaining spawned-but-unresolved enemies to individually escape or
  die. Those get force-cleared via `_clear_all_enemies()`, and `wave_manager.abort()` stops both
  the spawn and breather timers so nothing feeds a round that already ended.
  Note `on_enemy_escaped()` returns *before* forwarding to `wave_manager.on_enemy_resolved()`,
  so the loss wins the race against a wave completing on the same escape. That is deliberate, and
  it means `enemies_to_resolve` and `wave_remaining` can differ by exactly 1 at the moment of a
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
  button, does). `round_ui.gd` learned this the hard way, and A4's HUD learned it again: hide UI state reactively in the
  handler that changes it, don't assume a lifecycle signal covers every entry point back to
  the same state.
- **Upgrades are locked outside `PRE_ROUND`**, enforced in two places: the buttons' `disabled`
  flag, and an authoritative guard in `upgrade_screen._on_upgrade_pressed()`. The guard is not
  redundant — a disabled Button still runs its `pressed` handler if something emits the signal
  directly (which `input_simulate`'s `click_node` does, and which silently defeated the first
  version of this test).
- **Gold-once is enforced by `PlayerData.award_level_gold`**, not by `level_controller` — `_end_round(true)`
  calls it and only forwards the *actual* amount paid (0 on a replay) through `round_ended`'s
  `gold_awarded` param. Never infer "gold was paid" from `won == true` alone.

### The UI layer (A4)

`round_ui.gd` — the M1-only throwaway that carried status, result and upgrades on one CanvasLayer
— **was deleted at A4's U-6.** Four scenes replaced it, each on its own `CanvasLayer` and each
signal-driven with no polling:

| Scene | Owns |
|---|---|
| `ui/hud/` | silver / gold / lives / wave, controls hint, breather + skip, the Upgrades button, FPS behind a flag |
| `ui/pause_menu/` | Resume / Restart / Quit to Menu / Quit to Desktop. **The only `PROCESS_MODE_ALWAYS` node in the project** |
| `ui/result_screen/` | win/lose, waves, kills, silver, gold — and the line telling a loser their silver was kept |
| `ui/upgrade_screen/` | the shop. Self-contained (autoloads only), so the SAME scene serves the main menu and a level |
| `ui/main_menu/` | the boot scene: Begin Defense / Upgrades / Quit, plus persistent currencies |

**Procedurally created buttons still need explicit `.name`s** (`UpgradeButton_<type>_<track>`) so
they are addressable by path for testing — anonymous `Control`s get auto-generated names like
`@Button@42`, gettable at runtime via `node.find_child("Name", true, false)` but not guessable in
advance. The upgrade screen generates its rows from `TOWER_TYPES x UPGRADE_TRACKS` and names them
for exactly this reason.

---

## Conventions

- **Tabs** for indentation (Godot standard).
- Comments explain *why*, not *what* — especially around the perf-critical density-field code.
- Type-annotate locals in hot loops. `:=` inference fails on values read out of untyped
  containers, which is a compile error, not a warning.
- Debug output goes through `print()` gated on an export flag (`level_controller.gd` has `debug_logging`).
  **Never `FileAccess.open("res://…", WRITE)`** — see Known issues #1.
- Prefer MCP `node_set_property` + `editor_save_scene` over hand-editing `.tscn`.
- **A sprite's world size is a GAMEPLAY number when the entity has a `hit_radius`.** An enemy's
  sprite must measure exactly `2 x hit_radius` in world px (goblin 32, skeleton 30, ogre 70), because
  since A3's S-1 projectiles hit by distance test against that value. Break the equality and the
  hitbox silently stops matching what the player sees; change `hit_radius` to suit new art and it is
  a difficulty change that per-wave silver will detect.
- **FLIP directional art, do not rotate it — unless the sprite has no "up".** Every character here
  (both tower units, all three enemies) is drawn 3/4-overhead with a head above a body, so rotating
  one makes it read as lying on its side; `flip_h` keeps it upright. An arrow is the exception and
  correctly rotates, because it is an object aligned with its own flight. **The test is whether the
  sprite has an implied vertical, not whether it is directional.**
- **Animation on anything that exists in bulk must write only on CHANGE.** Up to 152 enemies animate
  per frame; assigning `sprite.frame` unconditionally would be ~150 redundant Variant property
  writes a frame. Cache the current frame and assign only when it differs. Derive the frame rate
  from DISTANCE travelled, not time, or fast and slow enemies animate at the same cadence.
- **A tower's appearance is derived in three places and must never be duplicated in any of them** —
  the placed tower, the build ghost (`ui/ghost_tower/`) and the sidebar icon
  (`ui/build_sidebar/`). The latter two **instantiate the real tower scene**; the ghost tints it and
  the sidebar renders it into a `SubViewport`. Both set **`PROCESS_MODE_DISABLED` before
  `add_child`**, because a tower scene is a *live* tower that would otherwise join `tower_unit`,
  start its fire Timer and spawn projectiles. Compositing textures by hand instead is what let the
  old ghost drift to a hardcoded scale of 3 and 9.
- **NEVER edit `ui/game_theme.tres` by hand — it is generated.** Edit `ui/palette.gd` and re-run:
  ```
  Godot_v4.6.3-stable_win64.exe --headless --path "<repo>/game" --script res://ui/build_theme.gd
  ```
  The whole look resolves from ~20 constants in `palette.gd`, so the aesthetic is a parameter, not
  an architecture. A hand-edited `.tres` is a merge-conflict magnet of sub-resource ids and would
  be silently overwritten by the next regeneration.
- **Build every new panel CONTENT-SIZED** (`PanelContainer` sizing to its child), never with a
  hardcoded height. A fixed size is a latent break every time the palette moves — UI-0 broke two of
  `round_ui`'s three panels the moment the theme landed. Let the theme's stylebox content margins
  do the padding instead of manual insets.
- **NEVER write a `.tscn` with a text-mode file API on Windows.** Python's `open(p, "w")`
  translates `
` to `

` — **including newlines INSIDE a quoted multi-line string property**.
  Godot then renders the stray `
` as an extra line break. This silently corrupted four scenes
  during A4; only the HUD's multi-line controls hint was visible enough to notice, showing as
  double-spaced text with a Label minimum height of 92px instead of 54px. Use binary mode, or
  `newline=""`, and normalise with `content.replace(b"

", b"
")` if it has already happened.
- **Line endings are MIXED in this project**, so MCP `script_edit` — which matches byte-for-byte —
  fails with a bare `NOT_FOUND` that looks like a typo when an `old_string` carries the wrong
  endings. Check the file before assuming the text moved.

---

## Performance — NOT the open problem, and not alpha's problem

> [!IMPORTANT]
> **Parked 2026-09-07. The remaining horde work moved to [beta_plan.md](beta_plan.md).**
>
> This section is long, detailed, and easy to mistake for a call to action. It is not one.
> **Waves top out at 152 concurrent enemies and the ceiling is ~420** — the game has roughly 2.7x
> the headroom it uses. Everything below is about a horde that has not been designed yet.
>
> **The genuinely load-bearing parts are the RULES, not the targets:** the density-field rules
> under Architecture, the "ruled out" list (each item was bought expensively), and the measurement
> protocol at the bottom. Read those before touching the crowd code. Ignore the 1500-enemy target
> until beta.

Measured on this machine, `level_01`, enemies spawned instantly:

| Enemies | FPS (before fixes) | FPS (now) |
|---|---|---|
| 50 | 53 | **60** |
| 152 (A1 wave 5, live round) | — | **60** |
| 200 | — | **57** |
| 600 | 2 | **4** |

**The practical budget is ~200–250 enemies.** Beyond that the framerate falls off a cliff, and
the falloff is super-linear in *density*, not in count.

**The FPS table above is legacy — prefer the bench figure.** Current measured baseline, taken with
`systems/bench.gd` after A2 closed (post-E-5, post-A-1), 600 enemies at the `packed` lattice:

| Metric | Value |
|---|---|
| `us_per_enemy` | **66.7** |
| `phys_ms` p50 / p95 | 40.00 / 52.24 |
| Ceiling at 60 Hz (`16600 / us_per_enemy`) | **~249 enemies** |

The trend across A2 is worth knowing: **59.3 (pre-E-1) → 60.6 (post-E-1) → 66.7 (post-A2)**. Note
`frame_ms` p50 sat at 133.33 for all three while `phys_ms` rose 10% — the vsync-quantisation trap,
visible in this project's own data. **None of that drift is attributable yet, because the noise
floor has still never been established** (three identical runs were called for; three have been
taken, but across three different builds). Establishing it is the first task of a3_plan's M-1.

The cost *was* isolated to `enemy.gd::_separation()`. Confirmed by probe: at 600 enemies, with
separation disabled the game ran at **60 FPS** (rendering 600 sprites is free); enabling it
dropped to 2–4. **That function no longer exists** — D-1 replaced it with a density-field read and
measured −40.7%. The paragraphs below describe the architecture it replaced.

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

> [!IMPORTANT]
> **MEASURED at a3_plan's M-1 (2026-09-06). The old "recommended next attempt" — move the horde
> into a single manager loop — was WRONG, and the numbers now bound how wrong.**
>
> Full ablation at 600 enemies, `packed`, one run per process (see the protocol note below):
>
> | Cost | µs/enemy | Share |
> |---|---|---|
> | Separation | **25.5** | 39% |
> | **`global_position` write → Area2D transform sync** | **12.2** | 19% |
> | Spatial-grid rebuild | **11.5** | 18% |
> | Dispatch + broadphase presence + group scan | 6.5 | 10% |
> | `is_wall()` + normalize + call overhead | ~5.3 | 8% |
> | Flow-field lookup (incl. its 2 `tile_map.` calls) | 3.8 | 6% |
> | **Total (V0)** | **65.6** | 100% |
>
> **A manager loop can only touch the 6.5 floor, and not all of it — at most ~10%,** against a
> target that needs 83%. It remains a prerequisite for later work; it is not the fix.
>
> **The biggest surprise: assigning `global_position` costs 12.2 µs/enemy — 19% of the frame.**
> Measured by an ablation that keeps `is_wall()` but skips the write. The enemies are *frozen* in
> that test, so it is writing the same value it already holds.
>
> **It is NOT the physics sync.** That was the first guess, and S-1 disproved it by retiring the
> Area2D entirely: the broadphase emptied (`phys_pairs` 180 → 0) and the frame cost did not move.
> The 12.2 is the engine's transform-set path — dirty flags, notifications, the setter — which a
> plain Node2D pays identically. **Only writing the transform less often, or owning no node at
> all, can remove it.**
>
> The 24-cap null result is explained: the nine-cell scaffolding is paid **in full by an enemy with
> zero neighbours**, so no inner-loop cap can reduce it.

> [!IMPORTANT]
> **The ranked list below is superseded as a strategy.** It is a list of ways to make the existing
> per-agent neighbour scan *cheaper*; the decided direction is to **delete that scan** by moving
> the horde to a density-field (fluid) formulation. See a3_plan.md's *THE DIRECTION TO TAKE NEXT*.
>
> **Why that is not just a style change:** the pairwise 3x3 neighbour scan is what makes the horde
> look like individuals shoving each other AND what costs 25.5 µs/enemy. Continuum/density
> formulations have no pairwise step at all — each agent adds its density to a grid (O(1)) and
> reads the gradient back (O(1)). One change targets both the 25.5 scan and most of the 11.5
> grid rebuild, because a density grid is a flat `PackedFloat32Array` rather than ~200 freshly
> allocated Arrays per frame.
>
> **Independent confirmation of the ceiling:** public Godot 4 boid projects measure **~300 agents**
> for CPU-per-agent versus **7,000–32,000** on a compute shader. This project measures ~250.
> **The current architecture is at its natural limit; micro-optimisation will not reach 1500.**
>
> A2's registry survives the change: `separation_weight` becomes the gradient-response multiplier
> (the ogre still ploughs a lane) and `ignore_separation` becomes "skip the gradient read" (the
> skeleton still slides through). Splash queries keep `enemy_grid_nodes` — only the *separation*
> path becomes a field read.

> [!NOTE]
> **DONE, AND IT WORKED — A3's D-1, 2026-09-07.** The density-field rewrite shipped. `us_per_enemy`
> at 600 `packed` went **168.7 -> 100.1, a 40.7% reduction**, measured as three-run means taken
> back-to-back in one sitting on `BENCH_TAG "M-0b"`. `loose` at 190 went 136.5 -> 112.5 (−17.6%).
> Two full rounds before and after produced **the same two outcomes in the opposite order**
> (906/20-lives and 900/17-lives, both WON), with per-wave silver reconciling exactly.
>
> **Absolute figures from this session are ~3x the earlier documented ones because the machine was
> downclocked to 1200 MHz of a 2401 MHz maximum.** Cross-session drift on this hardware is a factor
> of 3, not the 14% recorded below. **Only ratios travel between sessions.**
>
> This does **not** reach 1500 enemies. What remains is per-node engine overhead, which is still
> X-\* (de-nodify + MultiMesh). See a3_plan.md's *D-1* for the full record.

**Kept for reference — ways to shave the scan D-1 deleted** (a3_plan's original ladder, now history):

1. **Separation** — 25.5 µs/enemy. **But not by flattening the grid to kill hashing:** P-2 did
   exactly that experiment (single-probe `get()` in place of `has()`-then-`[]`) and measured
   **−3.9%, inside the noise band**. Hashing is not separation's dominant cost. The remaining
   suspects are the inner-loop arithmetic and the Variant boxing on every position read out of an
   untyped Array. Re-target before spending a commit.
2. ~~**The Area2D presence**~~ — **tried, and it bought nothing.** S-1 shipped: `phys_pairs` went
   180 → 0 and node count 1845 → 1250, and `us_per_enemy` did not move (54.1 → 57.2, inside noise).
   The 12.2 µs/enemy is the engine's **transform-set path**, not the physics sync — a plain Node2D
   pays it too. **No node-type change removes it; only not owning a node does.** That is A3's X-*
   (de-nodify + MultiMesh).
3. **Grid rebuild** — 11.5 µs/enemy. Persistent buckets + an enemy registry (P-3).
4. **Cell conversion** — ~9 µs/enemy, but **mostly inside `is_wall`, not the flow lookup** (P-1).
   An implementation that only caches `get_flow_direction` captures less than half of it.

Even with separation made *entirely free* the loop still costs 40.1 µs/enemy, against the ≤11.1
that 1500 enemies would need — so the non-separation path needs a 3.6× reduction on its own. If
the ladder does not get there, the horde leaves GDScript (MultiMesh + a compute-style update, or
GDExtension).

> [!CAUTION]
> **THE BENCH HAS A MEASUREMENT BUG. Every number in the table above is suspect until it is fixed
> and the ladder re-measured.** Found 2026-09-07; see a3_plan.md's *SOLVED — the "degradation" was
> never real*.
>
> **`Performance.TIME_PHYSICS_PROCESS` updates far more slowly than once per frame, and
> `bench.gd` samples it once per frame.** Every run's early samples therefore carry the
> **previous** run's value. Proven by dumping `_phys_samples` from a V5 run started right after a
> V0 run: the first **33 of 180 samples were a frozen 46.229** (V0's figure) before dropping to
> V5's real 3.76 — 93+ frames of stale data, counting the warm-up.
>
> **This means the previously documented "+45% within-process degradation" was never real**, and
> the protocol built on it was backwards:
>
> | Run | Preceded by | Residue | Bias |
> |---|---|---|---|
> | 1st in a process | an idle game | low | reads **too LOW** |
> | 2nd, 3rd... | the previous heavy run | high | reads **too HIGH** |
>
> "Only the first run is trustworthy" made the *most* contaminated run the reference. It also
> explains why idling never recovered it, and why S-1 emptying the broadphase changed nothing.
>
> **Contamination scales inversely with run length** (a fixed number of stale frames is a bigger
> share of a short run), so the light variants V4/V5 are distorted hardest — which is why they
> looked deceptively "flat" back to back.
>
> **FIXED 2026-09-07, `BENCH_TAG` now `M-0b`.** Sampling counts **distinct monitor updates, not
> frames**; warm-up waits for observed changes rather than a frame count. Self-test: a V5 run
> straight after a V0 run read **48.65 / 81.1** before the fix and **5.2** after, against a
> fresh-process V5 of 5.1. Six V0 runs back-to-back went from `67.5 / 98.3 / 94.3` (+45%,
> monotonic) to `60.2 / 58.3 / 54.4 / 53.3 / 58.8 / 50.5` (no trend).
>
> **The table above still needs re-deriving** — every figure in it was produced by the buggy
> sampler, and the bias was worse for short runs, so the ablation subtractions are distorted.
>
> **New protocol.** Back-to-back runs are fine; **no restart per measurement**. Take three runs and
> use the mean: ~±7% on one run, ~±4% on a three-run mean, and now *unbiased* — the error averages
> out instead of depending on whatever ran before. **Rows tagged `M-0` must never be compared
> against `M-0b` rows.**

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

1. ~~**The archer's damage upgrade track is inert.**~~ **CLOSED by A2's ogre (E-5).** Against a
   10 HP goblin, +2 archer damage changed nothing (12 and 14 still one-shot it). Against an 80 HP
   ogre, base damage 10 is eight shots and each upgrade removes one. **Verified live 2026-09-06**,
   not merely reasoned: a real ogre took 7 hits of 10 and survived on 10 HP, dying on the 8th; at
   12 it survived 6 on 8 HP and died on the 7th. `TowerStats` resolves archer damage to exactly 10
   and 12 at upgrade levels 0 and 1. **Note what was NOT done:**
   raising goblin HP was measured and rejected — it is a binary cliff, not a dial (at HP 16 the
   archer needs two shots, roughly halving its DPS, and a fresh-save round went from a comfortable
   win to a loss at wave 4). Adding a high-HP enemy fixed the track without touching the curve.
   **Don't "helpfully" raise goblin HP.**
1b. **Freed-node access through the spatial grid — FIXED, but read this before touching the
   grid.** `enemy_grid_nodes` caches node references at rebuild time; splash damage reads
   them later in the same frame, by which point other kills may have freed them. This crashed
   in real play (`get_zombies_in_radius: Invalid access ... 'previously freed'`, two wizards on
   a dense cluster). Guarded now in three places: skip queued/invalid on grid rebuild, and
   `is_instance_valid()` in both `get_enemies_in_radius()` and `fire.gd`'s damage loop. Any new
   consumer of `enemy_grid_nodes` needs the same guard. (The old parallel positions array,
   `enemy_grid`, was deleted by D-1 — it was safe, but it had only one reader and that reader is
   gone.)
1c. **`lives_depleted` is emitted and connected to nothing.** `base_health.gd` declares and emits
   it; nothing listens. The loss is actually driven by an inline `if base_health.lives <= 0` check
   inside `level_controller.on_enemy_escaped()`. **Not a live bug** — `on_enemy_escaped()` is the
   only caller of `lose_life()` and it checks immediately after — but it is the same shape as M1's
   `save_data()` trap: a mechanism that looks like the one in charge, wired to nothing. Add a
   second way to lose lives (a boss attack, a timer, a self-damage effect) and it will silently
   fail to end the round. Found in A2 step 11 by calling `lose_life(20)` directly and watching the
   round carry on. **Either connect it or delete it.**
2. Flow field charges `cost + 1` for diagonals → Chebyshev distances, so diagonal routes are
   under-priced and paths skew.
3. `is_wall()` tests only the enemy's centre point, so bodies clip wall corners.
4. ~~`place_tower` marks one cell occupied but the wizard sprite is 9x scale — towers visually
   overlap.~~ **CLOSED 2026-09-08** by A5's wizard art import: every tower sprite is now scale 1.0
   on a 64x64 texture, so a tower overhangs its 50px cell by 7px a side instead of by four cells.
5. `TileMap` is deprecated as of Godot 4.3 (project targets 4.6). **Migration is deliberately
   deferred — do not "helpfully" do it.** Deprecated is not removed; it works fine in 4.6. The
   rule has always been: **bundle it with the horde rewrite, or do it immediately before building
   levels 2–15 — whichever comes first.**
   **As of 2026-09-07 that resolves to A7, and A7 owns it.** The horde rewrite moved to beta, so
   the levels come first. This was an orphan created by dissolving A3 and is deliberately recorded
   in three places (here, alpha_plan's A3 and A7 entries) because it is exactly the kind of
   dependency a re-plan drops silently.
   Affected calls, all in `level_controller.gd`: `get_used_cells(0)`, `local_to_map`,
   `map_to_local`, `get_used_rect`. Note the `0` in `get_used_cells(0)` is a layer index that
   ceases to exist under `TileMapLayer`, where the node *is* the layer.
6. The TileMap physics layer generates collision shapes that nothing uses (movement is manual).
7. ~~`archer.tscn` carries a leftover `position = Vector2(329, 98)`.~~ **CLOSED 2026-09-08** —
   removed during A5's archer art import, along with the `(0, -60)` visual offset in
   `archer_tower.gd`. The real art is a 64x64 top-down platform with a 64x64 archer meant to stand
   in its middle, so both now share a centre and neither is nudged.
8b. **Rain of Arrows reuses the archer's `arrow.png`** rather than owning a copy — a **deliberate
   exception to colocation**, on the grounds that these are the same object: replacing the
   archer's arrow should re-skin the barrage too, and two copies would let them silently diverge.
   Its ground-zone rectangle is still the shared `1_pixel.png`. If the artist wants them to differ,
   drop an `arrow.png` into `entities/abilities/rain_of_arrows/` and repoint the `preload`.
8. ~~**The boulder has no PNG of its own.**~~ **CLOSED 2026-09-08** — `boulder.png` (16x16) landed
   in A5 at `scale = 2.5` (40 world px) with the brown modulate removed. The colocation brief
   ("replace the PNG in each entity folder") worked exactly as intended: a drop-in file plus a
   scale.

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

The **horde engine rewrite** (massive battles) was scheduled mid-alpha as A3. **It moved to beta
on 2026-09-07**, after D-1 raised the ceiling from ~250 to ~420 and made it obvious the ceiling
was never what blocked shipping. It is still the largest single item in the roadmap and the
biggest technical unknown — timebox it and keep the current GDScript horde as a fallback, so worst
case the game has smaller battles rather than no schedule.

**One hard ordering constraint the move created:** `X-*` (de-nodify + MultiMesh) changes how enemy
*art is drawn*, so it must land **before** beta's full art integration or the enemy half of that
integration gets done twice. See beta_plan.md.

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

**A3 — big battles.** ⏸️ **PARKED 2026-09-07; the remainder moved to
[beta_plan.md](beta_plan.md)'s *The horde engine*.**

**D-1 shipped and stays** — density-gradient separation, the stage's only measured win: −40.7%
`us_per_enemy` at 600 packed, −17.6% at loose, with two before/after rounds producing the same two
outcomes in the opposite order. The horde is a continuum now: enemies deposit into a density field
and read its gradient, and never look at each other. Also shipped: a bench measurement bugfix, and
M-1/P-2/S-1, **all three of which produced no gain** but refuted the proposed cause of the two
largest costs (see a3_plan.md's *Where A3 actually stands*).

**Parked because it was invisible.** Waves top out at 152 concurrent enemies, which the game
already ran at 60 FPS before any of it. The remaining cost is inherent to one-Node-per-enemy,
which only de-nodify/MultiMesh addresses — a big, risky item that earns its keep in beta, where a
huge horde is a store-page screenshot, and not in alpha, where it was blocking nothing.

**Two orphans rehomed:** the TileMapLayer migration to **A7** (Known issue 5), overlapping waves
to **A6** (D-1's headroom means it no longer needs the rewrite).

**A4 is next.**

**A2 — enemy variety.** ✅ Done and verified; see [a2_plan.md](a2_plan.md) for the work order and
step-by-step state. **Shipped: R-0 (contract hardening), R-1 + R-2 (both renames), M-0 (bench
harness), E-1 (enemy registry), E-2 (life cost), E-3 (wave composition), E-4 (skeleton), E-5
(ogre), A-1 (Rain of Arrows), and the step-11 tune/verify pass.** **A-2 Divine Smite and A-3
Dragon Fire moved to A6.** A2 is closed.

**Step 11 verified two things worth carrying forward.** Both proof cases passed: losing mid-wave
with ogres and skeletons in flight leaves no stale `_spawn_plan` and no ghost spawns on restart;
and a barrage, a boulder mid-arc and wizard fireballs all overlapping a force-cleared board
produced zero errors.

**A fresh save now LOSES level_01 at wave 4, and that is deliberate — do not "fix" it by cutting
enemy counts** (explicit decision, 2026-09-06). Four base archers fire 8 shots/sec; wave 4 delivers
~16.7 enemies/sec. Upgrades are what close that gap, which is exactly what the economy section
means by tuning each level against an assumed upgrade level. The loop closes correctly — the lost
round still banks its silver (422 measured), and that silver buys the win. **A1's "a fresh save
lost four lives" figure is dead** and must not be quoted: it predates skeletons, ogres, and the
`SKELETON_PACK` fix.

What this *does* expose belongs to **A4**: a new player's first game is a loss, and the result
screen says only "Round Lost" — it never explains that their silver was kept.

**Two defects found while verifying E-5, both in `_build_waves()`, both fixed** — and both worth
the class of mistake rather than the fix:

- **Scaled wave totals drifted +1** on waves 3 and 5, because each group was rounded
  independently so the errors accumulated instead of cancelling. It only appeared once E-5 added a
  **third** group — with two, they happened to cancel. Fixed with largest-remainder apportionment;
  totals are again exactly the authored curve × scale (32/48/72/104/152, 408 spawned).
- **`SKELETON_PACK` was inert.** `_build_waves()` dropped the `pack` key, and `_build_spawn_plan()`
  reads `pack` off the groups *that function produces* — so every pack silently degraded to 1 and
  skeletons had never once arrived as a squad, in any round played or measured. **E-4's acceptance
  criterion was that wave totals stay on the authored curve, and this bug does not affect totals
  at all.** An acceptance check that only reads the aggregate cannot see a defect in the
  *arrangement*. Fixing it is a real difficulty change: the same round now loses 12/20 lives
  instead of 14/20.

Three more lessons from A2's enemy track:

4. **A refactor's acceptance criterion should be a number, not a vibe.** E-1, E-2 and E-3 were
   each verified by "a full round is numerically identical: 816 silver = 408 kills, won, 20/20".
   That one figure caught nothing — which is exactly the point. It made "I didn't break anything"
   checkable rather than asserted.
5. **Keep a content change from becoming a difficulty change.** Skeletons and ogres *replace*
   goblins rather than adding to them, so every wave total stays on the authored curve
   (20/30/45/65/95). A2 could then still be compared against A1's tuning instead of needing a
   fresh baseline.
6. **The scene-data trap closed itself.** R-0 moved group membership from `.tscn` into
   `Enemy._ready()`. Two commits later, skeleton and ogre scenes were created — and neither
   *could* forget the group. That is the difference between a rule and a guarantee.

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
**A2**, alongside the new enemy types and Rain of Arrows.

`implementation_plan.md` is now a **design reference**, not a roadmap — its phase numbering is
superseded by the three stages above, but its tower and enemy design tables are still the source
of truth for what those things are.

Build UI *after* gameplay: a Godot `Theme` cascades project-wide, so retrofitting style is
cheap. Retrofitting **structure** is not — so make managers signal-driven from day one
(`silver_changed`, `wave_started`), even when the only listener is a raw `Label`.

---

## Gotchas

- **THE GAME NOW BOOTS TO A MENU, NOT A LEVEL.** `run/main_scene` is
  `res://ui/main_menu/main_menu.tscn` (A4's U-4), so `game_start` with `scene_path: "main"` lands
  on the menu with **no `/root/map1`**. Two ways through it, both verified: `game_start` with
  `scene_path: "res://levels/level_01.tscn"` to go straight to a playable level, or `click_node`
  on `/root/MainMenu/Backdrop/Center/Card/Rows/BeginButton`.
- **`/root/map1` STILL RESOLVES once a level is loaded, and that is deliberate.** Scene transitions
  use `change_scene_to_file()`, which frees the old scene and makes the new one a **direct child of
  root** — so the level's root node stays `map1` at `/root/map1` and every path in this document
  keeps working. **Never make the menu a resident overlay above the level:** it would push the
  level down a level and invalidate every `scope_path` and verification snippet here.
- **`get_tree().paused` is tree-wide and SURVIVES a scene change.** Always unpause before
  `change_scene_to_file()`, or the next scene loads paused with dead buttons. Both the pause screen
  and the result screen call `resume()` before emitting.
- **REPAINTING `grass_biome` DOES NOT CHANGE THE GAME, AND FAILS SILENTLY.** The art layer and the
  logic layer are separate nodes (see Flow-field pathfinding); `level_controller` reads only
  `my_tiles`. Editing the map in `grass_biome` alone leaves `walls_dict` stale — and *clearing*
  `my_tiles` empties it, which cost a session on 2026-09-09: **`walls_dict` 0, `flow_field` 1 cell,
  density grid collapsed 53x31 -> 6x6**, no tower placeable anywhere, `is_wall()` false everywhere,
  and every enemy on `enemy.gd`'s zero-flow fallback (a straight beeline at `end_point` through
  walls) — 32 spawned, 0 kills, 20/20 lives gone in wave 1. **Nothing errors.** The `flow_field`
  collapse is the sneakiest part: the BFS bounds itself with `tile_map.get_used_rect().grow(15)`,
  and an EMPTY used_rect grows to (-15,-15)..(15,15), which does not contain the end cell (21, 8).
  After any map edit, re-derive `my_tiles` and check **`walls_dict.size()` and `flow_field.size()`
  are both non-trivial** before concluding anything else is wrong.
- **`application/config/name` IS WHAT `user://` RESOLVES FROM. Never change it after shipping.**
  It moved the save directory from `app_userdata/game/` to `app_userdata/Medieval Horde Defense/`
  when A5-1 renamed the project. Doing that to a released build orphans every player's `save.json`
  silently — they see a brand-new game. It was safe on 2026-09-10 only because nothing had shipped.
- **The editor holds ProjectSettings IN MEMORY and rewrites `project.godot` on save.** Editing that
  file on disk while the editor is open left `project_get_settings` still reporting the old value,
  which would have been written back over the edit. Use `project_set_setting`, which persists via
  `ProjectSettings.save()` so both copies agree.
- **`systems/bench.gd` is excluded from the export, and `level_controller` must keep using `load()`,
  not `preload()`, to build it.** `preload()` resolves at COMPILE time, so it binds the file into
  `level_controller`'s dependency closure — excluding an preloaded file is a parse failure of the
  whole game, not a missing bench. The `if OS.has_feature("editor")` guard and the
  `exclude_filter` entry are a PAIR; undoing either alone breaks the export.
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
- **The bench harness measures the game for you: `/root/map1/Bench`.** `call("run", 600, "packed")`
  then read `result_line` via `runtime_get_script_vars`. Headline stat is **`us_per_enemy`**;
  Headline stat is `us_per_enemy`. **The protocol below replaced an earlier one that was exactly
  backwards** — "only the FIRST run is trustworthy, restart between every measurement" was an
  artefact of the monitor-lag bug and is now simply wrong. **Back-to-back runs are valid; take
  three and use the mean** (~±7% on one run, ~±4% on three, and unbiased).
  **Absolute figures do not travel between sessions.** This machine downclocks — 1200 MHz of a
  2401 MHz maximum was observed for a whole sitting, making that session's numbers ~3x another's.
  **Compare ratios measured in one sitting, never absolutes across sittings.** Always re-measure
  the "before" immediately before the change.
  `phys_ms` and `us_per_enemy` come from `Performance.TIME_PHYSICS_PROCESS`; `frame_ms` is
  worthless in the overloaded regime (see the next bullet). Configs: `loose` (45px, fits only ~195
  on level_01 — pass n=190) and `packed` (20px, fits ~955). `Enemy.bench_variant` drives the V0–V5
  ablation ladder; **`reset()` it or the horde stays crippled.** A 600-enemy run can take 10+
  minutes of wall clock on a downclocked machine.
- **The bench's `frame_ms` is NOT wall-clock time.** It reads exactly 133.33 in every V0 `packed`
  row ever recorded, which is 8 x 16.67 — Godot's `max_physics_steps_per_frame` clamp. Measured
  during a D-1 run: 13 real frames in six minutes, i.e. frames ~4s apart, while `frame_ms` reported
  7.5 fps. So `frame_ms` is decoupled from elapsed time in the overloaded regime, and `phys_ms` is
  a per-main-iteration total covering up to 8 physics steps rather than a per-tick cost. Ratios are
  unaffected (both sides clamp identically); **`16600 / us_per_enemy` as "the enemy ceiling" is not
  yet re-verified against this.**
- **A slow warm-up counter is not a hang, and not a regression.** A 600-enemy bench run advances
  `_frames_seen` a handful of frames per minute on this machine. During D-1 that briefly looked
  like a catastrophic slowdown; reading `Bench._last_phys` (the live monitor value) showed physics
  was in fact 40% *faster*. **Read `_last_phys` before diagnosing anything from the frame counter.**
- **A benchmark's lattice must sit on the flow field, not merely off walls.** The first version
  seeded at StartPoint and filtered on `not is_wall()`, which put ~350 of 600 enemies off-map
  where `get_flow_direction()` returns zero — and those take a *more expensive* branch every
  frame. It measured the wrong code path and failed its own self-test. Filter on
  `flow_field.has(cell)`.
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
- **`Input.is_action_just_pressed()` POLLS — `set_input_as_handled()` cannot suppress it.** These
  are two different input paths, and mixing them silently breaks key handling. `ui/fps_counter.gd`
  polled `ui_cancel` and called `get_tree().quit()`; when U-1 put the pause screen on the same key,
  **Escape opened the pause menu AND quit the process in the same frame.** Prefer `_input` /
  `_unhandled_input` for anything a UI layer might need to consume.
- **A feature bound to an input is not tested until the INPUT is tested.** U-1's pause was verified
  by calling `pause()` directly and shipped with Escape quitting the game. Drive the real key with
  `input_simulate` (`{"event_type": "action", "event_data": {"action": "...", "pressed": true}}`).
- **`start_new_round()` does not emit `round_started`, and it has now caught this project THREE
  times** — the result panel stayed on screen, the lives readout went stale, and the HUD read
  "Wave 5/5" in PRE_ROUND. Any UI holding round-scoped state needs an explicit reset call on that
  path; a lifecycle signal does not cover every entry point back to the same state.
- **The editor rewrites a deleted `.tscn` from its cache on the next filesystem rescan.** Deleting
  `floor_tiles.tscn` while the editor was open, then calling a rescan, brought the file back.
  Re-delete after the rescan and confirm it stayed gone.
- **MCP `scene_get_tree` silently UNDER-REPORTS a hand-written `.tscn`.** `pause_menu.tscn` was
  authored by hand; `scene_get_tree` showed only its first three nodes, with **no error**, through
  a filesystem rescan and a reopen — it looked exactly like a scene that failed to parse. At
  runtime the full tree was present and correct. **Verify a hand-written scene by instantiating it
  and probing `has_node()`, not by reading the editor-side tree.** (This is also the reason
  CLAUDE.md prefers the MCP scene tools for authoring.)
- **A project-wide `Theme` is not a cosmetic change — it resizes every control.** `gui/theme/custom`
  cascades to every `Control`, and the button styleboxes carry content margins Godot's defaults do
  not. When UI-0 landed, `round_ui`'s upgrade panel overflowed its own background by three rows and
  its breather panel dropped to exactly **zero** pixels of slack. **Measure, do not look:** compare
  `control.get_combined_minimum_size()` against `control.size` — the breather panel screenshotted
  fine while being one font tweak from clipping.
- **`set_anchors_preset()` alone leaves a procedurally created Control at size (0,0)** — children
  anchored to it then centre on an empty rect and land off-screen. Set `anchor_*` **and**
  `offset_*` explicitly. Cost an hour on the ability bar.
- **Per-wave silver is the sharpest gameplay regression detector this project has.** It
  reconciles exactly — a wave pays `sum(count x silver_reward)`, so wave 3 is always `+154` and
  wave 4 `+238` at `difficulty_scale` 1.6 with the current composition. **A single missed kill
  shows up as a number.** A3's S-1 shipped two damage regressions that passed `script_check` and
  read correctly; both were caught this way, and one of them (waves 1-3 exact, 4-5 short) pointed
  straight at the mechanism. A "did the round still win?" check would have passed the first bug.
- **Round outcomes are stochastic — do not compare single rounds.** Tower fire intervals jitter
  ±5%, initial delays are random, and target selection is `randi()`. The same build has finished
  at 12/20 and 16/20 lives. Compare **per-wave totals**, which are exact, and take two rounds
  before believing a difference in the final result.
- **Abilities are inert outside `IN_ROUND` — by design, and it will look like a bug.**
  `level_controller._unhandled_input()` returns early unless the round is running, so a number key
  in PRE_ROUND selects nothing and a click aims nothing. Verify ability input *inside* a round, or
  you will chase a routing bug that does not exist.
- **An effect shorter than an MCP round trip cannot be screenshotted live.** A 3s barrage is
  reliably over before the next call lands. Two techniques that work: `get_tree().set("paused",
  true)` **in the same expression** that casts, which freezes a real frame at spawn; or verify
  programmatically instead (child counts, `global_rotation`, resulting HP) and treat the picture
  as illustration. Do not pose a frame by hand and present it as caught live.
- **Cosmetic randomness is fine; damage randomness is not.** Rain of Arrows scatters its arrow
  sprites with `randf()`, but damage is a deterministic box test — so no measurement in this
  project depends on an RNG. Keep that line: a payload whose *footprint* varied per cast would
  make every acceptance figure unreproducible, which is the same argument `_build_spawn_plan()`
  makes for a deterministic interleave over a shuffle.
- **MCP round trips are ~5 seconds.** Anything shorter-lived than that cannot be observed by
  polling — a 3s cooldown always reads as 0 by the next call. Two techniques that work:
  `get_tree().set("paused", true)` to freeze mid-animation for a screenshot, and holding a round
  open indefinitely by giving the wave manager nothing to resolve.
- **To hold a round open for inspection:** with no enemies alive, `_check_round_complete()` never
  fires, so the round sits in `IN_ROUND` forever. `get_tree().set_group("enemy", "speed", 0.0)`
  freezes the horde in place — but it freezes them *where they currently are*, not at the spawn
  point, so sample a live enemy's position rather than assuming where the cluster is.
- The main scene is `levels/level_01.tscn` (`uid://c4tocub30g0w`). `testbed/clean_area.tscn` is a stripped-down
  test harness that implements the same `get_flow_direction` / `is_wall` contract — if you
  change that contract, update it too, or its enemies break.
- `enemy.gd` reaches its map via `get_parent()` and reads `map.end_point` directly. Enemies
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
  `upgrade_screen._on_upgrade_pressed()`).
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
