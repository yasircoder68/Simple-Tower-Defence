# A5 — "Pre-Ship Polish" — Implementation Work Order

**Status: IN PROGRESS. A5-5 (art import) is largely done — 10 of the 12 manifest files are in and
verified. **A5-1 (export hygiene) is DONE and verified against a real export, 2026-09-10.**
A5-2 (audio) is blocked on files; A5-3 (settings) and A5-4 (camera) are not started.**

**Art went first, out of the planned order, at the user's direction** — they had assets ready. The
five-strand order below is otherwise unchanged and still correct for what remains.

| | State |
|---|---|
| A5-1 export hygiene | **DONE 2026-09-10** — pck 961 KB -> 287 KB, zero sockets in the export |
| A5-2 audio foundation | not started — **no audio files supplied yet** |
| A5-3 settings | not started |
| A5-4 camera zoom + pan | not started |
| A5-5 art import | **10/12 done** — see the DONE blocks below |

**Manifest: done** — archer tower + unit, wizard tower + unit, goblin, skeleton, ogre, arrow,
fireball, boulder. **Outstanding** — #11 wall tile, #12 floor tile.

> **A grass floor WAS built and then removed at the user's request** (2026-09-09: *"it's not that
> good right now"*). The generator approach worked and is worth repeating when better art exists:
> a headless script painting a `TileMapLayer`, 16px tiles at `scale = 3.125` = exactly one 50px
> game cell, weighted variants, fixed seed. It was never committed. **The walls are still
> `1_pixel.png` stretched x50** — white squares, and the last placeholder in the game.

A4 unblocked shipping. **This is the pass that makes the first public build not embarrassing** —
real art instead of coloured rectangles, sound instead of silence, a settings menu, a camera the
player can control, and an export that does not carry developer tooling into a stranger's machine.

Inserted 2026-09-08, which pushed the old A5/A6 to **A6/A7**. That is the second renumber this
roadmap has had; see alpha_plan.md's table for the current shape.

---

## Why this stage exists, and what it is not

**It is not the art commission.** `beta_plan.md` owns that — final-quality art across the whole
game, briefed during alpha to arrive in time. A5 imports a specific set of assets the user already
has, for the entities that currently look worst. Anything not on the manifest below stays a
placeholder until beta.

**It is not the audio pass either.** Beta's *Audio · 7%* still owns the full soundscape. A5 builds
the **plumbing** — buses, a pooled player, volume settings — and wires up a starter set. That
ordering matters: the plumbing is what makes beta's audio work a drop-in rather than a rebuild.

---

## The asset manifest

Everything below is what the game needs from outside. Filenames and paths are fixed by the
colocation convention, so a correctly named file is a drop-in replacement with no code change.

### Art

Cell = **50 world px**. Source sizes below are fixed (user decision, 2026-09-08): **64x64 for
towers and units, 8x8 for projectiles.** The **Scale** column is what the `.tscn` will carry —
A5-5's job is to set it, not to guess it.

| # | File | Source px | Scale | World px | Notes |
|---|---|---|---|---|---|
| 1 | `entities/towers/archer/archer_tower.png` | **64x64** | 1.0 | 64x64 | also the sidebar icon and the build ghost |
| 2 | `entities/towers/archer/archer.png` | **64x64** | 1.0 | 64x64 | the unit on top — see the padding note |
| 3 | `entities/towers/wizard/wizard_tower.png` | **64x64** | 1.0 | 64x64 | currently scale **9** — Known issue 4 |
| 4 | `entities/towers/wizard/wizard.png` | **64x64** | 1.0 | 64x64 | see the padding note |
| 5 | `entities/enemies/goblin/goblin.png` | 64x64 | 0.5 | 32x32 | = 2 x `hit_radius` 16 |
| 6 | `entities/enemies/skeleton/skeleton.png` | 48x70 | 0.5 | 24x35 | = 2 x `hit_radius` 15 |
| 7 | `entities/enemies/ogre/ogre.png` | 140x140 | 0.5 | 70x70 | = 2 x `hit_radius` 35 |
| 8 | `entities/projectiles/arrow/arrow.png` | **8x8** | 2.0 | 16x16 | **also re-skins Rain of Arrows** |
| 9 | `entities/projectiles/fire/fire.png` | **8x8** | 2.0 | 16x16 | |
| 10 | `entities/abilities/boulder/boulder.png` | 80x80 | 0.5 | 40x40 | closes Known issue 8 |
| 11 | wall tile | 100x100 | 0.5 | 50x50 | must tile seamlessly |
| 12 | floor tile or background | 100x100 | 0.5 | 50x50 | there is currently nothing at all |

