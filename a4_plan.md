# A4 — "MVP UI" — Implementation Work Order

**Status: IN PROGRESS. U-0 (theme), U-1 (pause) and U-2 (HUD) SHIPPED 2026-09-08.
U-3 (result screen) is next.**

**This is the stage that unblocks shipping.** A1 is built and exported and has never been put in
front of anyone, because the game opens straight into a level with no main menu, no pause, and an
upgrade panel bolted to the side of the play screen as a debug readout.

A3 was parked for exactly this reason — see [a3_plan.md](a3_plan.md)'s opening. Performance was
never what was stopping this game from being released.

---

## The ship gate

> **A stranger downloads the build, understands what they are looking at, plays, loses,
> understands that they kept their silver, upgrades, and plays again — with no debug panel
> anywhere on screen.**

That is the whole of A4. Anything that does not serve that sentence is deferred, and beta already
owns a dedicated *All UI screens finished · 6%* pass for the rest.

---

## Scope — build the minimum that ships, not all of `ui_plan.md`

[ui_plan.md](ui_plan.md) is ~16h across six stages. Most of it is polish, and polish is not what
has kept this game unreleased for months.

| `ui_plan` stage | A4? | Reasoning |
|---|---|---|
| **UI-0** theme foundation | ✅ **in** | no dependencies, gates every screen, cheapest item in the stage |
| **UI-1** HUD | ✅ **in, trimmed** | `round_ui` currently *is* the HUD, so killing it needs a replacement. Readouts yes; count-up tweens, vignettes and flashes no |
| **UI-4** screens | ✅ **in** | menu, pause, upgrade, result — this is the actual stage |
| UI-2 sidebar rebuild | ❌ defer | it works. Imperative construction is ugly, not broken |
| UI-3 procedural icons | ❌ defer | placeholder pixels are fine for an alpha, and art is a **beta** deliverable regardless |
| UI-5 juice | ❌ defer | polish by definition |

**Fix in passing:** `ui_plan.md`'s UI-4 still lists a **"souls"** currency. That was removed by
decision on 2026-09-03 — silver and gold only. Corrected as part of A4's planning.

---

## What already exists — do not rebuild any of it

**A4 is relocation and reskin, not new systems.** Everything below is built, wired and verified:

**Every signal a HUD needs**, so it can be fully signal-driven with **zero backend work** —
nothing has to poll `_process`:

| Source | Signals |
|---|---|
| `PlayerData` | `silver_changed`, `gold_changed`, `upgrade_changed` |
| `base_health` | `life_lost`, `lives_depleted` *(see Known issue 1c — emitted, connected to nothing)* |
| `level_controller` | `round_started`, `round_ended(won, gold_awarded, silver_earned)` |
| `wave_manager` | `wave_started(num, total, count)`, `wave_cleared`, `breather_started`, `all_waves_complete` |
| `ability_manager` | `cooldown_changed`, `selection_changed` |

**The whole upgrade economy.** `TowerStats.try_upgrade()`, `get_upgrade_cost()`, the
`10 * 1.35^level` silver curve, and `PlayerData.upgrade_changed` are all working and verified
since M1. A4 wires a screen to a working economy; it does not build one.

**`ui/ability_bar/`** is already its own scene and already a permanent UI element — built that way
in A1 deliberately, so it would not have to be built twice. Leave it alone.

**`ui/build_sidebar/`** works. Leave it alone (that is `ui_plan` UI-2, deferred).

---

## Three findings that change the shape of the stage

### 1. `/root/map1` SURVIVES the main menu — if scenes are replaced, not nested

alpha_plan's A4 sketch warned that a main menu "changes the main scene, and therefore
`/root/map1` — the path every MCP verification in these docs is written against. Expect a docs
pass."

**That is only true for a resident menu.** `get_tree().change_scene_to_file()` frees the current
scene and makes the new one a direct child of `root`, so the level's root node is **still `map1` at
still `/root/map1`.** Every gotcha, every `scope_path`, and every verification snippet in CLAUDE.md
keeps working untouched.

> **Scene REPLACEMENT is therefore an architectural constraint of this stage, not an
> implementation detail.** It protects ~15 documented gotchas and the entire MCP verification
> toolkit. A nested or additive menu would invalidate all of it for a purely cosmetic gain.
> **Do not add the menu as a resident overlay above the level.**

