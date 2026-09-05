# A3 — "Big Battles" — Implementation Work Order

**Status: planned, not started.** Blocked on A2 (see [a2_plan.md](a2_plan.md)), except the bench
harness, which moves *into* A2 — see *Scope change to A2* below.

**Target: 1500 concurrent enemies at p95 < 16.6 ms**, ~6× today's ceiling. De-nodify and MultiMesh
are in scope from the start (decided with the user). The ladder below is about **attribution
order**, not scope.

**Scope:** `level_controller.gd`, `enemy.gd`, a new `systems/bench.gd`, the two towers, the two
projectiles, `goblin.tscn`, `level_01.tscn`, `my_tiles.tscn`. Bundles the deprecated-TileMap →
TileMapLayer migration (CLAUDE.md Known issue 5) and, as its final step, overlapping waves
(deferred here by [a1_plan.md](a1_plan.md)).

Read [CLAUDE.md](CLAUDE.md) first — *Separation (the perf-critical path)*, *Performance*, *Known
issues* 1b and 5, and *Gotchas*.

---

## The finding that reshapes this stage

CLAUDE.md's *Performance* section currently says:

> **Recommended next attempt:** stop giving every enemy its own `_physics_process`. Move the whole
> horde into a single manager loop... which is the largest remaining structural cost.

**That is wrong, and following it would have produced a sixth consecutive "no change" result.**

Per enemy, per physics frame, in the common open-ground case:

| Cost | Count | Removed by a manager loop? |
|---|---|---|
| `Vector2i`-keyed Dictionary operations | **16–25** | **No — zero removed** |
| `Vector2i` constructions | ~11 | **No** |
| Cross-object `tile_map.` calls | 4 | **No** — same calls, different caller |
| Cross-object `map.` calls | 3 | Softened to self-calls, not removed |
| `_physics_process` Callable dispatch | 1 | **Yes** |
| PhysicsServer2D area transform sync | 1 | **No** — still an Area2D assigning `global_position` |

At 600 enemies that is roughly **10,800 dictionary probes and 6,600 `Vector2i` constructions per
frame**. A manager loop removes one dispatch out of that. It is a real win and a *prerequisite* for
later rungs, but it is not the fix.

**This also explains the project's most confusing datum.** CLAUDE.md records that capping
candidates at 24 per frame produced "no change at all". The reason: the nine-cell scaffolding
(9 `has()` probes, 9 `Vector2i` builds, 2 `range()` setups) is paid **in full by an enemy with zero
neighbours**. No inner-loop cap can touch it. The cost is fixed per-enemy overhead, not
per-neighbour work.

Where the probes come from, precisely:

- `_separation()` — **9** `_grid.has(key)`, always, plus up to **9** `_grid[key]`. The
  `has()`-then-`[]` idiom hashes every key **twice**.
- `get_flow_direction()` — 2 (same double-probe), plus 2 cross-object `tile_map.` calls.
- `is_wall()` — 1, plus 2 more `tile_map.` calls.
- `_rebuild_enemy_grid()` — ~4 more per enemy, and it hashes each key **three** times
  (`has`, then `enemy_grid[key]`, then `enemy_grid_nodes[key]`).

**Correcting that CLAUDE.md paragraph, backed by measured arithmetic, is a deliverable of M-1.**
Leave it and the next person spends a week re-confirming it.

---

## Why measurement comes first

Six optimisations have been attempted on this loop. **Five produced "no change."** The only
measurement that ever produced a number was deleting the feature entirely (600 enemies, separation
off, 60 FPS). The acceptance criterion for the largest item in the roadmap is currently *a
screenshot of an FPS label*.

**FPS is the wrong instrument**, for three reasons that have each already cost this project data:

1. **It is vsync-quantised.** Anything from 3 ms to 16.6 ms of work reports "60". Every
   optimisation on the flat part of the curve reads as "no change" **whether it worked or not**.
   Only two rows of CLAUDE.md's table (57 FPS at 200, 4 FPS at 600) carry information at all.
2. **It is a reciprocal, so it is not additive.** Halving cost at 4 FPS gives 8; the same halving
   at 55 gives 57.5. You cannot say "that removed 3 ms" and predict what the next change buys.
   Frame *time* is linear in work — that is what makes a ladder possible.
3. **Mean hides the tail.** Hitching is what a player feels at the ceiling.