**Three consequences of those sizes, all decided rather than discovered:**

- **Towers overhang their cell by 7px a side** (64 world px in a 50px cell). That is deliberate and
  reads well — a tower should feel bigger than its footprint — and it is a vast improvement on the
  wizard's current x9. If it turns out to crowd neighbours, `scale = 0.78` makes it fill the cell
  exactly.
- **The unit sprites need transparent padding.** An archer at the full 64x64 would be the same size
  as the tower it stands on. Draw the character occupying roughly the middle **32x40** of the
  canvas so it reads correctly at `scale = 1.0`.
- **8x8 projectiles are tiny at the default zoom.** 8 world px is ~4.6 screen px at zoom 0.575 —
  effectively a dot. Hence `scale = 2.0` for 16 world px (~9 screen px), which is readable and
  gets crisper as the player zooms in. **This requires Nearest filtering** or the upscale is a
  blur: set `rendering/textures/canvas_textures/default_texture_filter = 0` project-wide in A5-5.

**Tiles must scale exactly.** 100x100 at `scale = 0.5` gives a clean 2:1; a non-integer tile scale
produces visible seams between cells. Note the tileset currently uses `tile_size = 1` with a x50
node scale, so A5-5 has to change `texture_region_size` and the node scale together.

**Open — skeleton and ogre are the only characters not on a 64x64 canvas.** If you want one uniform
canvas for every character, author all three enemies at 64x64 and A5-5 sets `scale` to 0.5 / 0.47 /
1.09 instead — the world sizes, and therefore `hit_radius`, stay identical either way.

**11 and 12 are the largest visual gap in the game and were not on the user's list.** The map is
drawn from `levels/tilesets/my_tiles.tscn`, which stretches `assets/1_pixel.png` by 50 — every wall
is a white square, and the floor is the default grey clear-colour. Two towers on a whiteboard still
looks like a prototype.

**Needs no art, already procedural:** the aim marker (`_draw()`), the ghost tower (tints the tower
PNG), the sidebar icons (reuse the tower PNGs), and every UI panel (the generated theme).

### Audio

`.wav` for SFX (no decode latency), `.ogg` for music (**tick Loop on import**). Into
`assets/audio/sfx/` and `assets/audio/music/`, which exist and are empty.

| Tier | Files |
|---|---|
| **Essential (6)** | `ui_click`, `tower_place`, `archer_shot`, `wizard_cast`, `enemy_death`, `life_lost` |
| **Punctuation (5)** | `wave_start`, `round_won`, `round_lost`, `upgrade_buy`, `fire_explode` |
| **Abilities (3)** | `boulder_cast`, `boulder_impact`, `rain_of_arrows` |
| **Music (2)** | `menu_loop` (60-90s), `combat_loop` (90-120s) |

**Length is a technical constraint, not a taste one.** `archer_shot` fires ~8x/sec per tower, ~32/sec
with four; keep it under 150ms and quiet. `enemy_death` fires in bursts of dozens.

**Deliberately skipped:** `silver_earned` (408 kills a round), `arrow_hit` (32 arrows/sec — fold it
into `enemy_death`), `tower_remove` (reuse `tower_place` pitched down).

### Effects

| # | Effect | Trigger | Build as |
|---|---|---|---|
| 1 | **Boulder impact** — dust ring, debris, screen shake | impact, radius 70 | sprite sheet |
| 2 | **Fire explosion** | wizard AoE, radius 100 | sprite sheet |
| 3 | **Enemy death** — small puff | every kill | **pooled particles** |
| 4 | **Life lost** — red screen-edge vignette flash | an enemy escapes | shader/ColorRect tween |
| 5 | **Tower placement** — dust puff | on place | particles |
| 6 | **Wave banner** — text tweens in and out | wave start | UI tween |
| 7 | Rain of Arrows ground impacts | per tick | particles, optional |
| 8 | Muzzle flash / bow flex | per shot | **skip — 32x/sec** |
| 9 | Something at the end point on escape | enemy reaches goal | optional |

