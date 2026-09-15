# A5 — "Pre-Ship Polish" — Implementation Work Order

**Status: IN PROGRESS. A5-5 (art import) is largely done — 10 of the 12 manifest files are in and
verified. **A5-1 (export hygiene) is DONE and verified against a real export, 2026-09-10.**
**A5-3 (settings) and A5-4 (camera) are also DONE, 2026-09-10.** **A5-2 (audio) is DONE as well, minus the two music tracks.**
**A5-5 is CLOSED at 12/12** — `grass_biome` IS manifest #11 and #12.

**Art went first, out of the planned order, at the user's direction** — they had assets ready. The
five-strand order below is otherwise unchanged and still correct for what remains.

| | State |
|---|---|
| A5-1 export hygiene | **DONE 2026-09-10** — pck 961 KB -> 287 KB, zero sockets in the export |
| A5-2 audio foundation | **DONE 2026-09-10** — 14 synthesized SFX, pooled `Audio` autoload; music excluded |
| A5-3 settings | **DONE 2026-09-10** — display only; audio rows wait on A5-2 |
| A5-4 camera zoom + pan | **DONE 2026-09-10** — verified through real wheel/drag input |
| A5-5 art import | **DONE 12/12 2026-09-10** — `grass_biome` closed #11 and #12 |

