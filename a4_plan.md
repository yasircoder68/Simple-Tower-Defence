# A4 — "MVP UI" — Implementation Work Order

**Status: ✅ COMPLETE 2026-09-08. All six steps shipped and verified. `round_ui.gd` is deleted.**

**THE SHIP GATE IS MET.** The game boots to a menu, plays, pauses, ends with a result screen that
tells a losing player their silver was kept, has an upgrade shop reachable from two places, and
has no debug UI anywhere on screen. **A4 was the only thing blocking an itch release.**

**The game now boots to a main menu and has a complete loop:** menu -> play -> pause -> menu,
and menu -> play -> result -> menu.

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

### U-3 — Result screen · ✅ **SHIPPED 2026-09-08**

`ui/result_screen/result_screen.tscn` + `.gd` — a centred card driven entirely by
`round_ended(won, gold_awarded, silver_earned)`. Headline (`Victory` in `SUCCESS` / `Defeat` in
`BLOOD`, both theme variations), waves survived, enemies killed, silver earned, gold, and a
context-sensitive button (`Play Again` / **`Upgrade & Retry`**).

#### The line this whole stage exists for

**A fresh save loses level_01 at wave 4 by explicit design.** So a new player's first game is a
loss, and the old panel said *"Round Lost / Earned: 422 silver"* — where "earned" reads as
*earned and then lost along with the round*, which is exactly backwards. The silver is banked
permanently and is what buys the win.

On a loss, and only on a loss, the screen now says:

> **You keep every silver you earned.**
> **Spend it on upgrades, then try again.**

A player who quits at that screen quits because the interface lied to them about the game's
central mechanic. This is not copywriting polish — it is the difference between a roguelite loop
and an apparent dead end, and it is the single most load-bearing change in A4.

#### One thing deliberately not inferred

`gold_awarded` is the **actual amount paid** — 0 on a replay, because `PlayerData.award_level_gold`
enforces gold-once. The screen therefore distinguishes *"Gold 12"* from *"Gold — already claimed"*
rather than deriving "gold was paid" from `won == true`, which CLAUDE.md warns against explicitly.
Verified live: a win on the already-cleared map1 correctly showed "already claimed".

#### A round-scoped kill counter

`kills_this_round` was added beside `silver_earned_this_round` — incremented in
`on_enemy_killed()`, reset on the same line, never written to `PlayerData`. Escapes are
deliberately not counted: it is a *kill* count, and the lives readout already says what got
through.

#### Verified

- **Both variants rendered and checked live**, driven through `_end_round()` — the same function
  the real loss and win paths call.
- **A full real round: 906 silver (the exact authored maximum), 408 kills, 20/20 lives, won.**
  408 is every enemy spawned (32+48+72+104+152), so **the new kill counter reconciles against the
  spawn table exactly**, and the per-wave silver was exact at every boundary (64 / 96 / 154 / 238
  / 354). That run mattered because U-3 put a counter in `on_enemy_killed()`, which is in the hot
  path of every kill.
- Play Again returns to `PRE_ROUND`, hides the screen, and resets the HUD to `Wave -`, `20/20`.
- **Zero errors** in `debugger_get_log`.

**No scrim, deliberately.** The pause screen dims the game because it is modal; this one does not,
because the player's next action after a loss lives behind it and a scrim would imply the game had
stopped. Worth revisiting at U-5 when the upgrade screen exists.

### U-4 — Main menu + scene flow · ✅ **SHIPPED 2026-09-08**

`ui/main_menu/main_menu.tscn` + `.gd`, and `run/main_scene` now points at it. Title, the player's
**persistent silver and gold**, Begin Defense, Quit.

Showing the currencies on the menu is the cheapest way to make meta-progression visible before the
player has played anything — a returning player sees immediately that their last run left them
better off, which is the hook the whole economy rests on.

#### Finding 1 confirmed by measurement: `/root/map1` survives

After Begin Defense, probed live:

```
map1_exists=true | current_scene=map1 | menu_gone=true | hud=true
```

`change_scene_to_file()` frees the menu and makes the level a **direct child of root**, so the
level's root node stays `map1` at `/root/map1`. **Every gotcha, `scope_path` and MCP verification
snippet in CLAUDE.md keeps working untouched** — the predicted "expect a docs pass" never
materialised, because scenes are replaced rather than nested.