Hero moments (1, 2) are seen up close and fire rarely, so they earn sprite sheets. Everything
high-volume (3, 5, 7) should be procedural particles tinted from `ui/palette.gd` — no art to
source, and no way for the art to blow the budget.

---

## THE RULE THAT GOVERNS BOTH AUDIO AND EFFECTS

> **Effects and sounds are the most likely thing in the project to undo D-1's performance work.**
>
> Wave 5 kills **152 enemies**, in bursts of dozens per second. Four towers fire **~32 shots per
> second**. A naive `AudioStreamPlayer.play()` or a fresh particle emitter per event means voice
> exhaustion, clipping, and 152 simultaneous emitters.
>
> **Both need the same three things: a fixed pool, a per-event minimum retrigger interval, and a
> hard cap.** Plus +/-10% pitch randomisation on repeated sounds so they do not fatigue — which is
> cosmetic, and therefore on the right side of CLAUDE.md's *"cosmetic randomness is fine; damage
> randomness is not"* rule.
>
> A3 spent an entire stage buying headroom. Do not hand it back for a dust puff.

---

## The work order

Five strands. Two ordering constraints are real; the rest is preference.

### A5-1 — Export hygiene · ~15 min · **no dependencies, do it first**

**The exported build currently ships the developer toolkit and opens a network port.**

- `export_presets.cfg` has `exclude_filter=""`, so all 277 files of `addons/godot_mcp_toolkit/`
  are packed into the release.
- `MCPRuntimeServer` is an **autoload**, so the shipped game starts a WebSocket listener scanning
  ports 6570-6585 on the player's machine. That will trip antivirus and looks alarming in a
  downloaded indie game.
- `config/name="game"` — the window and taskbar say "game".
- `application/product_name` and `company_name` in the export preset are blank.

Fix: an exclude filter for the addon, a guard so the autoload does nothing in an exported build
(`OS.has_feature("editor")`), a real project name, and filled-in export metadata.

**Also drop `systems/bench.gd` from the export** for the same reason — it is dev instrumentation
that a player can never reach.

#### DONE — 2026-09-10. Three of the four premises above were WRONG; read this before trusting them.

**The WebSocket listener was ALREADY GUARDED.** `mcp_runtime_server.gd` line 108 already does
`if not OS.has_feature("editor"): set_process(false); return`, with a comment noting it is stronger
than `is_debug_build()` (true in a debug export). The addon also ships its own `EditorExportPlugin`
(`core/export_strip.gd`) that strips addon files **and nulls the `MCPRuntimeServer` autoload for the
bake**. Nothing needed writing for this.