The real docs change is smaller and different: `run/main_scene` moves from `level_01.tscn` to the
menu, so **`game_start` with `scene_path: "main"` now lands on the menu rather than a playable
level.** Verification sessions need either one `click_node` on Begin Defense, or `game_start` with
the explicit level path. That is one new gotcha, not a pass over all of them.

### 2. Pause is the OPPOSITE problem to the one the sketch predicts

The sketch says `wave_manager`'s two `Timer`s, `ability_manager`'s `_process` cooldown tick and the
boulder's `Tween` each "need a deliberate `process_mode`, or pausing either fails to stop the horde
or permanently strands a cooldown."

**Measured instead of assumed:** there is no `process_mode`, `paused`, or `PROCESS_MODE_*` anywhere
in the project. Everything sits at the default `PROCESS_MODE_INHERIT`, which means
`get_tree().paused = true` **already** stops all of it — the horde, both Timers, the cooldown tick,
and node-bound Tweens.

> **The work is one exception, not four rules.** Policy, in one line:
> **everything inherits; only the pause overlay is `PROCESS_MODE_ALWAYS`.**

Three traps that *are* real:

- **The HUD must NOT be `ALWAYS`**, or it keeps animating behind the pause screen. Put the HUD and
  the pause overlay on **different `CanvasLayer`s**.
- **The input handler that toggles pause must be on the `ALWAYS` node**, or the unpause key is
  dead and the only way out is Alt-F4.
- **Verify `ability_manager`'s cooldown is delta-accumulated, not wall-clock.** A
  `Time.get_ticks_msec()` deadline survives a pause and snaps to zero on resume. One-line check; if
  it is a deadline, it has to change. *This is the one place the sketch's "stranded cooldown"
  worry is genuinely live.*

### 3. `round_ui.gd` is not one deletion — it is four relocations

Its 341 lines hold four unrelated things that belong in four different places:

| Inside `round_ui.gd` | Destination |
|---|---|
| silver / gold / lives / wave labels | the HUD (U-2) |
| breather panel + skip button | the HUD (U-2) |
| result panel + Play Again | the result screen (U-3) |
| upgrade panel + buttons | the upgrade screen (U-5) |

**That is why deleting it is the LAST step, not the first.** Direct application of A1's own lesson:

> *Make the seam commit purely additive. An earlier draft of the A1 plan deleted `spawn_zombies()`
> up front — that would have left the game with no enemies at all for eight commits.*

`round_ui` stays alive and working until every piece has a replacement.

---

## The ladder

Each step is independently committable and leaves the game playable. Rough estimates; treat them
as relative weights, not a schedule.

### U-0 — Theme foundation · ✅ **SHIPPED 2026-09-08**

**What landed:**

- **`ui/palette.gd`** — 20 constants: four ground tones, five interactive states, four semantic
  colours, two text colours, a five-step type scale, and four metrics. `extends RefCounted` +
  preload, matching `systems/enemy_types.gd`'s precedent for a numbers-only registry — which also
  sidesteps the documented "a new `class_name` is invisible until the editor rescans" gotcha.
- **`ui/build_theme.gd`** — the generator, emitting `ui/game_theme.tres` (10KB).
- **Registered project-wide** via `gui/theme/custom`, so it cascades to every `Control` with no
  per-node wiring.

**Two deviations from the plan, both deliberate:**

1. **The generator is a `SceneTree` script, not a `@tool` script.** `ui_plan` specified `@tool`,
   which means triggering it by hand from inside the editor. A `SceneTree` script runs headless
   from one shell command — scriptable, CI-able later, and independent of whether the editor is
   open. Same output, fewer moving parts:

   ```
   Godot_v4.6.3-stable_win64.exe --headless --path "<repo>/game" --script res://ui/build_theme.gd
   ```

2. **A silver colour was added to the palette.** `ui_plan`'s palette has one currency colour
   (`GOLD`), because it predates the silver/gold split. Silver is the currency the player actually
   watches tick up, so it needs its own.

**The display font was NOT taken.** It requires downloading an external asset; left as a
standalone decision rather than folded in silently.

#### Risk 1 fired exactly as predicted, and twice