**That is now an architectural constraint, recorded at the top of `main_menu.gd`: never add the
menu as a resident overlay above the level.** It would push the level down a level and invalidate
the whole verification toolkit for a purely cosmetic gain.

#### Two deviations from the plan

**No Upgrades button yet.** The plan listed *Begin Defense / Upgrades / Quit*, but the upgrade
screen is U-5. A disabled button would be dead UI on the first screen a stranger sees, so U-5 adds
the screen and its entry point together.

**The result screen gained a Main Menu button, which the plan did not call for.** It had to:
pausing is disarmed the moment a round ends (`pause_menu.setup(false)` in `_end_round`), so Escape
does nothing on the result screen — **without it, Play Again would be the only way out of a level,
forever, and the menu would be reachable only at launch.** Caught by walking the loop rather than
by reading it.

#### One trap, guarded

`resume()` runs **before** `menu_requested` is emitted. `change_scene_to_file` frees the tree but
`get_tree().paused` is tree-wide state that would **survive into the menu** — producing a main
menu whose buttons do nothing. Verified: `paused=false` immediately after returning, and the menu
was interactive (a second Begin Defense worked).

Both screens route through one `_on_menu_requested()` on the controller rather than each calling
`change_scene_to_file` themselves.

#### Verified

- **The full loop, driven through real button clicks:** menu -> level -> pause -> Quit to Menu ->
  menu -> level -> round end -> result -> Main Menu -> menu.
- `PlayerData` survives every transition (silver 28823 throughout). Nothing needed saving at the
  transition: `_end_round()` already flushes, and everything else is round-scoped by design.
- **`game_start` with the explicit level path still lands in a playable level** at `/root/map1` —
  the documented workaround for the changed boot scene, tested rather than assumed.
- **Zero errors** in `debugger_get_log`.

### U-5 — Upgrade screen · ✅ **SHIPPED 2026-09-08**

`ui/upgrade_screen/upgrade_screen.tscn` + `.gd` — a modal `CanvasLayer` reachable from **two**
places: the main menu's Upgrades button, and a HUD button that appears only between rounds.

**Self-contained, which is what makes one scene serve both contexts.** It reads `PlayerData` and
`TowerStats` and nothing else — both autoloads — so it never touches `map`. The identical scene
therefore works as a child of the main menu with **no level loaded at all** and as an overlay
inside a running level.

**No new backend**, as predicted: `try_upgrade()`, `get_upgrade_cost()`, `get_upgrade_level()` and
the `10 * 1.35^level` curve have been working since M1.

**The rows are generated from `TOWER_TYPES x UPGRADE_TRACKS`**, not authored in the `.tscn`, so a
third tower or a fourth track appears here for free. The scene owns the frame; the registry owns
the contents.

#### Risk 2 resolved: the gating was re-thought, not ported

`round_ui` asked `map.round_state == PRE_ROUND`, **a question that cannot be asked at the main
menu** — there is no round and no map. The rule underneath was never "PRE_ROUND"; it was
**"upgrades are allowed whenever no round is running"**, true both at the menu and between rounds.

So the opener answers it and the screen takes the answer: `open(allowed)`. The menu passes `true`
unconditionally; the level passes `round_state == RoundState.PRE_ROUND`. The shop never guesses.

**The authoritative guard survived the move**, and was re-verified the way M1 learned to:

| | |
|---|---|
| Mid-round, shop forced open | `_allowed = false`, button `disabled = true` |
| `click_node` fired at it anyway | **damage stayed Lv5 — no purchase** |

`input_simulate`'s `click_node` emits `pressed` directly and walks straight past a `disabled`
flag, which silently defeated the first version of this exact test in M1. A disabled Button is a
UI hint; the guard in the handler is the rule.

#### Verified

- **A real purchase from the main menu with no level loaded:** silver 29721 -> 29688 (-33), archer
  damage Lv4 -> Lv5, and the button relabelled to the escalated 45-silver cost. That single result
  is the whole point of the re-thought gating.
- The same purchase carried into the level, and the menu's currency readout refreshed on close
  (it is read once in `_ready()`, so a purchase behind it would otherwise leave a stale figure).