**The tooling constraint that shapes the solution:** MCP's `execute_code` runs through Godot's
`Expression` class and **cannot reach `Engine` or `Performance`**, and rejects statements (no
`var`, no loops). But `runtime_get_script_vars` reads any script member variable off a live node.
**So the game must measure itself into member vars**, and MCP reads them back.

---

## Scope change to A2

**Build the bench harness (M-0) during A2, not A3.** It is purely additive and touches only a hook
in `level_controller`. Three reasons:

- A2's own checks want it — E-1's "a round is numerically identical", E-4's and E-5's "FPS holds
  at peak" are currently screenshot-reads.
- It gets validated on real work before A3 depends on it.
- **The per-enemy numbers above are pre-E-1 and will be stale.** A2 adds `enemy_types.gd`, three
  enemy types, four ability payloads, `ignore_separation`, `separation_weight` and `life_cost`.
  The harness re-baselines for free once E-1 lands.

---

## The ladder

```
M-0/M-1   measure + attribute          ← blocks everything
P-1..P-4  cheap wins, one commit each, each measured
T-1       TileMapLayer migration       ← after P-1, before G-2
G-1       flatten the grid             (kills hashing)
S-1       retire the physics presence  (parallel track)
G-2       single manager loop          (kills dispatch; enables X)
M-2       checkpoint — measured vs 1500
X-*       de-nodify + MultiMesh        (branch)
A3-ship   overlapping waves + re-tune
```

---

## M-0 · The bench harness

`systems/bench.gd`, a round-scoped child of `level_controller` named `Bench`, addressable at
`/root/map1/Bench`.

### What it records — frame time, not FPS

| Field | Source | Why |
|---|---|---|
| `frame_ms_p50/p95/max` | `delta` in `_process`, vsync off | What the player feels |
| `phys_ms_p50/p95` | `Performance.TIME_PHYSICS_PROCESS` | Includes the physics server step |
| **`us_per_enemy`** | `phys_ms_p50 * 1000 / enemy_count` | **The headline number** |
| `phys_pairs` | `PHYSICS_2D_COLLISION_PAIRS` | Proves S-1 did what it claims |
| `node_count` | `OBJECT_NODE_COUNT` | Proves X did what it claims |
| `result_line: String` | preformatted | One `runtime_get_script_vars` returns a paste-ready row |
| `history: Array` | | Several configs per session without re-polling |

**`us_per_enemy` is the only statistic that predicts.** At 60 Hz the physics budget is 16.6 ms, so
`16600 / us_per_enemy` *is* the enemy ceiling. Every rung becomes "27 µs → 11 µs, ceiling
600 → 1500" instead of "felt faster".

**`DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` and `Engine.max_fps = 0` at bench start.**
One line, and the highest-value line in the harness — it turns "60 / 60 / 57 / 4" into a
continuous curve.

### Determinism — do not benchmark through the wave machine

It uses `randf()` scatter, takes 2.5 minutes, the population decays as enemies escape (destroying
the denominator of `us_per_enemy`), and tower fire is jittered.

`bench.run(count: int, config: String)`:

1. Clear the board and towers; set `round_state` so nothing scores.
2. Spawn `count` enemies on a **fixed lattice — no RNG at all**. A lattice beats a seeded RNG: it
   reproduces across engine versions and machines, and it makes **density an explicit parameter**.
3. `speed = 0`. The horde freezes but **the entire measured cost still runs** — separation runs
   before the move, the flow lookup runs, `is_wall(pos + ZERO)` still fires once, the grid still
   rebuilds. Only positional drift is removed, which is the variance you are trying to eliminate.
4. Discard **60 warm-up frames** (instantiation, `_ready()`, texture upload, the physics server
   registering n areas), then sample 180.
5. Compute p50/p95/max, fill `result_line`, append to `history`. Total ~4 seconds — under one MCP
   round trip.

**Two standard configs:**

- **`loose`** (45 px spacing) — most enemies have zero in-radius neighbours. **This is the case the
  scaffolding analysis says dominates, and the case where the 24-cap changed nothing.** Primary.
- **`packed`** (20 px, tighter than `SEPARATION_RADIUS = 32`) — every enemy has ~8 neighbours.
  Bounds the inner loop.

**Density has never been a controlled variable in this project's measurements**, despite CLAUDE.md
stating the falloff is super-linear in density rather than count. That is the largest gap in the
existing data.

Plus **one `live` cross-check per rung** — a real wave-5 board with the real tower loadout — so the
synthetic bench cannot silently drift from the game.

### The harness must pass its own self-test before it is trusted