The plan said *"U-0 will break existing layouts on day one... budget fix-up time inside U-0. The
theme is not a cosmetic-only change."* It did:

- **The upgrade panel overflowed its own background by three rows**, visible on the very first run.
  Its height was hardcoded to 240px against Godot's *default* button metrics; the theme gives every
  button content margins, and six buttons no longer fit.
- **The breather panel had exactly ZERO slack** — VBox minimum height 60 inside 60px of space. It
  rendered correctly and was one palette tweak from clipping the Skip button. **Found by measuring
  `get_combined_minimum_size()` against `size`, not by looking at it** — the screenshot looked fine.

**Both fixed by making the panels size to their content** (`Panel` -> `PanelContainer`, dropping
the manual insets in favour of the theme's own content margins) rather than by bumping the
numbers. Bumping would have deferred the identical bug to the next palette change — which is
precisely the thing a generated theme exists to make cheap. The result panel was measured too and
had 17px of slack; it was left alone.

**The lesson worth carrying to U-2 onward:** *a hardcoded panel size is a latent break every time
the palette moves.* Build every new panel content-sized from the start.

#### Verified

- All three `round_ui` panels render correctly, including the breather **on its live path** (shown
  by the wave manager, not by hand).
- **Waves 1 and 2 paid exactly +64 and +96**, lives 20/20 — U-0 touches no gameplay, and the
  project's sharpest regression detector agrees.
- **Zero errors** in `debugger_get_log`.
- Disabled upgrade buttons are dimmed **but still legible**, which is what `DISABLED_TEXT` exists
  for: greying a cost into the background is how a player ends up unable to read what they cannot
  afford.

### U-1 — Pause · ✅ **SHIPPED 2026-09-08**

`ui/pause_menu/pause_menu.tscn` + `.gd` — scrim, centred card, Paused / Resume / Restart Round /
Quit to Desktop. Instantiated by `level_controller._ready()` and wired through three signals
(`resume_requested`, `restart_requested`, `quit_requested`), so the screen emits *intent* and the
controller decides what it means — the same split every other manager here uses.

**Finding 2 confirmed: the whole policy is one line.** `PROCESS_MODE_ALWAYS` on the pause
CanvasLayer, and nothing else in the project sets `process_mode` at all. `ability_manager` was
checked and does `remaining = max(remaining - delta, 0.0)` — delta-accumulated, not a wall-clock
deadline, so it freezes correctly. **Any future cooldown, timer or duration must be
delta-accumulated for the same reason**; that is now the standing rule.

**Verified by state across real wall-clock, not by looking:**

| Held paused | Before | After | Real time elapsed |
|---|---|---|---|
| enemy position | `(647.1979, 510.6771)` | `(647.1979, 510.6771)` | 12 s |
| ability cooldown | `23.4669279999997` | `23.4669279999997` | 12 s |
| **breather `Timer`** | `0.93333333333316` | `0.93333333333316` | **15 s** |

The breather Timer is the strongest of the three: it was **0.93 s from firing** and did not fire
across fifteen seconds of wall clock — the round stayed on wave 1, phase 3, with zero enemies.
Unpaused, it resumed and spawned wave 2 normally. That covers both mechanisms — `_process` ticks
(the cooldown) and `SceneTree` Timers — and both directions, freeze *and* resume.

**Risk 4 (restart must go through the real path) handled and verified.** Restart calls
`start_new_round()` — the same path "Play Again" uses — rather than re-implementing a reset.
Measured after a restart from pause: tree unpaused, `PRE_ROUND`, enemies cleared, towers kept,
lives reset, Start button shown, pause disarmed, screen closed. **`resume()` is called BEFORE the
signal is emitted**, because restarting into a still-paused tree is a soft lock that looks exactly
like a crash — the new round exists and nothing in it moves.

**Pause is armed only inside a round** (`pause_menu.setup(true/false)` from `_start_round`,
`_end_round` and `start_new_round`), matching the existing rule that abilities are inert outside
`IN_ROUND`. A pause screen over the build phase would stop nothing.

**Quit is quit-to-DESKTOP for now**, not a stub that does nothing: there was previously no
graceful way to exit the game at all. U-4 turns it into quit-to-menu with quit-to-desktop below.

**Acceptance:** a full round after the change earned **906 silver — the exact authored maximum**
(64 / 96 / 154 / 238 / 354, every wave exact, zero escapes), 20/20 lives, won, **zero errors** in
`debugger_get_log`. U-1 touches the round lifecycle in three places, so this was the run that
mattered.

### U-2 — HUD · ✅ **SHIPPED 2026-09-08**

`ui/hud/hud.tscn` + `hud.gd` — a `CanvasLayer` at the default process mode (**never `ALWAYS`**, or
it would animate behind the pause screen). A stats panel with Silver / Gold / Lives / Wave in a
two-column grid using the theme's `Muted` + semantic label variations, the controls hint, and the
breather panel with its countdown and Skip button.

**Entirely signal-driven, with zero backend work** — every number already had a signal behind it,
because A1 and A2 built the managers signal-first for exactly this. The one poll is the breather
countdown, which reads a `Timer` in `_process`: `time_left` changes every frame, so a signal per
frame to move one label would be worse than reading it. Guarded on visibility, so it costs nothing
the rest of the round.

**`round_ui` suppression skips CONSTRUCTION, not visibility.** `setup(map, suppress_status)` no
longer builds the status labels or breather panel. Hiding them would have left live signal
handlers fighting the HUD for the same state and a `_process` still ticking a second countdown.
`round_ui` keeps only the result and upgrade panels until U-3 and U-5 replace them.

#### It found a bug U-1 had shipped: Escape quit the game

`ui/fps_counter.gd` — the loose FPS label in `level_01.tscn` — contained:

```gdscript
if Input.is_action_just_pressed("ui_cancel"):
    get_tree().quit()
```

**`Input.is_action_just_pressed()` POLLS**, so the pause screen's `set_input_as_handled()` could
not suppress it. Pressing Escape opened the pause menu *and* quit the process in the same frame.

**Verified before fixing** — simulating `ui_cancel` killed the running game
(`GAME_NOT_RUNNING` on the next call) — and verified again after: Escape now pauses, and pressing
it again resumes.

**U-1's testing missed this because it drove `pause()` directly and never exercised the real key.**
That is the lesson worth keeping: *a feature bound to an input is not tested until the input is
tested.* The node is gone from `level_01.tscn`, `ui/fps_counter.gd` is deleted as a verified
orphan, and the FPS readout lives in the HUD behind `show_fps` (default **off**) with no quit
behaviour. Quitting is now a deliberate choice from the pause screen.

#### And a bug of its own, caught the same way

After Play Again the HUD read **"Wave 5/5" while sitting in PRE_ROUND**. `start_new_round()` does
not emit `round_started`, so nothing cleared the wave counters — I had guarded the *lives* half of
that trap and missed the *wave* half. Fixed with `reset_for_new_round()`, which clears the
counters and refreshes; `refresh()` alone stays safe to call mid-round.

**That asymmetry has now caught this project three times** (the result panel, the lives readout,
and this). It is the strongest argument in the codebase for U-6 deleting `round_ui` rather than
leaving two things listening to the same lifecycle.

#### Verified

- **Full round, waves 1-4 reconciling exactly**, including two partial waves — wave 3 was 12
  silver and 3 lives short (**exactly one escaped ogre**) and wave 4 was 28 silver and 8 lives
  short (**exactly two ogres plus two smalls**). The round then ended in a loss at wave 5, which
  is the documented short-circuit path where remaining enemies are force-cleared and do not pay.
  Run with two towers rather than the four-tower baseline, which is why it lost.
- **Escape pauses and resumes**, tested through simulated input rather than by calling `pause()`.
- **The breather panel works on its live path**, shown by the wave manager with a ticking
  countdown.
- Play Again returns the HUD to `Wave -`, `Lives 20/20`, hint at full alpha; a fresh Start
  repopulates it to `Wave 1/5`.
- **Zero errors** in `debugger_get_log` throughout.

### U-3 — Result screen · ~2h

- Win/lose, waves survived, kills, gold awarded — and **explicitly "silver kept: N"**.
- Replaces `round_ui`'s result panel; `round_ui`'s copy hidden, not deleted.

### U-4 — Main menu + scene flow · ~2h

- New main scene: **Begin Defense / Upgrades / Quit**.
- `change_scene_to_file` only — see finding 1.
- Wires U-1's Quit-to-menu.
- `run/main_scene` changes here; so does the `game_start` gotcha.

### U-5 — Upgrade screen · ~3h

- Relocates `round_ui`'s upgrade panel to a real screen, reachable from the menu **and** between
  rounds.
- Re-thinks the gating rather than porting it — see risk 2.

### U-6 — `round_ui.gd` deleted; docs pass · ~1h

- Delete the file and its construction in `level_controller._ready()`.
- CLAUDE.md: the new `game_start` gotcha, the pause policy, the retired `round_ui` references
  (including the button-path gotcha, which becomes obsolete).
- alpha_plan.md: A4 → ✅.

---

## Risks

1. **U-0 will break existing layouts on day one.** A project-wide theme instantly restyles
   `round_ui`, `build_sidebar`, `ability_bar` and `StartButton` — all laid out against *default*
   font metrics with hardcoded offsets. Bigger text means bigger controls, and the documented
   *"`set_anchors_preset()` alone leaves a procedurally created Control at size (0,0)"* trap fires
   immediately. **Budget fix-up time inside U-0. The theme is not a cosmetic-only change.**
2. **Upgrade gating must be re-thought, not ported.** `_upgrades_allowed()` reads `round_state`,
   but a menu-level shop has no round at all. The correct rule is **"upgrades are allowed whenever
   no round is running"** — true both at the menu and in `PRE_ROUND`. And the authoritative guard
   **stays in the handler**: `input_simulate`'s `click_node` bypasses a Button's `disabled` flag,
   which silently defeated the first version of this exact test once already.
3. **`change_scene_to_file` frees the level**, so anything holding a reference across the
   transition dangles. Only the autoloads (`PlayerData`, `TowerStats`) legitimately survive —
   which is precisely what CLAUDE.md's state-boundary table already says.
4. **Restart-from-pause must go through the real path.** `start_new_round()` deliberately does
   **not** emit `round_started`, and `round_ui` learned that the hard way (the result panel stayed
   on screen after Play Again). A Restart button that skips it will strand UI state the same way.
5. **Known issue 1c becomes live-r.** `lives_depleted` is emitted and connected to nothing; the
   loss is driven by an inline check in `on_enemy_escaped()`. A4 adds screens that react to the
   round ending, which makes "the signal that looks like it is in charge" more tempting to bind to.
   **Either connect it or delete it while in here.**

---

## Acceptance

- **The whole point, tested as one flow:** a fresh save, played start to finish — menu → play →
  lose at wave 4 → **the result screen states the silver was kept** → upgrade from the menu →
  play again → win. CLAUDE.md calls the current version of this out by name as A4's job.
- **Pause verified by state, not by looking.** With the tree paused: enemy positions frozen, both
  wave Timers stopped, ability cooldowns not advancing — and all three correct on resume.
- **Per-wave silver still reconciles exactly** (wave 3 = `+154`, wave 4 = `+238` at
  `difficulty_scale` 1.6). A4 must not touch gameplay at all, so any drift means something got
  mis-wired. This is the sharpest regression detector the project has and it costs one round.
- **Zero errors in `debugger_get_log`** — *not* `editor_get_console`, which cannot show a running
  game's runtime errors and is the easiest false negative available here.
- **No debug UI on screen** in a default build.

---

## Two decisions defaulted rather than asked

**The aesthetic.** `ui_plan` explicitly defers this ("you don't have to answer yet... pick after
UI-0 exists and you can see it"), so U-0 builds its restrained dark-fantasy palette and it gets
looked at. It is ~15 constants in one file — changing direction later is a one-command reskin,
which is the entire reason the theme is generated.

**The FPS counter.** Folded into the HUD behind a debug flag rather than shipped visible.

---

## Why this is the right stage to do now

- A1 and A2 are complete, verified, and exported. **The game works.**
- A3 is parked; the enemy ceiling (~420) is 2.7x what the waves actually use (152).
- A5 (gold sinks, more towers, the last two abilities) and A6 (level select, more levels) both
  **depend on A4** — level select is a screen, and screens arrive here.
- Every hour spent anywhere else is an hour the game stays unreleased for a reason that has
  nothing to do with whether it is fun.