**Manifest: DONE, all 12.** Archer tower + unit, wizard tower + unit, goblin, skeleton, ogre,
arrow, fireball, boulder — and, as of 2026-09-10, the wall (#11) and floor (#12) tiles.

> **#11 AND #12 ARE THE USER'S `grass_biome` TILEMAP** (settled 2026-09-10: *"wall/floor is the
> grass_biome tileMap"*). It ships 6 floor variants and 11 wall variants of hand-drawn 8x8 art
> (`grass_floor.png` 48x8, `grass_walls.png` 88x8) — green grass and grey stone.
>
> **They did NOT land the way this manifest specified, and the difference is the interesting part.**
> The spec assumed one tilemap at 100x100 / scale 0.5 doing both art and collision. What shipped is
> a **split**: `grass_biome` is 8x8 at scale 1.0 and purely cosmetic, while a hidden `my_tiles`
> stays the 50px logic layer. 50 / 8 = 6.25 is not an integer, so the two lattices cannot be
> reconciled by any scale value — which is precisely why the split exists. See CLAUDE.md's
> *Flow-field pathfinding*; the wall cells are DERIVED from the art by area majority.
>
> An earlier procedural grass floor was built and rejected (2026-09-09: *"it's not that good right
> now"*) and was never committed. Hand-drawn art replaced it.

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
| 11 | `levels/tilesets/grass_walls.png` | **88x8** (11 x 8x8) | 1.0 | 8x8/tile | **DONE** — grey stone, cosmetic layer only |
| 12 | `levels/tilesets/grass_floor.png` | **48x8** (6 x 8x8) | 1.0 | 8x8/tile | **DONE** — green grass |

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

**"Tiles must scale exactly" was the wrong constraint, and reality routed around it.** The rule
assumed one tilemap serving art AND collision, where a non-integer scale would put the hitbox off
the sprite. The shipped answer decouples them instead: the art tilemap can use any tile size it
likes because nothing queries it, and the logic tilemap keeps its exact 50px cell because nothing
draws it. **The constraint only ever bound because one node was doing two jobs.**

**Open — skeleton and ogre are the only characters not on a 64x64 canvas.** If you want one uniform
canvas for every character, author all three enemies at 64x64 and A5-5 sets `scale` to 0.5 / 0.47 /
1.09 instead — the world sizes, and therefore `hit_radius`, stay identical either way.

**11 and 12 WERE the largest visual gap in the game and were not on the user's list — now closed.**
The map was drawn from `my_tiles.tscn` stretching `assets/1_pixel.png` by 50: every wall a white
square on a grey clear-colour, two towers on a whiteboard. `grass_biome` replaced that. `my_tiles`
still exists and still uses `1_pixel.png`, but it is `visible = false` — it is collision now, not
art, so **that placeholder is no longer on screen anywhere.**

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

#### DONE — 2026-09-10. All 14 SFX, synthesized; the 2 music tracks remain (excluded by decision).

**No audio was supplied, so the sounds were synthesized in code** — a Python script (numpy/scipy,
sfxr-style: oscillators with pitch sweeps, filtered noise, Karplus-Strong plucks for bowstrings, fixed
seeds). **That script is not committed yet; the WAVs are the source of truth until it is.** 16-bit mono
44.1 kHz, ~850 KB total, zero clipped samples. Loudness is set per sound by peak and deliberately
uneven: `archer_shot` is 130 ms at -15 dBFS peak / -31.6 RMS because it fires ~32/sec, `enemy_death`
is 180 ms for its bursts, and rare punctuation (`wave_start`, `round_won`, `boulder_impact`) sits at
-3 to -5 dBFS. **Whether they SOUND right was not judged here** — nothing on the implementing side can
hear. Everything below is what measurement could establish.

**Shipped:**

| Piece | Where |
|---|---|
| `default_bus_layout.tres`: Master -> Music, SFX | `game/` |
| `Audio` autoload: 14 fixed pools (30 players), retrigger gap, pitch jitter from a private RNG | `autoload/audio.gd` |
| Every button clicks: `node_added` hook + one deferred sweep of the boot scene | `autoload/audio.gd` |
| SFX Volume slider: linear 0-1, `linear_to_db()` at apply, 0 = muted bus | `settings.gd`, `settings_screen.gd` |
| Call sites: both towers, fireball, enemy death, boulder, Rain, waves, round end, lives, place/remove/move, shop | 11 scripts |

**Verified in a real round** (upgraded save, 3 archers + 1 wizard, boulder and Rain cast mid-round):
WON, 904 silver, 19/20 lives, result screen **407 killed**. Four channels agree: 906-904 = 2 silver
short, 1 life lost, one small enemy escaped — and **`enemy_death` requests = 199 played + 208 throttled
= 407 = the kill count**, so every `_die()` reached the hook exactly once. `life_lost` 1 = the one
escape; `wave_start` 5; `round_won` 1; `wizard_cast` 50 = `fire_explode` 50. **`stolen` was 0 for every
sound**: the retrigger gaps absorbed the bursts (`enemy_death` dropped 51% of requests, `archer_shot`
40 of 224) and no pool ever ran out. The cap is a backstop this load never reached.

**Also verified:** 4 towers placed in one frame gave `tower_place` 1 played / 3 throttled; removal
played it at pitch 0.738 (0.78 x jitter); a real shop click gave `upgrade_buy` 1 + `ui_click` 1; a
misspelled sound name push_errors (tested by breaking it); a real mouse drag moved SFX 0.8 -> 0.3
live, played a preview click on release and wrote `[audio] sfx_volume` to `settings.cfg`; the pause
menu's buttons click with `tree_paused: true`, and its settings screen showed the persisted 0.3.

**Pause, measured:** a gameplay voice already playing when the pause began froze at 0.003 s through the
whole pause and resumed to 1.707 s after; a `ui` voice beside it advanced to 0.525 s; the retrigger
clock read identically across two paused reads. **The first version of that test was invalid** — it
started both voices AFTER pausing, saw both advance, and proved nothing, because Godot pauses streams on
the pause notification.

**Two bugs found by testing, both fixed:**

- **Boot-scene buttons were silent.** `node_added` never reports the boot scene's nodes — they enter the
  tree before any autoload's `_ready()` runs. A shop button built later in `_ready()` clicked while the
  level's authored StartButton did not, and in real play the boot scene is the MAIN MENU. Fixed with one
  deferred sweep; re-verified at the menu: all four menu buttons hooked, and real clicks counted.
- **The editor clobbered the bus layout.** Adding the Music bus through the editor made it save its
  in-memory, Master-only layout over `default_bus_layout.tres`, deleting SFX from the file. Re-adding SFX
  through the editor restored it, and `Audio._ensure_bus()` recreates a missing bus at runtime anyway.

**`us_per_enemy` was not re-measured.** Audio adds no per-enemy, per-frame work — one float add per frame
in `Audio._process()`, everything else fires on events — so it sits outside what that metric measures.

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

#### DONE — 2026-09-10, MINUS AUDIO (A5-2 is blocked on files).

`autoload/settings.gd` (registered as `Settings`) + `ui/settings_screen/`. Ships **Fullscreen,
VSync, Resolution**; the two volume sliders are the only missing rows and are two entries in
`_build_rows()` when the buses exist. Deliberately not shipped as dead controls.

`display/window/stretch/mode = canvas_items` + `aspect = keep` landed FIRST and was looked at, as
the prerequisite note demanded. **Verified by launching at an 820-wide window**: the whole layout
(HUD, sidebar, ability bar, map) scaled down together and 16:9 was preserved. Under the old
`disabled` mode the same window would have shown LESS map at a pixel-identical HUD.

**The settings screen is the SECOND `PROCESS_MODE_ALWAYS` node in the project** — CLAUDE.md
previously said `pause_menu` was the only one. It has to be: the pause screen opens it while the
tree is paused, and a screen that inherited would appear with dead buttons. **Verified by clicking
a toggle with `tree_paused: true` and watching the value change.**

**It sits at `layer = 110` against pause_menu's 100.** At the 70 it was first written with it
rendered UNDERNEATH the screen that opened it.

**Escape closes Settings before it resumes.** Without that guard the press falls through to
`_on_resume_pressed()` and the round runs invisibly behind a still-open modal. Verified: first
Escape left `paused=true, pause_visible=true, settings_visible=false`; the second resumed.

**The bench conflict the plan predicted was real and is fixed.** `bench.gd` force-disables vsync
(without which every result reads "60") and `reset()` never restored it; it now calls
`Settings.apply_vsync()`. Before A5-3 nothing owned vsync so nothing noticed.

**Verified end to end:** a real click on the VSync toggle flipped `Settings.vsync` true->false,
wrote `user://settings.cfg`, and **the value survived a full restart** (loaded back as false on
boot). Reachable and working from BOTH the main menu and the pause screen, one shared scene. Zero
runtime errors throughout.

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

#### DONE — 2026-09-10.

`systems/camera_controller.gd`, attached to `level_01`'s existing `Camera2D`. Shared by every
level like `level_controller.gd`, and it **reads the level's authored zoom as the floor** rather
than hardcoding 0.575, so a bigger map with different framing needs no edit here.

**Routed through `_unhandled_input()`, not `_input()`** — the same rule the boulder is bound by,
and it is load-bearing: a wheel notch over the build sidebar would otherwise zoom the world
underneath it. This was **observed, not assumed**: motion events sent at (40,60) and (100,100) did
nothing because those land inside the HUD panel, which consumed them. That looked like a bug for a
moment and is in fact the routing working.

**Zoom pins the world point under the cursor**, computed from the viewport rect by hand rather
than with `get_global_mouse_position()`. That call reads the canvas transform, which `Camera2D`
does not necessarily refresh in the frame the zoom is assigned — it would silently read the
pre-zoom value and the correction would come out as exactly zero.

**Panning has two clamp regimes, and the split is what stops the view snapping.** Zoomed IN the
visible rect may not cross the map edge. Zoomed OUT that clamp is unsatisfiable (min would exceed
max) and forcing it would jerk the camera to the map centre the instant the player touches the
wheel; there the camera CENTRE is simply kept inside the map, which still guarantees the map is
on screen because the view already covers it.

**Verified through real input, not by calling methods:**

| Check | Result |
|---|---|
| one wheel notch | 0.575 -> 0.6325, i.e. exactly x1.1 |
| 16 notches up | clamped at exactly **2.0** |
| 16 notches down | clamped at exactly **0.575** (the level's authored value) |
| middle-drag, two motions of relative (-200,-100) at zoom 2 | camera +exactly (200,100) = `-relative/zoom` |
| drag into the corner | exactly **(880.0, 620.0)** = the predicted tight clamp |
| HUD | pixel-identical at every zoom (CanvasLayer, correct by construction) |

**Placement and aiming were VERIFIED to follow the camera, not assumed.** At zoom 2.0 panned to
(880,620) the canvas transform reads scale (2,2), origin (-1120,-880), and screen centre maps to
world (880,620) — the camera centre. `get_global_mouse_position()` *is* that inverse transform, and
`_cell_at()` and every ability read it, so they follow by construction.

`level_controller.get_world_bounds()` supplies the clamp rect, derived from the LOGIC tilemap
(`my_tiles`), never the art layer. It resolves to Rect2(-300, 0, 1500, 800) on level_01. The camera
queries it **deferred**, because `_ready()` runs children-first and `level_controller`'s `@onready
tile_map` is still null at that point.

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

**RUN 2026-09-10. Everything that does not need audio PASSES.**

| Criterion | Result |
|---|---|
| Full round, per-wave silver | **PASS** — wave 1 = 64, wave 2 = 160 cumulative, both exact |
| Three-way reconciliation | **PASS** — see below |
| Settings survive a restart | **PASS** — vsync written to `user://settings.cfg`, loaded back on boot |
| Zoom/pan vs placement + aiming | **PASS** — see below |
| Export has no `addons/`, opens no ports | **PASS** (A5-1) — pck -70%, zero sockets on the running exe |
| Zero errors, menu -> settings -> play -> pause -> result -> menu | **PASS** — `debugger_get_log` empty at every step |
| `us_per_enemy` after effects | **N/A** — effects are not built (see Open items) |

**The three-way reconciliation, which is the criterion that matters.** Round WON, 12/20 lives:

| Channel | Figure |
|---|---|
| Silver | 906 expected — 884 actual = **22 short** |
| Lives | 20 - 12 = **8 lost** |
| Kills | 408 spawned - 402 killed = **6 escaped** |

Exactly one composition satisfies all three: **1 ogre** (12 silver, 3 lives) + **5 small** (10
silver, 5 lives) = 22 / 8 / 6. Two ogres would owe 28 silver, zero would owe 16; neither fits. **No
drift anywhere in the damage, scoring or life-cost paths.**

**`hit_radius` — the one thing A5-5 could have moved — is intact.** The convention is that a
sprite's world size must equal `2 x hit_radius`, and all three hold exactly:

| | frame | scale | world px | 2 x `hit_radius` |
|---|---|---|---|---|
| goblin | 16x16 | 2.0 | **32** | 32 |
| skeleton | 16x16 | 1.875 | **30** | 30 |
| ogre | 32x32 | 2.1875 | **70** | 70 |

Note the source sizes differ from what this manifest specified (it asked for 64x64 / 48x70 /
140x140 at scale 0.5). **The WORLD sizes are what the invariant is about, and those are exact.**

**Zoom/pan verified against placement and aiming at zoom 0.765, mid-round:** `_cell_at()` on the
screen-centre world position resolved to a live map cell, ability selection worked from the number
keys, and **Rain of Arrows cast successfully through the full press-rotate-release directional aim**
(cooldown read 25.6 of 30 afterwards). The boulder could NOT be confirmed the same way — its 3s
cooldown is shorter than an MCP round trip, so it always reads 0 by the next call. Rain's 30s
cooldown is what makes it observable at all; **use Rain, not the boulder, to test ability input.**


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

- ~~**Wall tile (#11) and floor tile (#12).**~~ **CLOSED 2026-09-10** — both are the user's
  `grass_biome` tilemap. The one residual cost: because the art lattice (8px) is 6.25x finer than
  the logic lattice (50px), **the collision edge can sit up to 25px from the grass edge the player
  sees.** That goes away only if the tiles are ever re-authored at 16x16 / `scale = 3.125`, which
  is exactly one 50px cell and would let one tilemap serve both again.
- **ALL NINE EFFECTS ARE UNBUILT, AND THEY HAVE NO WORK-ORDER SECTION.** The manifest specifies
  them (boulder impact, fire explosion, enemy death puff, life-lost vignette, placement dust, wave
  banner, Rain impacts, and two skipped) but the work order only ever ran A5-1..A5-5, so there is
  no A5-N that builds them. **They are the one part of A5's stated scope with nothing written.**
  Decide whether they are an A5-6 or move to beta with the rest of the polish. Whoever takes them
  must read *THE RULE THAT GOVERNS BOTH AUDIO AND EFFECTS* first, and owes a `us_per_enemy`
  reading against one taken in the same sitting beforehand.
- **Effects 1 and 2** — sprite sheets, or built procedurally?
- **Music (`menu_loop`, `combat_loop`) is the only audio still outstanding** — excluded by user
  decision, 2026-09-10. The `Music` bus already exists; landing it means two `.ogg` files (tick Loop
  on import), a music player in `Audio`, and a Music slider in `_build_rows()`.