With separation disabled it must reproduce **~60 FPS / p95 well under 16.6 ms at 600 enemies** —
the one number this project already believes. If it doesn't, the harness is wrong, not the game.
This is A2's "verify the net by breaking it" applied to instrumentation, and it is not optional: a
benchmark that has never reproduced a known result is worth nothing.

**Second self-test:** measure V0 with the ablation branch present versus a build without it. If one
int compare per enemy per frame is detectable, the harness distorts what it measures — and you need
to know that on day one.

**Record a noise floor** from three identical runs; report three significant figures maximum.
Anything smaller than the spread is not a result. Had this existed, "capping at 24: no change at
all" would have been recorded as "no change, ±0.4 ms" — a bounded statement instead of an ambiguous
one.

### Comparability

One machine only; say so in the table header. The game runs as a child of the editor under
`game_start`, and an exported build measures differently — make every claim on the same harness.
Pin `Engine.time_scale = 1`, assert the physics tick is 60, and record it, so a project-setting
change cannot silently invalidate the table. `const BENCH_TAG` bumped per step, with the commit
hash recorded beside it in this file. **Never `FileAccess.open("res://…", WRITE)`** — the table
lives in markdown, in git.

---

## M-1 · Attribution, without touching the inner loop

A single static int checked **once per enemy per frame** at the top of `_physics_process`,
early-returning at successive stages:

| Variant | Behaviour | Isolates, by subtraction from the row above |
|---|---|---|
| V0 | Full | — |
| V1 | Skip `_separation()` | **All of separation** |
| V2 | V1 + skip flow lookup | `get_flow_direction` + its 2 `tile_map.` calls |
| V3 | V2 + skip wall test / move | `is_wall` + its 2 `tile_map.` calls |
| V4 | Return immediately | Script dispatch + the Area2D transform sync |
| V5 | V4 + grid rebuild disabled | Group scan + n Array reallocations |

Six runs give the entire cost breakdown in milliseconds, in one commit, with **zero instrumentation
in any inner loop**.

**Deliverables of this commit:** the baseline table (variants × {200, 400, 600, 900} × {loose,
packed} + one live cross-check), the noise floor, and **the CLAUDE.md correction** — landed with
arithmetic behind it rather than argument.

---

## P-1..P-4 · The cheap wins, ranked by expected value

Predictions. The whole point of M-0/M-1 is that these get replaced by numbers.

**P-1 — Cached cell conversion. Likely the largest, and not previously on anyone's list.**
`get_flow_direction` and `is_wall` each call `tile_map.to_local()` then `tile_map.local_to_map()` —
**4 cross-object calls into an engine node per enemy per frame**, plus transform math. But
`my_tiles` is `scale = (50,50)`, at origin, unrotated, with 1×1 tiles: the entire conversion is
`Vector2i(floori(x/50), floori(y/50))`.

Capture `_cell_size` / `_cell_origin` / `_inv_cell` once in `_ready()` from the TileMap's actual
transform and `tile_set.tile_size`, `assert` no rotation or skew, and compute inline. **Four engine
calls become two integer divisions — and this *deletes* the four hot-path TileMap sites rather than
migrating them** (see T-1).

**P-2 — The `has()` + `[]` double-probe.** Nine redundant re-hashes per enemy per frame in
`_separation`, two more in `get_flow_direction`, and a triple-hash in the rebuild.
`var cell = _grid.get(key)` / `if cell == null: continue` halves dictionary work in the hottest
function.

G-1 throws this away — **do it anyway, because that is precisely its value.** It is a four-line,
revertible **test of G-1's premise**. If halving the probes does not roughly halve
separation-attributable time, then hashing is *not* dominant, the flatten will not pay, and you
have learned that for four lines instead of for two commits.

**P-3 — Enemy registry + persistent buckets.** `enemy_grid.clear()` destroys every per-cell Array
and they are all reallocated every frame; `get_tree().get_nodes_in_group()` allocates a fresh
n-element Array every frame; `enemy_grid_nodes` duplicates the whole structure.

Clear buckets **in place** (iterate values, `.clear()` each) rather than clearing the dictionary —
the map is bounded, so persistent empty buckets are correct and cheaper. Give `level_controller` its
own `_enemies: Array[Node]`, registered from `Enemy._ready()` and deregistered in `_exit_tree()`.
The group stays for towers, `call_group` and `_clear_all_enemies` — purely additive.

