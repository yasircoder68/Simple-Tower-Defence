# Alpha — Public on itch.io

**Audience:** anyone. Released publicly on itch across a series of updates, to build a following
while the game is still being figured out.

**Graphics:** rough. Placeholders throughout, with only a small first batch of real art near the
end of the run. **Do not spend on visuals here** — alpha exists to find out whether the game is
fun before any money goes into making it look good.

**Share of remaining work: 40%.**

---

## Why alpha is a series, not a milestone

Shipping one big alpha earns one day of attention. Shipping six times earns six, and each update
gives people who already played a reason to come back. So alpha is structured as numbered
releases, each one genuinely playable and each with a headline a player would actually care
about.

The first release should go out **soon**. The loop already works — place towers, kill things,
earn silver, buy upgrades, replay. What it lacks is escalation and anything to do while a round
runs. That is a small gap, and closing it is enough to justify a first public build.

> [!IMPORTANT]
> **That last paragraph has not survived contact.** A1 closed exactly the gap it names — escalation
> and a live input — and the build still has not gone out, because the *real* blocker turned out to
> be interface, not mechanics: no main menu, no pause, and an upgrade panel that reads as a debug
> readout. That is what **A4 — MVP UI** now exists to fix.
>
> The tension worth naming: under the current ordering nothing ships until A4, which sits behind
> A2 and A3 — **20% of remaining work**. A1+A2+A3 then arrive as one large release, which is
> precisely what this section argues against. That may well be the right trade (shipping a thin
> game once badly is worse than shipping a thick one once well), but it should be a decision
> rather than a drift.

---

## The run at a glance

| Stage | Headline | Share | State |
|---|---|---|---|
| **A1** | "it's a game now" — waves + the boulder | 6% | ✅ built, exported, **not shipped** |
| **A2** | enemy variety + Rain of Arrows | ~5.5% | ✅ **built, verified, complete** |
| ~~**A3**~~ | ~~big battles — the horde engine~~ | ~2% spent | **MOVED TO [beta_plan.md](beta_plan.md)** 2026-09-07. D-1 shipped (−40.7%); the rest is beta work |
| **A4** | **MVP UI — menu, pause, upgrade screen** | ~6% | ⏭️ **NEXT** — planned, see [a4_plan.md](a4_plan.md); **unblocks shipping** |
| **A5** | more ways to build and fight — towers, gold sinks, slots, the last two abilities | ~7.5% | sketch |
| **A6** | a campaign shape — level select, more levels | ~4% | sketch |
| — | running throughout: first art batch | ~2% | |

Adding A4 as its own stage pushed alpha's share of remaining work from 40% to roughly 43%. The
shares are estimates and A5 absorbed a reduction, since some of its interface cost moved into A4.

**Moving A3's horde engine to beta (2026-09-07) took ~10% back out**, leaving alpha at roughly
**33%** and beta at roughly **50%**. A3 had already spent ~2% on D-1, which shipped and stays.
**A4 is now the next stage**, which is the whole point of the move — it is the only thing between
this project and an itch release.

**Moving A-2 Divine Smite and A-3 Dragon Fire from A2 to A5** (2026-09-06) shifted roughly 2.5%
between those two stages; the alpha total is unchanged. Both are cheaper than originally scoped
because A2's A-1 already built the machinery they needed — see A5 below.

---

## The release run

### A1 — "it's a game now" · 6% ✅ BUILT

The round becomes something you play rather than watch.
**Full work order: [a1_plan.md](a1_plan.md)** — implemented and verified live in twelve commits.

A round is now 408 enemies across 5 escalating waves at 60 FPS, with a breather between each and
a boulder ability as the live input, ending won or lost from a single Start press.

**A Windows export exists** (`export/game.exe`, presets committed at `game/export_presets.cfg`).
Two things checked while planning A3:

- **The MCP toolkit addon self-gates correctly.** `mcp_runtime_server.gd` disables itself on
  `not OS.has_feature("editor")`, which covers *any* export template, debug and release alike — so
  the shipped build does **not** open a WebSocket server. Worth recording, because it is the first
  thing anyone would reasonably suspect of a dev addon that ships.
