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

### A2 — enemy variety · 8%

**Full work order: [a2_plan.md](a2_plan.md).**

- Several enemy types with genuinely different roles: fodder in huge numbers, a fast rusher that
  punishes slow-firing towers, a heavy that must not be allowed through. **Goblin, Skeleton,
  Ogre** — the Troll boss is deliberately deferred past A2 (see the work order).
- The approved rename from zombies to the medieval goblin horde — split into a *machinery*
  rename (`zombie_*` → `enemy_*`, since the grid and counters mean "any enemy") and an *entity*
  rename (zombie → goblin).
- A shared foundation for enemies so adding the next one is cheap: `class_name Enemy` plus a
  stat registry, so a new type is a `.tscn` and a dict entry.
- **The three remaining abilities** — Rain of Arrows, Divine Smite, Dragon Fire — moved here
  from A1. They land alongside the enemies that give them a job.

A2 also closes two debts A1 left open: the Ogre's 80 HP makes the archer's damage upgrade track
meaningful (Known issue 1), and gives Divine Smite a target worth a 60s cooldown.

### A3 — big battles · 12%

The horde engine rewrite: from a few hundred enemies to genuinely overwhelming numbers.

This is the largest single item in the entire roadmap and the biggest technical unknown in the
project. It is also the best update headline alpha has — "the hordes got massive" is something
players notice immediately.

**Bundle the TileMapLayer migration into this.** Godot deprecated `TileMap` in 4.3 and the
project is on 4.6. It still works, so it isn't urgent on its own — but the rewrite touches the
same pathfinding code (cell lookups, coordinate conversion, used-rect), and doing them
separately destabilises that code twice. Decided deliberately: don't migrate before this point,
and don't leave it past the first batch of new levels.

**Full work order: [a3_plan.md](a3_plan.md).** Target **1500 concurrent enemies at p95 < 16.6 ms**,
~6× today's ceiling, with de-nodify and MultiMesh in scope from the start.

**Two things to hold onto:**

- **Timebox it, and keep the current engine as a fallback.** If the rewrite proves too
  expensive, the game degrades to smaller battles rather than stalling. That fallback is what
  keeps this from being a project-killing bet. *(a3_plan sharpens this: because every rung is
  independently committed and measured, the fallback is simply "stop climbing" — there is no
  second engine to maintain and nothing to abandon.)*
- **It gets more expensive the longer it waits.** Every tower and enemy built beforehand is more
  to carry across. That is the argument for doing it at A3 rather than at the end of the run —
  early enough to limit the porting cost, late enough that a public build exists first.

**Two findings from planning that change the shape of this stage:**

- **The diagnosis in CLAUDE.md was wrong.** "Move the horde into a single manager loop" removes
  one Callable dispatch out of ~25 keyed Dictionary operations per enemy per frame. The cost is
  hashing and `Vector2i` construction. Following it as written would have produced a sixth
  consecutive "no change" result.
- **Measurement comes first, and it is not optional.** Six optimisations have been attempted here;
  five produced "no change", and the only number ever obtained came from deleting the feature. A3
  opens by building a self-measuring bench harness — *which lands during A2*, so it is validated on
  real work before A3 depends on it.

**A3 ends with overlapping waves.** A bigger sequential wave is the same fight bigger; overlap is
what actually makes it *overwhelming*, and [a1_plan.md](a1_plan.md) deferred it to exactly this
point. That, not the engine, is the shippable headline.

### A4 — more ways to build · 7%

- Additional tower types beyond the starting two, so loadout becomes a real decision.
- **Gold finally does something.** Today gold is earned once per level and can be spent on
  nothing at all — half the economy is inert. Gold buys tower unlocks and extra placement slots.
- More placement slots, so the four-tower cap becomes a choice rather than a wall.

**This is smaller than it looks.** `PlayerData` already has `spend_gold()`, `unlocked_towers`,
`is_tower_unlocked()` and `slot_count`, all persisted and all working since M1 — A4 is wiring a UI
to a working economy, not building one.

**Two traps.** Any new tower must join the `tower_unit` group **and** expose `refresh_stats()`, or
it silently ignores every upgrade the player buys. And more placement slots is a large power
increase: A1 measured that a 4-tower choke already wins passively at `difficulty_scale` 1.0, so
this needs a re-tune, not just a number bump.

### A5 — a campaign shape · 4%

- Level select.
- A handful of rough levels, so progression has somewhere to go.

**The lever already exists:** `wave_count` + `difficulty_scale` per level means a new level is two
numbers against one authored curve, not a bespoke wave table.

**Vary layout, not numbers.** A1's tuning found the choke point is what actually sets difficulty —
raising enemy HP is a binary cliff (archer damage is exactly 10, so any HP above it doubles the
shots needed and swings a comfortable win into a wave-4 loss), while volume scales smoothly. Level
geometry is the real knob.

**Blocked on A3's TileMapLayer migration** — don't author fifteen levels against a deprecated API
(CLAUDE.md Known issue 5).

### Running throughout · 3%

- A functional theme and HUD, replacing the throwaway debug interface that exists today. Not
  pretty — just no longer embarrassing. See `ui_plan.md` for the approach.
- The first small batch of real art, arriving near the end of the run.

**`round_ui.gd` needs to die sooner rather than later.** It is explicitly throwaway, and A1 has
already bolted a wave counter and a breather panel onto it. Every further bolt-on is work done
twice. `ui_plan.md`'s UI-0 (theme) has no dependencies and can land at any point; the ability bar
was deliberately built as its own scene for exactly this reason.

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