**Highest-leverage item on the list, because it is also the architectural seam G-1, G-2 and X all
need.** This is the A1-Step-0 pattern applied to A3: additive, nothing observable changes, so the
risky commits land against a foundation already proven not to move.

**P-4 — The nine rebuilt `Vector2i` offsets and the per-frame `has_method`.**
`const NEIGHBOR_OFFSETS: Array[Vector2i]` with nine entries removes nine constructions per enemy per
frame. And `enemy.gd`'s `map.has_method("get_flow_direction")` is asked **every frame** for an
answer fixed at `_ready()` — probe once into `_has_flow`, exactly as R-0 already did for the round
contract eleven lines above it.

*Caveat:* GDScript specialises `for i in range(<consts>)` into an integer loop, so the `range()`
allocations are probably **already free**. Don't spend a commit on that half without measuring.

*Low confidence:* untyped Arrays cause Variant boxing per candidate read. `Array[Vector2]` is **not**
`PackedVector2Array` and is **not** copy-on-write — say so in the commit message or someone will
revert it citing CLAUDE.md's packed-array rule, which is about a different thing. But a typed Array
retrieved from an untyped Dictionary returns as a Variant anyway, which may eat the gain. Measure;
expect a wash. G-1 fixes this properly.

---

## T-1 · TileMapLayer migration

**Slots immediately after P-1, and before G-2.** P-1 changes the migration's shape: it **deletes**
the four hot-path call sites rather than migrating them. What remains is 11 cold-path sites, all in
`level_controller.gd` — a self-contained commit.

Do not run a deprecation migration and a hot-path rewrite over the same lines in the same window.

- `get_used_cells(0)` → `get_used_cells()`. An arg-count error, so it fails loudly. Safe.
- **`level_01.tscn`'s `layer_0/tile_data` → `tile_map_data` is the real risk** — the entire level
  geometry is one `PackedInt32Array` line. Use Godot 4.3+'s editor conversion action on the selected
  node, then `editor_save_scene`. **Never hand-edit.**
- **Verify by integers, not by looking at it.** `generate_flow_field()` already prints
  `flow field %d cells` under `debug_logging`. Compare **`flow_field.size()`, `walls_dict.size()`
  and `get_used_rect()` as exact integers, pre and post.** A level that loses six tiles looks fine
  and paths wrong.
- **`my_tiles.tscn`'s `scale = Vector2(50,50)` is load-bearing** — it is why one cell = 50 world px,
  and P-1 reads it. The editor conversion may produce a *child* layer node, changing the path.
  **End state must be a single `TileMapLayer` named `my_tiles`, a direct child of `map1`, carrying
  `scale = (50,50)`** — otherwise `$my_tiles`, `place_tower()` and `_cell_at()` all move.
- **Free bonus: delete the TileSet's physics layer.** It generates collision polygons nothing uses
  (movement is manual point-testing) — CLAUDE.md Known issue 6 — and it takes the wall bodies out of
  the same broadphase S-1 is cleaning up. It never gets cheaper than this moment.

---

## G-1 · Flatten the grid

Replace `Dictionary[Vector2i] → Array[Vector2]` (and its duplicate `enemy_grid_nodes`) with a
**counting sort into flat packed arrays**.

Bounds derived once in `generate_flow_field()` from `get_used_rect().grow(15)`, converted to 32 px
grid coordinates, **plus a one-cell apron** so any in-bounds enemy's 3×3 scan stays in range.
Cell index is `(gy - origin.y) * _grid_w + (gx - origin.x)` — a plain int. **All hashing
disappears.**

```
_counts / _starts / _fill : PackedInt32Array
_positions                : PackedVector2Array   bucket-sorted
_indices                  : PackedInt32Array     parallel, index into _enemies
```

Rebuild is three linear passes with zero allocation and zero hashing: count, prefix-sum, place.
All arrays `resize()`d once when capacity grows, never reallocated per frame.

**The payoff:** because cells within a row are consecutive indices and the prefix sum lays buckets
out in index order, **the three cells of a row occupy one contiguous range of `_positions`**. Nine
dictionary probes and nine `Vector2i` constructions become **six `PackedInt32Array` reads and three
tight loops over cache-linear memory** — finally the shape the ruled-out "capping at 24" experiment
assumed it already was.

**This is not the ruled-out packed-array case.** CLAUDE.md's rule is that packed arrays are
copy-on-write and **appending** to one stored in a Dictionary can copy it per append. Here the array
is a **member, written by index, never appended**, resized only on growth. The precise rule to write
into the code:

> **Write through the member (`_positions[i] = p`). Never take a local alias for writing** —
> `var a := _positions` creates a second reference and the next write copies. A local alias for
> *reading* in the inner loop is fine and is faster than repeated member lookup.

Getting this vague rather than precise is what produced the blanket ban that would otherwise block
this design.

**Fallback, named now so it is a decision rather than an improvisation under pressure:** int-keyed
Dictionary (`gy * _grid_w + gx`) with persistent in-place-cleared buckets. Keeps hashing, drops
`Vector2i` construction, ~60% of the benefit for a fraction of the change.

**Rejected: fixed-capacity buckets.** One pass, no prefix sum — but they **silently drop enemies**
past capacity, and at 32 px cells a dense cluster blows past 8 easily. Silent dropping is exactly
the failure class A1 and A2 spent their budgets building nets against.

**Out-of-bounds:** clamp the index and skip separation, with a `push_error` **once per round**.
"Loud once, then correct" beats "loud every frame".

---

## S-1 · Retire the physics presence (parallel track)

`Area2D` → `Node2D`, **keeping the node**. ~30 lines across four scripts and one `.tscn`.

- Towers: `get_overlapping_areas()` + group filter → `map.get_enemies_in_radius(pos, range_px)`.
  That function already exists and answers the same question off the grid, and towers fire at ~2 Hz,
  not per frame.
- Projectiles: `area_entered` → a distance test against the already-homed `target`. Both already
  track a specific target and both already tolerate a dead one.
- `goblin.tscn`: root → `Node2D`, `CollisionShape2D` removed.

**Buys** the per-enemy PhysicsServer2D transform sync (paid today despite `monitoring = false` and
`collision_mask = 0`, because towers need the broadphase) and takes n areas out of the broadphase
entirely. Collision layer 2 (`tower_range`) becomes unused — note it in CLAUDE.md's table rather
than renumbering.

**Keeps** sprites, `.tscn`-per-type, `is_instance_valid`, `take_damage`, `queue_free`, groups,
`call_group`, and A2's entire contract net.

**Risk:** the hit test stops being the enemy's 32-world-px box and becomes a tunable `HIT_RADIUS`
(start ~18). **Acceptance is numeric, not visual:** same round, kill count and lives lost within the
noise floor.

Nearly disjoint from P-1..G-1 — one line of overlap (`extends`). Run it concurrently.

---

## G-2 · Single manager loop

`level_controller` iterates `_enemies` inline; `enemy.gd::_physics_process` is retired. Removes the
per-node Callable dispatch and converts the three cross-object `map.` calls into self-calls.

**The testbed decision is made here, not discovered.** `clean_area.gd` drives enemies through its own
duck-typed `get_flow_direction`/`is_wall` contract. Either it gets a minimal manager or it is
formally retired.

---

## X-* · De-nodify + MultiMesh (branch)

The only rung that cannot be partially landed, so it goes on a branch while trunk keeps shipping the
G-2 engine.

- **Handles become `(slot, generation)`.** Get the generation counter wrong and a stale arrow damages
  a **fresh** enemy occupying a recycled slot — no crash, no error, in a project whose entire A2 R-0
  was about eliminating exactly that class of bug.
- **Eight consumers, not three** — archer, wizard, arrow, fire, boulder, plus A2's `rain_of_arrows`
  (which ticks repeatedly), `divine_smite` (picks highest-HP from a query) and `dragon_fire`.
- **A2's contract net must be re-formed for the index model, not deleted.** `Enemy.GROUP`,
  `ROUND_CONTRACT` and `_assert_enemy_contract()` were all built around nodes and groups. Budget for
  this explicitly — it is the thing most likely to be quietly skipped.
- **Known cost to A2's promise.** "A new enemy is a `.tscn` and a registry entry" degrades: per-type
  sprites need **one MultiMesh per type** (recommended — the type count is small and bounded) or an
  atlas with per-instance custom data (a second unknown stacked on the first). The `.tscn` stops
  being *instantiated* and becomes *read as data* (texture, scale, modulate pulled once at registry
  build). **Record this as a decision now rather than discovering it later.**
- **Free win:** this retires Known issue 1b (freed-node access through the grid) outright — an index
  plus generation cannot dangle.