- The HUD's Upgrades button is **hidden** outside `PRE_ROUND` rather than disabled — a disabled
  shop button invites the click the guard then has to refuse.
- Escape closes the shop rather than falling through to the pause screen underneath it.
- **`round_ui.upgrade_panel` is now `null`** — round_ui builds nothing at all and is an empty
  shell. U-6 deletes it.
- **Zero errors** in `debugger_get_log`.

### U-6 — `round_ui.gd` deleted; docs pass · ✅ **SHIPPED 2026-09-08**

`ui/round_ui.gd` (341 lines) and its `.uid` are gone, along with the `round_ui` member and its
construction in `level_controller._ready()`. By the time it was deleted it built **nothing** — U-2
took the status labels and breather, U-3 the result panel, U-5 the upgrade panel — so the deletion
removed an empty shell rather than live behaviour. That is exactly what the additive ordering was
for.

Cross-references in `ability_manager.gd` and `ability_bar.gd` were repointed. The remaining
mentions across the codebase are deliberate **historical prose** — "round_ui learned this the hard
way" — which is the record of *why* the current code is shaped as it is, and is worth more than
tidiness.

#### It caught a bug I had introduced across four scenes

The controls hint rendered double-spaced. Measured rather than eyeballed: the Label's minimum
height was **92px for three 11px lines**, and the text contained
`Move: drag<CR><LF>Remove: right-click<CR><LF>Esc: pause`.

**Editing a `.tscn` with Python in text mode on Windows rewrites `
` as `

` — including the
newlines INSIDE a quoted multi-line string property.** Godot then renders the stray `
` as an
extra line break. Four scenes had been silently corrupted this way (`hud`, `main_menu`,
`pause_menu`, `result_screen` — 271 line endings in total); only `hud` had a multi-line `text`
property visible enough to show it.

Normalised back to LF, and the hint's minimum height dropped 92 -> 54, which is correct. **The
lesson is the general one: a file-writing tool that "helpfully" translates line endings will
corrupt data inside quoted strings, and the damage is invisible until something renders it.**

#### Acceptance — the ship gate, walked end to end

- **Boot -> main menu**, with persistent silver and gold on it.
- **Upgrades from the menu with no level loaded**, including a real purchase.
- **Begin Defense -> level**, `/root/map1` intact, **no debug panel anywhere**.
- **A full round: 894 silver, 407 kills, 17/20 lives, won.** A three-way reconciliation, and the
  tightest this project has managed: 12 silver short of the 906 maximum, 3 lives lost, and 407 of
  408 spawned enemies killed — **exactly one escaped ogre**, agreed independently by the silver
  total, the lives counter and the new kill counter.
- **Result screen -> Main Menu**, closing the loop.
- **Zero errors** in `debugger_get_log`.

---

## What A4 delivered, against what it set out to do

| Gate | State |
|---|---|
| Main menu | ✅ U-4, and it is the boot scene |
| Pause | ✅ U-1, one-line policy, verified frozen by state |
| Upgrade shop as its own screen | ✅ U-5, reachable from the menu and between rounds |
| `round_ui` dead | ✅ U-6 |
| Theme foundation | ✅ U-0, generated from ~20 constants |
| A losing player learns their silver was kept | ✅ U-3 — **the point of the stage** |

**Four bugs were found by testing rather than review**, and all four were invisible to reading the
code: Escape quitting the game (U-2), the HUD reading "Wave 5/5" in PRE_ROUND (U-2), the result
screen leaving the menu unreachable (U-4), and the CRLF scene corruption (U-6). Three of them were
found only by *driving the real input or walking the real loop* rather than calling the function
underneath it.

**Deferred to beta by design:** `ui_plan`'s UI-2 (sidebar rebuild), UI-3 (procedural icons) and
UI-5 (juice). None blocks a release, and beta already owns an *All UI screens finished* pass.

**Not taken:** the display font. It needs an external asset download and is left as a standalone
decision — still the best value-per-hour item available.

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
- A6 (gold sinks, more towers, the last two abilities) and A7 (level select, more levels) both
  **depend on A4** — level select is a screen, and screens arrive here.
- Every hour spent anywhere else is an hour the game stays unreleased for a reason that has
  nothing to do with whether it is fun.
