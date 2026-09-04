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

### A1 — "it's a game now" · 8%

The round becomes something you play rather than watch.

- **Progressive waves.** Difficulty escalates within a level instead of one flat batch of
  enemies every time. Right now the power curve rises forever and nothing pushes back — this is
  the fix.
- **The three cooldown abilities.** Towers are pre-placed and auto-fire, so abilities are the
  *only* live input a round has. Without them, a round is a spectator phase.
- A short breather between waves. Not a build phase — placement still happens once, before the
  round starts.

**Ship it.** This is the first itch release.

### A2 — enemy variety · 6%

- Several enemy types with genuinely different roles: fodder in huge numbers, a fast rusher that
  punishes slow-firing towers, a heavy that must not be allowed through.
- The approved rename from zombies to the medieval goblin horde.
- A shared foundation for enemies so adding the next one is cheap.

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

**Two things to hold onto:**

- **Timebox it, and keep the current engine as a fallback.** If the rewrite proves too
  expensive, the game degrades to smaller battles rather than stalling. That fallback is what
  keeps this from being a project-killing bet.
- **It gets more expensive the longer it waits.** Every tower and enemy built beforehand is more
  to carry across. That is the argument for doing it at A3 rather than at the end of the run —
  early enough to limit the porting cost, late enough that a public build exists first.

### A4 — more ways to build · 7%

- Additional tower types beyond the starting two, so loadout becomes a real decision.
- **Gold finally does something.** Today gold is earned once per level and can be spent on
  nothing at all — half the economy is inert. Gold buys tower unlocks and extra placement slots.
- More placement slots, so the four-tower cap becomes a choice rather than a wall.

### A5 — a campaign shape · 4%

- Level select.
- A handful of rough levels, so progression has somewhere to go.

### Running throughout · 3%

- A functional theme and HUD, replacing the throwaway debug interface that exists today. Not
  pretty — just no longer embarrassing. See `ui_plan.md` for the approach.
- The first small batch of real art, arriving near the end of the run.

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