- **Smoke-test MultiMesh under `gl_compatibility`** (this project's renderer) in the first hour, not
  in week three.

---

## A3-ship · Overlapping waves + re-tune

**A bigger sequential wave is the same fight bigger; overlap is what makes it overwhelming.** This is
the actual A3 headline, and a1_plan deferred it here explicitly.

a1_plan already priced it: a wave tag per enemy and per-wave decrements — *"a real deferred cost, not
a dodged one."* Waves are strictly sequential today precisely so one counter suffices; overlap breaks
that, and `wave_remaining` / `enemies_to_resolve` must become per-wave.

Plus a re-tuned `WAVE_TABLE` and `difficulty_scale` against the measured ceiling, and the measured
600+ screenshot CLAUDE.md demands.

---

## Sequencing

| # | Commit | Done when |
|---|---|---|
| 0 | **M-0** bench harness + ablation seam *(lands in A2)* | `run(600,"loose")` returns a `result_line`. **V1 reproduces ~60 FPS at 600.** Noise floor recorded; variant-branch overhead below it |
| 1 | **M-1** baseline + CLAUDE.md correction | Scaffolding claim confirmed or refuted in ms; the 24-cap null result explained arithmetically |
| 2 | **P-1** cached cell conversion | 20 sampled positions map to identical cells pre/post. Δms recorded vs prediction |
| 3 | **T-1** TileMapLayer migration | `flow_field.size()`, `walls_dict.size()`, `get_used_rect()` **identical integers** pre/post. Towers still place only on walls |
| 4 | **P-2** single-probe dicts | **Separation ms (V0−V1) drops ≈half.** *If it doesn't, re-plan G-1 before building it* |
| 5 | **P-3** enemy registry + persistent buckets | Manager-side ms (V4−V5) drops. Round **numerically identical** |
| 6 | **P-4** offset table + `has_method` probe | Δms recorded. Testbed and level_01 both run |
| 7 | **G-1** flatten the grid | Separation ms drops sharply. Same lattice yields the same separation vector pre/post |
| 8 | **S-1** retire physics presence *(parallel)* | `PHYSICS_2D_COLLISION_PAIRS` collapses. Kills and lives within noise floor |
| 9 | **G-2** single manager loop | Dispatch ms (V3−V4) → ~0. Testbed either works or is formally retired |
| 10 | **M-2** checkpoint | Full matrix vs the 1500 target. Decision recorded either way |
| 11 | **X-\*** de-nodify + MultiMesh *(branch)* | Target met, or branch abandoned and trunk ships rung 9 |
| 12 | **A3-ship** overlapping waves + re-tune | A played round feels overwhelming. CLAUDE.md's table carries real numbers, not a cliff |

**Ordering rules:**

- **M-0 and M-1 block everything.** No optimisation lands without a before/after pair. This is the
  rule the previous six attempts lacked.
- **T-1 must follow P-1** (which deletes four of its sites) and **precede G-2** (which rewrites the
  same neighbourhood).
- **P-3 is the A1-Step-0 pattern** — the additive seam that G-1, G-2 and X all build on.
- **S-1 runs concurrently** with 2–7.
- **The tripwire that actually protects the timebox:** after each rung, compare measured µs/enemy
  against the target **and against that rung's own prediction**. **Two consecutive rungs missing
  their prediction by more than 50% means the cost model is wrong — stop and re-measure rather than
  keep spending against it.** That is the discipline the "capping at 24" episode should have
  triggered and didn't, because there was no prediction to miss.
- **Every rung is independently shippable**, so running out of budget means shipping at whatever rung
  you reached — not abandoning work. That is materially stronger than alpha_plan's current "keep the
  current GDScript horde as a fallback", which implies maintaining two engines.

---

## Verification

Per CLAUDE.md's *Gotchas*: **runtime errors go to `debugger_get_log`, not `editor_get_console`**;
`execute_code` with `scope_path` `/root/map1` (it cannot reach `Engine`/`Performance` — hence the
self-measuring harness); `click_node` by runtime-resolved path. Confirm via state, never
`dispatched: true`.

**No perf claim without both a measured screenshot and a `us_per_enemy` figure.**

---

## Out of scope — named so they are not drifted into

- **GDExtension / C#.** If X misses the target, that is a *post-alpha* conversation, not a rescue.
- **Per-type separation radius or mass** — a2_plan reserves this deliberately, and G-1 does not
  enable it.
- **The Chebyshev flow-field wart** (Known issue 2) — unrelated, and touching the BFS during a
  hot-path rewrite is how you get a path regression you cannot attribute.
- **Tower targeting priority** — a2_plan's answer is Divine Smite.
- **`is_wall()` centre-point testing** (Known issue 3) — same reasoning as the flow field.