**What DID leak was the `.gdc` leak the addon documents and refuses to fix.** With
`script_export_mode=2` (binary tokens, this preset's setting) Godot's built-in GDScript export
plugin compiles addon `.gd` to `.gdc` **before** the strip runs, so the scripts shipped as inert
orphaned bytecode. The addon warns rather than strips because `set_exclude_filter` is unbound
through 4.6 (godot#4054). Setting `exclude_filter` **by hand in the preset** is the fix, and it is
safe precisely because the strip plugin has already nulled the autoload.

**`systems/bench.gd` could NOT simply be excluded.** `level_controller.gd` had
`bench = preload("res://systems/bench.gd").new()`, and `preload()` resolves at **compile** time —
so excluding the file would have been a parse failure of `level_controller` itself, i.e. the whole
game would not boot. The construction is now wrapped in `if OS.has_feature("editor")` and uses
`load()`. **Those two changes are a pair; undoing either alone breaks the export.**

**Shipped:**

| Change | Where |
|---|---|
| `exclude_filter="addons/godot_mcp_toolkit/*, systems/bench.gd, testbed/*"` | `export_presets.cfg` |
| bench construction guarded + `preload` -> `load` | `level_controller.gd` |
| `config/name` "game" -> "Medieval Horde Defense", `config/version` 0.1.0 | `project.godot` |
| `product_name`, `company_name`, `file_description`, `file_version`, `product_version` | `export_presets.cfg` |
| **`.gitignore` (there was none)** + untracked `export/` | repo root |

**Verified against a real `--export-release`, not by reading:**

- **pck 961,340 -> 287,196 bytes (-70%).**
- **The exported process holds ZERO network sockets** (`netstat -ano` filtered to its PID). Its own
  `user://logs/godot.log` contains **no MCP lines at all**, where the editor run logs both
  `port: scanning 6570-6585` and `listening on 127.0.0.1:6570`. That contrast is the proof.
- Window title reads **"Medieval Horde Defense"** (`tasklist /V`), not "game".
- Bench still constructs under an editor run (`has_node("Bench")` true), map intact (175/156).

**Two traps found while doing it:**

- **`config/name` is what `user://` resolves from.** Changing it MOVED the save directory from
  `app_userdata/game/` to `app_userdata/Medieval Horde Defense/`, orphaning anything in the old one.
  Harmless here only because it was done before any public build and right after a deliberate save
  reset. **Never change `config/name` after shipping** — it wipes every player's progress.
- **The editor holds ProjectSettings in memory and rewrites `project.godot` on save.** Editing the
  file directly left the editor still reporting `"game"`, which would have been written back. Use
  `project_set_setting` so both agree.

**Residual, and deliberately not chased:** ~137 addon path *strings* remain in the pck inside
`.godot/global_script_class_cache.cfg` and `.godot/uid_cache.bin`, which Godot always packs. No
addon **file** is stored — the size drop and the zero-socket result both confirm it. They are dead
names in a lookup table, not code.

### A5-2 — Audio foundation · needs nothing but the files

- `default_bus_layout.tres`: **Master -> Music, SFX.** None exists today; only Master does, which
  is why per-category volume is impossible right now.
- An `Audio` autoload owning a **pool** of `AudioStreamPlayer`s per bus, with the retrigger
  throttle, the cap and the pitch jitter from the rule above.
- **Missing files must be a no-op, not an error**, so sounds can land one at a time rather than
  all sixteen at once.
- Wire the call sites: towers, projectiles, enemies, abilities, the round lifecycle, every button.

### A5-3 — Settings · needs A5-2's buses

- **A `Settings` autoload writing `user://settings.cfg` — NOT `PlayerData`.** CLAUDE.md's state
  boundary is *persistent progress* vs *round-scoped*; settings are a **third category**, user
  preference. In `PlayerData` they would be wiped by `reset_progress()`, which is plainly wrong,
  and they would ride along in the save format for no reason.
- Applied on boot, **before the main menu is shown**.
- One screen, reachable from the **main menu and the pause screen**, using the self-contained
  `CanvasLayer` pattern the upgrade screen proved at A4's U-5.
- Music volume, SFX volume: slider 0-1 in the UI, `linear_to_db()` on the way to the bus. Never
  store dB.
- Resolution, fullscreen, vsync via `DisplayServer`.

> **Prerequisite, and it changes how everything renders.** `display/window/stretch/mode` is unset,
> so it defaults to `disabled` — changing the window size today just shows more or less viewport
> instead of scaling the game. Resolution options need `stretch/mode = canvas_items` and
> `aspect = keep`. **Do this early in the strand and look at it**, not at the end.

> **Conflict with the bench.** `systems/bench.gd` force-sets `VSYNC_DISABLED` and
> `Engine.max_fps = 0`. Once Settings owns vsync, a bench run silently overrides the player's
> choice and never restores it. `bench.reset()` must re-apply from Settings.

### A5-4 — Camera zoom and pan

Requested as *"camera zooming by player while placing tower and in combat"*. **Zoom implies pan** —
once zoomed in you can only see the middle of the map.

- **Wheel = zoom, middle-drag = pan.** Both inputs are currently unused: LMB is the tower drag and
  ability aiming, RMB is tower removal. No collisions.
- Clamp zoom to roughly **0.575 (the current value, which fits the whole map) up to ~2.0**, and
  clamp panning to the map bounds so the level cannot be lost off-screen.
- **Not persisted in Settings** — it is per-session view state, not a preference.

Two things that follow:

- **The HUD is unaffected**, because every UI element is on a `CanvasLayer`. Correct by
  construction, and worth not breaking.
- **Placement and aiming should follow automatically**: `_cell_at()` and every ability read
  `get_global_mouse_position()`, which accounts for the camera transform. **Verify it rather than
  assume it** — and note CLAUDE.md's standing warning that `get_global_mouse_position()` is not
  reliably driven by `input_simulate`, which zoom makes worse. Verify by state, not by coordinates.

### A5-5 — Art import · **LARGELY DONE** *(taken first, out of order)*

Art is judged at a zoom, and A5-4 defines the range, so this comes last.

**Started out of order (2026-09-08), at the user's direction: the archer tower first.**

> **Archer tower — DONE.** `archer_tower.png` (64x64) and `archer.png` (128x64, two 64x64 frames)
> imported. Both sprite scales set to **1.0**, the archer centred on the platform
> (`ARCHER_VISUAL_OFFSET` is now `Vector2.ZERO`), `hframes = 2`, and a one-shot `ShotAnimTimer`
> holds the drawn-bow frame for 0.08s per shot — deliberately under `MIN_ATTACK_INTERVAL` (0.1) so
> a fully upgraded archer cannot leave the bow permanently drawn. Closes Known issue 7.
>
> **Facing: `flip_h`, not rotation.** The art is directional (bow on the right, frame 1 nocks an
> arrow pointing +x), so an archer shooting left would otherwise fire the wrong way. Rotation was
> tried first **and looked wrong on screen** — the sprite is drawn 3/4-overhead with the head above
> the body, so rotating it makes the archer read as lying on his side. Flipping keeps the head up.
> The cost is left/right-only facing, which at this zoom is invisible; a character lying down is not.
>
> **A generalisable finding for the rest of the manifest:** this art has an "up". Assume every
> character sprite does, and reach for `flip_h` before `rotation`.

> **Wizard tower — DONE.** `wizard_tower.png` (64x64) and `wizard.png` (256x64, four 64x64
> frames) imported; tower scale **9 -> 1.0**, which **closes Known issue 4** — the wizard sprite
> no longer overlaps neighbouring towers. The wizard is centred (its `position = (0, 40)` offset
> removed) and its unit scale set to **0.8** to match the archer, so the platform reads underneath
> it. Cast animation runs frames **0 -> 1 -> 2** and returns to idle on a repeating `CastAnimTimer`;
> `flip_h` faces the target, same as the archer.
>
> **Frame 3 is unused.** It is a near-duplicate of frame 0, and the brief was "first 3 for
> animation, first one for idle" — so the cast plays 0/1/2 and rests on 0. Say if it was meant to
> be part of the cycle.
>
> Unlike the archer's single-frame hold, the wizard's animation **does not need to fit inside
> `MIN_ATTACK_INTERVAL`**: each shot restarts it from the first frame, so a fast wizard replays it
> rather than getting stuck mid-cast.
>
> **The fireball moved to `entities/projectiles/fire/fire.png`.** It arrived at
> `entities/towers/wizard/fireball.png`, but the projectile owns its own folder under the
> colocation convention — and overwriting the existing file in place kept its `.import` and UID, so
> nothing needed re-referencing.

> **Build preview — DONE, and rebuilt rather than patched.** The ghost now shows the tower **and
> its unit**, because it instantiates the real tower scene instead of compositing a lone base
> sprite with a hardcoded scale (3 for archer, 9 for wizard — both already stale). Same rule the
> aim marker follows: preview geometry is read off the thing it previews, never duplicated beside
> it, so it can never drift again.
>
> **`PROCESS_MODE_DISABLED` is what makes that safe.** A tower scene is a *live* tower — its unit
> joins `tower_unit`, resolves stats, starts a fire Timer and spawns projectiles into its parent.
> Disabling the subtree stops every Timer in it from ticking while leaving rendering untouched.
> **Verified: the ghost archer's `time_left` was frozen at `0.28214292984407` across two samples
> five seconds apart.** The unit is also removed from `tower_unit` after instantiation, since
> `_ready()` runs regardless and that group means "a tower that is actually placed".
>
> The validity tint had to soften too (`(0,1,0)` -> `(0.45,1,0.45)`): `modulate` multiplies, so a
> pure channel mask flattened the newly visible detail into one featureless blob.

> **Build sidebar icons — DONE, same treatment.** The two buttons `load()`ed the tower base PNG, so
> they showed no unit either. They now render the real tower scene into a 64x64 `SubViewport` and
> use that as the icon. Compositing the textures here instead would have put each tower's unit
> scale and offset in a **third** place — the scene, the ghost, and the sidebar — and those had
> already drifted once.
>
> `PROCESS_MODE_DISABLED` before `add_child` again, so the icon towers cannot fire into a viewport
> invisibly forever, plus removal from `tower_unit`. `render_target_update_mode = UPDATE_ONCE`, set
> **after** the contents exist so it captures a populated frame: the subject never moves, so
> re-rendering it every frame for the life of the game would be pure waste.
>
> **Three places now derive the tower's appearance from one source** — the placed tower, the build
> ghost, and the sidebar icon — and none of them can drift from the scene again.

> **Enemies — DONE.** `goblin.png`, `skeleton.png` and `ogre.png` imported, each a two-frame run
> sheet. All three `modulate` tints removed (they existed only because the "art" was a white
> pixel), root scales reset to 1.0, `hframes = 2`, and sprite scales chosen so **world size = 2 x
> `hit_radius`** exactly:
>
> | | frame px | scale | world px | 2 x hit_radius |
> |---|---|---|---|---|
> | goblin | 16x16 | 2.0 | 32 | 32 |
> | skeleton | 16x16 | 1.875 | 30 | 30 |
> | ogre | 32x32 | 2.1875 | 70 | 70 |
>
> **The skeleton arrived as a clean 12x upscale** — 384x192, i.e. 32x16 of logical pixels blown up.
> Verified every 12x12 block was uniform, then point-sampled it down to 32x16 (lossless, 7134 ->
> 420 bytes). Left at 192x192 per frame it would have needed `scale = 0.156`, and downscaling
> blown-up pixel art by a non-integer factor drops pixels unevenly. Original kept in the scratchpad.
>
> **Run animation is distance-based, not time-based.** Frames advance every `ANIM_STEP_PX` (14) of
> ground covered, so a 280 px/s skeleton animates 2.8x faster than a 100 px/s goblin instead of
> skating. The rate is resolved once at spawn (`speed / ANIM_STEP_PX`) so the hot path multiplies
> rather than divides, and each enemy gets a **random phase** — otherwise a wave that spawns
> together animates in lockstep and reads as one object rather than a crowd.
>
> **It touches the sprite only when the frame actually changes.** This runs on up to 152 enemies a
> frame; assigning `sprite.frame` unconditionally would be ~150 redundant Variant property writes
> per frame. D-1 did not free that budget up to spend it setting the same value. It also sits after
> the `BENCH_NO_MOVE` early-out, so a frozen bench enemy does not animate either — otherwise the
> ablation would measure cosmetics it claims to have removed.
>
> `flip_h` for facing, same conclusion as the towers: this art is drawn 3/4-overhead with the
> weapon on the right.
>
> **Acceptance passed: a full round earned 904 with 407 kills and 19/20 lives.** Against the 906
> maximum and 408 spawned, that is 2 silver short, 1 life lost and 1 enemy unkilled — **exactly one
> escaped small enemy, agreed by all three counters**. The hitboxes did not move.

> **Arrow and boulder — DONE.** `arrow.png` (8x8) at `scale = 2` -> 16 world px; `boulder.png`
> (16x16) at `scale = 2.5` -> 40 world px, tint removed, which **closes Known issue 8**.
>
> **The arrow ROTATES, and that is not a contradiction of the flip rule.** `arrow.gd` already did
> `rotation = direction.angle()`, and the new art points +x with fletching behind, so it worked
> untouched. Characters flip because they are drawn 3/4-overhead with a head above a body; an arrow
> has no "up" — it is an object aligned with its own flight. **The test is whether the sprite has an
> implied vertical, not whether it is directional.**
>
> **A trap found while setting the arrow's scale.** `arrow.gd`'s `PROJECTILE_RADIUS = 20.0` was
> documented as "CircleShape2D 4.04 at scale 5" — a derivation from the scene. Dropping the node
> scale 5 -> 2 for the real art makes that shape measure ~8, so anyone later "correcting" the
> constant to agree with the scene would **more than halve every tower's reach**. The shape has been
> vestigial since S-1 (hits are a distance test; nothing masks layer 3), so the constant is the real
> number and the scene is the part that stopped mattering. The comment now says so explicitly.
>
> Old visual scale was 5, i.e. a 40px arrow — **larger than a goblin**. At 16px it finally reads as
> a projectile rather than a thrown log.
>
> Verified: waves 1-2 paid exactly 160 with 20/20 lives after the change, so the smaller arrow still
> connects; boulder cast, landed and damaged; zero errors.

Twelve files from the manifest. Three things that make this more than a drag-and-drop:

1. **`hit_radius` must stay in sync.** The enemies are `1_pixel.png` scaled to 64 and tinted with
   `modulate` — root scale 0.5 / (0.38, 0.55) / 1.1 for goblin / skeleton / ogre. Those scales are
   **not cosmetic**: `enemy_types.gd`'s `hit_radius` was derived from them, and since A3's S-1
   projectiles hit by **distance test** against that number.
   **The rule: an enemy's sprite world size must equal `2 x hit_radius`** (32, 30, 70). Break it and
   the hitbox silently stops matching what the player sees; change `hit_radius` to match new art and
   it is a difficulty change, which per-wave silver will detect.
2. **Remove every `modulate` tint**, or the new art arrives tinted red, bone and green.
3. **Normalise the scales.** They are currently ad-hoc — archer x3, wizard x2.5, **wizard_tower x9**.
   Authoring at 2x world size and setting every sprite to `scale = 0.5` **closes Known issue 4**
   (the wizard sprite visually overlapping neighbouring towers) as a side effect.

---

## Risks

1. **Effects/audio reversing D-1's headroom.** The governing rule above. This is the single largest
   technical risk in the stage, and it is a repeat of a lesson the project has already paid for.
2. **`hit_radius` drift.** Silent, gameplay-affecting, and only visible as a per-wave silver
   discrepancy. A5-5's acceptance round is not optional.
3. **The stretch-mode change (A5-3) altering the whole game's rendering.** Land it early.
4. **Camera zoom breaking placement or aiming.** Should be free, but `get_global_mouse_position()`
   is exactly the API this project has documented as untestable through `input_simulate`.
5. **Scope creep into beta's art pass.** The manifest is twelve files. Anything not on it stays a
   placeholder.

---

## Acceptance

- **A full round with per-wave silver reconciling exactly** (64 / 96 / 154 / 238 / 354). Mandatory
  after A5-5, because `hit_radius` is the one thing here that can change difficulty. Compare kills
  against the spawn table too — A4's U-3 counter makes that a three-way check.
- **A `us_per_enemy` figure from the bench after effects land**, against a reading taken in the
  same sitting beforehand. Not optional: see risk 1, and remember only ratios travel between
  sessions on this machine.
- Settings survive a restart; changing each one visibly does what it says.
- Zoom and pan do not break tower placement, tower removal, or either ability's aiming.
- **An exported build contains no `addons/` and opens no ports.**
- Zero errors in `debugger_get_log` across menu -> settings -> play -> pause -> result -> menu.

---

## Open items

- **Wall tile (manifest #11) and floor tile (#12).** The floor was attempted and rejected; the wall
  has not been attempted. Both want **16x16 at `scale = 3.125`**, which lands exactly on the 50px
  game grid. Note `my_tiles.tscn` is currently `tile_size = 1` at node scale 50, so a real wall
  texture means changing `texture_region_size` and the node scale **together**.
- **Effects 1 and 2** — sprite sheets, or built procedurally?
- **No audio has been supplied yet.** All 16 files are still outstanding, so A5-2 and the audio
  half of A5-3 are blocked on them. A5-2 is specified to treat a missing file as a no-op, so they
  can land one at a time.