- **Worth confirming before upload:** that the export is a *release* build rather than debug (the
  ~100 MB size and the `game.console.exe` wrapper both suggest debug), and optionally an
  `addons/*` exclude filter — though at a 762 KB `.pck` the saving is negligible either way.

What remains before this is actually *released*: a hand playtest to confirm `difficulty_scale`
1.6 is winnable with ability use (see a1_plan's caveat — it was never measured), and the itch
upload itself.

- **Progressive waves.** Difficulty escalates within a level instead of one flat batch of
  enemies every time. Right now the power curve rises forever and nothing pushes back — this is
  the fix. Escalation is **density only** — count and spawn interval. Enemy HP and speed stay
  constant across waves, so waves never touch the enemy scene.
- **One cooldown ability: the boulder.** Hold left mouse to aim, release to drop; 3s cooldown.
  Towers are pre-placed and auto-fire, so an ability is the *only* live input a round has.
  Without one, a round is a spectator phase.
- A short breather between waves. Not a build phase — placement still happens once, before the
  round starts, and stays locked through the breather.

**Ship it.** This is the first itch release.

> **Scope note.** A1 originally carried all three cooldown abilities; they moved to A2 to get the
> first public build out sooner. The boulder's 3-second cooldown makes it a different kind of
> thing from the 30/60/90s abilities — it is the baseline verb of a round, not a special, so it
> stands on its own as A1's live input. The move also fixes a design problem for free: Divine
> Smite's "huge single-target damage" is meaningless while every enemy has 10 HP, and A2 is
> exactly where the enemies worth smiting arrive.

### A2 — enemy variety · ~5.5% ✅ COMPLETE

**Full work order: [a2_plan.md](a2_plan.md).**

- Several enemy types with genuinely different roles: fodder in huge numbers, a fast rusher that
  punishes slow-firing towers, a heavy that must not be allowed through. **Goblin, Skeleton,
  Ogre** — the Troll boss is deliberately deferred past A2 (see the work order).
- The approved rename from zombies to the medieval goblin horde — split into a *machinery*
  rename (`zombie_*` → `enemy_*`, since the grid and counters mean "any enemy") and an *entity*
  rename (zombie → goblin).
- A shared foundation for enemies so adding the next one is cheap: `class_name Enemy` plus a
  stat registry, so a new type is a `.tscn` and a dict entry.
- **Rain of Arrows** — the first of the three abilities deferred from A1, and the one that proved
  the ability registry generalises. It also introduced **directional (rotatable) aiming** and the
  optional `SHAPE` mechanism on the aim marker, neither of which was in A2's original scope.
- **Divine Smite and Dragon Fire moved to A5** (2026-09-06). They were never blocking A2's
  headline — enemy variety — and A-1 had already built the machinery both of them needed.

A2 also closes two debts A1 left open: the Ogre's 80 HP makes the archer's damage upgrade track
meaningful (**Known issue 1, verified dead** — 8 archer hits, dropping to 7 after one damage
upgrade), and gives Divine Smite a target worth a 60s cooldown even though Smite itself now ships
in A5.

**A fresh save loses level_01 at wave 4** — measured, and deliberately left alone (2026-09-06).
Four base archers fire 8 shots/sec against wave 4's ~16.7 enemies/sec; upgrades close the gap.
The lost round still banks its silver, which buys the win on the replay, so the intended grind
loop works. It does mean **a new player's first game is a loss with no explanation** — an
onboarding problem for A4, not a reason to cut enemy counts.

**Two defects surfaced while verifying the ogre**, both in `_build_waves()`, both fixed: scaled
wave totals drifted +1 once a third enemy group existed, and `SKELETON_PACK` was **inert** — the
`pack` key was dropped, so skeletons had never once arrived as a squad in any round played or
measured. E-4's acceptance check only read wave totals, which that bug does not affect.

### A3 — big battles · ~2% spent · **MOVED TO BETA (2026-09-07)**

**The horde engine is no longer an alpha stage.** What remains of it lives in
[beta_plan.md](beta_plan.md) under *The horde engine*. This entry is kept because A3 did ship
something, and because dissolving the stage left two dependencies that had to be rehomed — see
below, they are the part that bites.

**Why it moved.** Not because it failed — because it was invisible:

> Waves top out at **152 concurrent enemies**, and the game already ran those at 60 FPS *before*
> any of A3's optimisation. Every hour spent on the enemy ceiling changed nothing a player could
> see, while the thing actually blocking an itch release — no main menu, no pause, a debug
> upgrade panel — sat untouched. **A4 was always the real blocker.**

The ceiling is headroom for a horde that has not been designed yet. That makes it beta work, where
"the screen fills with enemies" is a store-page screenshot rather than an invisible refactor.

**What A3 shipped before it was parked** (~2% of the roadmap, and it stays shipped):

- **D-1 — density-gradient separation** (`4901672`). The pairwise 3x3 neighbour scan deleted;
  enemies now deposit mass into a density field and read its gradient. **−40.7% `us_per_enemy`**
  at 600 packed, verified with two full rounds before and after that produced the same two
  outcomes in the opposite order. The ceiling went from ~250 to ~420.
- **A bench that does not lie.** `systems/bench.gd` had a real measurement bug —
  `TIME_PHYSICS_PROCESS` lags, and sampling it per frame carried the previous run's value into the
  next run's results. Found and fixed (`BENCH_TAG "M-0b"`). That bug had already produced one
  entirely fictional finding ("the harness degrades +45% within a process").
- **Three hypotheses killed by measurement rather than argument:** dictionary hashing (P-2, −3.9%,
  noise), the physics broadphase (S-1, `phys_pairs` 180 → 0, no change at all), and the manager
  loop (bounded at ~10% before it was built).

**What moved to beta:** D-1b (density-damped speed), D-2 (Continuum Crowds proper), X-\*
(de-nodify + MultiMesh), and the refuted micro-optimisation ladder as a record.

---

#### The two things dissolving A3 broke, and where they went

**1. The TileMapLayer migration (T-1) lost its home — it is now A6's problem.**

CLAUDE.md Known issue 5 says to bundle it with the horde rewrite **or** do it immediately before
building levels 2–15, *whichever comes first*. With the horde rewrite in beta, **A6 comes first**,
so A6 now owns it. A6 already said it was "blocked on A3's TileMapLayer migration"; that sentence
would have pointed at a stage that no longer exists.

This is the kind of thing that silently falls through a crack during a re-plan, so it is written
down in three places: here, in A6 below, and in Known issue 5.

**2. Overlapping waves no longer needs the horde engine — D-1 bought the headroom.**

[a1_plan.md](a1_plan.md) deferred overlapping waves to A3 on the grounds that overlap raises the
concurrent enemy count, and the engine could not take it. Two waves of 152 is ~300 concurrent,
against a pre-D-1 ceiling of ~250 — genuinely blocked. **Post-D-1 the ceiling is ~420, so modest
overlap fits today.**

It is a gameplay feature, not a performance one, and it is the better update headline of the two
("a bigger sequential wave is the same fight bigger; overlap is what makes it *overwhelming*").
**Folded into A5.** The deferred cost is unchanged and still real: overlap needs a wave tag on
every enemy and per-wave decrements, because today a dying enemy unambiguously belongs to the
current wave and one counter suffices.

### A4 — MVP UI · ~6% · **the stage that unblocks shipping** · **NEXT**

**Full work order: [a4_plan.md](a4_plan.md)** (planned 2026-09-08). The sketch below is kept
because it is what the plan was written from; a4_plan supersedes it where they differ, and it
differs in three places worth knowing:

- **`/root/map1` survives the main menu** if scenes are *replaced* rather than nested — so the
  "expect a docs pass" warning below is mostly wrong, and scene replacement became an
  architectural constraint of the stage rather than an implementation choice.
- **Pause is one exception, not four rules.** Nothing in the project sets `process_mode` at all,
  so `get_tree().paused` already stops the horde, both wave Timers and the cooldown tick. Only the
  pause overlay needs `PROCESS_MODE_ALWAYS`.
- **Scope was cut deliberately.** A4 takes `ui_plan`'s UI-0, a trimmed UI-1 and UI-4. UI-2
  (sidebar rebuild), UI-3 (procedural icons) and UI-5 (juice) are deferred — beta already owns an
  *All UI screens finished* pass, and none of the three is a release blocker.

**This is why nothing has shipped yet.** A1 is built and exported, but the game opens straight
into a level with no main menu, no way to pause, and an upgrade panel bolted to the side of the
play screen as a debug readout. That is not a build you put in front of strangers, and alpha's
whole premise is putting builds in front of strangers.

The three gaps, in the order a player hits them:

- **Main menu** — Begin Defense / Upgrades / Quit. Today `level_01.tscn` *is* the main scene.
- **Pause menu** — Resume / Restart / Quit to menu. There is currently no pause at all.
- **The upgrade shop as its own screen**, not a panel wedged beside the tower sidebar.

Plus the two that fall out of doing those properly:

- **UI-0, the theme foundation** — `ui_plan.md`'s palette + generated `Theme`. It has **no
  dependencies**, gates everything else, and is the cheapest item in the stage.
- **`round_ui.gd` finally dies.** It is explicitly throwaway and has now had A1's wave counter and
  breather panel bolted onto it. Every further bolt-on is work done twice.

**Four things to know before planning this in detail:**

1. **The upgrade shop needs no new backend.** `TowerStats.try_upgrade()`, `get_upgrade_cost()`,
   `PlayerData.upgrade_changed` and the silver curve all exist and are verified. A4 is relocation
   and reskin, not new economy.
2. **Pause is not free.** `wave_manager` owns two `Timer`s, `ability_manager` ticks cooldowns in
   `_process`, and the boulder payload runs a `Tween`. Each needs a deliberate `process_mode`, or
   pausing either fails to stop the horde or permanently strands a cooldown. Decide the policy
   once, for all of them.
3. **A main menu changes the main scene**, and therefore `/root/map1` — the path every MCP
   verification in these docs and in CLAUDE.md's Gotchas is written against. Expect a docs pass.
4. **Upgrades are `PRE_ROUND`-only, enforced in two places** (the buttons' `disabled` flag and an
   authoritative guard in the handler). Moving them to a menu-level screen changes where "between
   rounds" is even defined — rethink the guard rather than porting it.

*~~Note: `ui_plan.md`'s UI-4 stage still mentions a "souls" currency... fix when A4 is planned.~~*
**Fixed 2026-09-08** during A4 planning — `ui_plan.md` now reads silver/gold throughout.

### A5 — more ways to build and fight · ~7.5% *(was A4)*

- **The last two abilities, moved here from A2** (2026-09-06):
  - **Divine Smite** (60s, single target) — now the *easy* case. Point-aimed and circular, so it
    takes the "one registry entry plus one payload folder" path A2's A-1 demonstrated, with no
    change to `ability_manager` or `aim_marker` at all. Its design problem — needing a target worth
    a 60s cooldown — was already solved by A2's Ogre.
  - **Dragon Fire** (90s, strafing run) — was scoped as "the one place the system strains", and
    A-1 removed most of that strain. The `aim_marker` `SHAPE` mechanism it needed **already
    exists** (Dragon Fire adds a `"strip"` branch rather than creating the mechanism), and
    directional drag-aiming exists too, so the planned fixed left→right axis compromise can be
    dropped. Decide that here rather than inheriting either answer.
  - Both are multi-tick payloads, so both obey A-1's rule: check the round at the top of every
    tick, and `is_instance_valid()` **every** tick. And neither may read `global_position` or
    `global_rotation` in `_ready()` — `cast()` assigns both after `add_child()`.
- Additional tower types beyond the starting two, so loadout becomes a real decision.
- **Gold finally does something.** Today gold is earned once per level and can be spent on
  nothing at all — half the economy is inert. Gold buys tower unlocks and extra placement slots.
- More placement slots, so the four-tower cap becomes a choice rather than a wall.
- **Overlapping waves, inherited from the dissolved A3.** Deferred by a1_plan on the grounds that
  overlap needs an engine that can hold ~300 concurrent enemies; **D-1 raised the ceiling from
  ~250 to ~420, so it fits now.** It is a gameplay feature and the better headline of the two —
  a bigger sequential wave is the same fight bigger, overlap is what makes it *overwhelming*.
  The deferred cost is unchanged: it needs a wave tag on every enemy and per-wave decrements,
  because today a dying enemy unambiguously belongs to the current wave and one counter suffices.

**This is smaller than it looks.** `PlayerData` already has `spend_gold()`, `unlocked_towers`,
`is_tower_unlocked()` and `slot_count`, all persisted and all working since M1 — A5 is wiring a UI
to a working economy, not building one. The same is true of the two abilities: the registry, the
cooldown dict, the bar and both aim modes are all built and verified.

**Two traps.** Any new tower must join the `tower_unit` group **and** expose `refresh_stats()`, or
it silently ignores every upgrade the player buys. And more placement slots is a large power
increase: A1 measured that a 4-tower choke already wins passively at `difficulty_scale` 1.0, so
this needs a re-tune, not just a number bump.

### A6 — a campaign shape · ~4% *(was A5)*

- Level select.
- A handful of rough levels, so progression has somewhere to go.

**Level select needs A4's menu system** — it is a screen, and screens arrive at A4.

**The lever already exists:** `wave_count` + `difficulty_scale` per level means a new level is two
numbers against one authored curve, not a bespoke wave table.

**Vary layout, not numbers.** A1's tuning found the choke point is what actually sets difficulty —
raising enemy HP is a binary cliff (archer damage is exactly 10, so any HP above it doubles the
shots needed and swings a comfortable win into a wave-4 loss), while volume scales smoothly. Level
geometry is the real knob.

**A6 NOW OWNS THE TileMapLayer MIGRATION (T-1).** It used to be bundled into A3's horde rewrite,
but A3 moved to beta on 2026-09-07 — and Known issue 5's rule is "bundle it with the horde rewrite
**or** do it immediately before building levels 2–15, whichever comes first." With the rewrite in
beta, **this stage comes first, so the migration lands here.** Don't author fifteen levels against
a deprecated API and then migrate underneath them.

Note the `0` in `get_used_cells(0)` is a layer index that ceases to exist under `TileMapLayer`,
where the node *is* the layer. The affected calls are `get_used_cells`, `local_to_map`,
`map_to_local` and `get_used_rect`, all in `level_controller.gd`.

### Running throughout · ~2%

- The first small batch of real art, arriving near the end of the run.

*(The theme and HUD moved out of here and into **A4**, where they became the thing blocking
release rather than a background task. The ability bar was already built as its own scene for
exactly this reason and survives A4 intact.)*

**Two entity folders still have no placeholder PNG of their own** — the boulder and the goblin both
borrow the shared `1_pixel.png`. The artist brief is "replace the PNG in each entity folder", so
those two need one before the commission goes out.

---

## Start the art commission during alpha

Art has to be **finished** by beta, which means it has to be **commissioned** during alpha.
Briefing an artist, agreeing a style, and waiting for delivery all take calendar time that isn't
development time.

Alpha's job here is to produce the brief: by the end of the run the game knows what it needs
drawn — which towers, which enemies, which environments — because they all exist as
placeholders. Commission against that list, not against a guess.

---

## Exit criteria

- Every core mechanic exists and works: escalating waves, abilities, several enemy types,
  several towers, both currencies spendable, level select.
- A few levels, a few towers, a few enemy types — thin content, complete systems.
- A few real assets in place.
- People on itch coming back for updates.

The real test is simpler than any checklist: **is it fun without graphics?** If it isn't, no
amount of art fixes it, and that is worth knowing before the invoice arrives.
