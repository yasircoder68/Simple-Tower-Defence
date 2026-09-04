# A1 — "It's a Game Now" — Implementation Work Order

**Status: planned, not started.** This is the first public itch.io release, per
[alpha_plan.md](alpha_plan.md). It closes the two gaps that stop a round from being *played*
rather than watched: the round doesn't escalate, and there is no live input.

**Scope:** two new managers (`wave_manager.gd`, `ability_manager.gd`), one new entity folder
(`entities/abilities/boulder/`), plus edits to `level_controller.gd`, `round_ui.gd`, `arrow.gd`
and `zombie.tscn`. No new autoloads, no save-format change, no change to `PlayerData` or
`TowerStats` — A1 adds nothing persistent.

Read [CLAUDE.md](CLAUDE.md) first — especially *Round lifecycle*, *Performance*, *Known issues*
and *Gotchas*. This document assumes that context and only covers what's new.

---

## Why this exists

The economic loop works: place towers, kill for silver, clear for gold, buy permanent upgrades,
replay. What it lacks is anything happening *inside* a round.

Two specific holes:

- **The round is one flat batch.** `zombie_count = 50` spawns once and the round is over when
  they resolve. The power curve rises forever — permanent upgrades compound across replays — and
  nothing pushes back.
- **The round has no input at all.** Towers are pre-placed and auto-fire by design. Between
  pressing Start and the result panel, the player does literally nothing.

Waves fix the first. The boulder ability fixes the second. Together they are the smallest change
that makes the existing loop worth playing, which is exactly the bar the first public build has
to clear.

---

## Decisions already made — do not re-litigate

**1. A1 ships exactly one ability: the boulder.**
Rain of Arrows, Divine Smite and Dragon Fire move to A2. This keeps the first release small
(alpha_plan: "the first release should go out **soon**") and resolves a design problem for free —
Divine Smite's "huge single-target damage" is meaningless while every enemy has 10 HP. In A2 the
Ogre (80 HP) and Troll (1000 HP) exist and it finally has a target.

**2. Enemy HP and speed are constant across waves. Count and spawn interval are the only
escalation levers.**
Escalation is *density*, not durability. This is why `wave_manager` never touches the enemy scene
at all — it instantiates and positions, exactly as today's `spawn_zombies()` does. An earlier
draft of this plan added `@export var max_hp` to `zombie.gd`; that is no longer needed and should
not be added.

**3. Waves are strictly sequential.** Wave N+1 begins only after wave N is fully resolved. See
*Why sequential* below — there are two independent reasons and neither is negotiable in A1.

**4. `RoundState` gains no new values.** The round stays `IN_ROUND` for its entire duration,
breathers included. Wave phase is private to `wave_manager`.

**5. No gold between waves.** `implementation_plan.md` §1.3 proposes "bonus gold between waves".
Rejected: gold is deliberately finite at `levels × gold_per_level`, and per-wave gold makes it
farmable by replaying — the exact failure the `cleared_levels` ledger exists to prevent. Silver
already flows from kills; there is no additional between-wave reward.

**6. Placement and upgrades stay locked for the whole round, breathers included.** The breather is
a breather, not a build phase.

---

## Why sequential waves

Wave N+1 waits for wave N to fully resolve. Two reasons:

1. **Perf.** Concurrent enemies are capped at one wave's size, which keeps A1 under the ~200–250
   ceiling documented in CLAUDE.md's Performance section. Overlapping waves is the obvious
   "make it more intense" lever and it is precisely the lever that cannot be pulled until A3's
   horde rewrite lands.
2. **Accounting.** With sequential waves a dying enemy unambiguously belongs to the current wave,
   so a single counter works. Overlapping waves would need a wave tag on every enemy and
   per-wave decrements on every death. That is the deferred cost, and it is real — know that
   it's being deferred, not dodged.

---

## The wave table

Count and spawn interval only. Starting values, to be tuned in play.

| Wave | Count | Spawn interval | Spawn duration |
|---|---|---|---|
| 1 | 20 | 0.15 | 3.0s |
| 2 | 30 | 0.12 | 3.6s |
| 3 | 45 | 0.09 | 4.1s |
| 4 | 65 | 0.06 | 3.9s |
| 5 | 95 | 0.04 | 3.8s |

255 enemies total, peak concurrent ~95, round length roughly 2.5–3 minutes.

**Floor `spawn_interval` at ~0.02.** A `Timer` cannot fire more than once per physics frame
(16.7ms at 60Hz), so any value below that silently stops responding — the wave just spawns at
60/sec and the tuning knob goes dead. If a wave ever needs to arrive faster than that, spawn N
per tick rather than shrinking the interval further.

**Level authoring:** `WAVE_TABLE` is a const in `wave_manager.gd`. Levels supply two exports —
`wave_count` (how many rows this level uses) and `difficulty_scale` (a multiplier on count).
That yields fifteen levels of pacing from one authored curve plus two numbers per level, and
defers bespoke per-level wave tables until something actually needs them.

---

## The boulder

| Property | Value |
|---|---|
| Input | hold LMB to aim, release to drop |
| Cooldown | 3s |
| Impact delay | ~0.5s arc |
| Radius | ~70 |
| Damage | ~15 |
| Placement rules | none — lands anywhere, walls included |

**A 3-second cooldown makes this a different kind of thing than the 30/60/90s abilities.** It is
not a special; it is the baseline verb of a round, fired 10–12 times per wave. So it must be
modest per cast or it replaces the towers it is meant to supplement. Target roughly 20–25% of
kills: strong early, a finisher late. That arc is deliberate — it gives the permanent damage
upgrades something to push against once A2's tougher enemies arrive.

**No input conflict with tower dragging, and it costs nothing to avoid.** `_input()`'s entire
LMB branch returns early unless `round_state == PRE_ROUND`; the boulder is `IN_ROUND` only. The
two meanings of "hold left mouse button" never coexist, so neither needs to know about the other.

**Silver is automatic.** Boulder kills route through `zombie._die()` → `map.on_zombie_killed()`
like any other kill. Nothing to add.

**Cooldown ticks during breathers.** That is part of what makes a breather worth having rather
than dead air.

---

## The highest-risk code in A1

The boulder's damage loop.

`get_zombies_in_radius()` reads `zombie_grid_nodes`, which caches node references at grid-rebuild
time. By the time a damage loop iterates them, earlier kills in the same burst may have freed
some. This has already crashed in real play once — see CLAUDE.md's Known issue 1b, two wizards on
a dense cluster.

A boulder fired every 3 seconds into the densest part of a 95-enemy wave is the most likely thing
in A1 to trigger it again.

**Use `map.get_zombies_in_radius()`** — it is already guarded — **and put an `is_instance_valid()`
check in the damage loop**, exactly as `fire.gd` does. Do not hand-roll a new query against
`zombie_grid_nodes`.

---

## The work split

The whole split turns on one idea: **only Step 0 touches `level_controller.gd`.** After that,
waves live in `wave_manager.gd`, the boulder lives in `ability_manager.gd` plus its own entity
folder, and neither track reopens the 554-line file both would otherwise be contending over.
That is what makes the two tracks genuinely independent rather than nominally independent.

### Step 0 — the seam (small, blocks everything)

Write both managers as **stubs with their full public API and no behavior**, wire them in, commit.
Each track then fills in a file nobody else is in.

`level_controller.gd`:

- `_ready()`: create `base_health`, `wave_manager`, `ability_manager`, **then** call
  `round_ui.setup(self)`. `round_ui` connects to their signals, so it must be constructed last —
  the same ordering dependency `base_health` already has.
- `_start_round()`: `wave_manager.begin()` replaces `spawn_zombies()`; `ability_manager.reset()`.
- `_end_round()`: `wave_manager.abort()`, `ability_manager.set_enabled(false)`.
- `start_new_round()`: reset both to idle.
- Delete `spawn_zombies()`, `zombie_count`, `spawn_interval`. Add `@export var wave_count: int = 5`
  and `@export var difficulty_scale: float = 1.0`.

Two one-line fixes belong in this same commit — both are cheap now and both get worse if left:

- **`arrow.gd:12`** — `queue_free()` with no `return`, so it keeps attaching a timer to a freed
  node (Known issue 1). The boulder multiplies projectile churn; fix it before it starts showing
  up in logs. `fire.gd` already does this correctly.
- **`zombie.tscn` `z_index = 10`** draws enemies over towers (Known issue 6). Give towers a
  higher `z_index` than enemies. The board gets substantially busier with 95-enemy waves.

### Track A — waves (`game/systems/wave_manager.gd`)

**A-1 · Phase machine and Timer-driven spawning.**
Phases `IDLE → SPAWNING → CLEARING → BREATHER → … → DONE`, private to the manager. Spawn
from a `Timer`, one enemy per `timeout`, index held in a plain field.

Do **not** add a `BETWEEN_WAVES` value to `RoundState`. Keeping the round `IN_ROUND` throughout
means `is_valid_placement()`, `_upgrades_allowed()`, `_input()`'s entire body, `remove_tower()`
and `begin_move()` all keep working untouched — five or six guards that need no re-audit, purely
by keeping wave phase private.

The Timer also retires a live bug that waves would amplify. Today's `spawn_zombies()` awaits a
timer per zombie inside a `for` loop, making it a coroutine that outlives everything:
`_clear_all_zombies()` does not touch it, and its `round_state != IN_ROUND` guard only helps if it
happens to wake while the round is over. Between Play Again (`PRE_ROUND`) and Start (`IN_ROUND`)
a sleeping coroutine sails straight through and resumes spawning into the new round. The window
is ~50ms today; with five spawn loops and breather timers per round it stops being negligible.
A Timer has nothing to leak, aborts with `stop()`, and — the part that matters most in practice —
exposes its whole state to `runtime_get_script_vars`.

If the coroutine is kept instead, the minimum fix is a monotonic `_run_token: int` captured by the
loop and re-checked after every `await`, incremented on every `begin()` and `abort()`.

**A-2 · The counter split.**
`zombies_to_resolve` becomes wave-scoped `wave_remaining`. A wave clears at 0. The round ends only
when `wave_remaining == 0 AND current_wave == wave_count`.

Write that conjunction deliberately rather than adapting the existing check in
`_check_round_complete()`. One counter is now answering two questions that have stopped being the
same question — "is this wave finished" and "is the round finished" — and conflating them has a
specific, loud symptom: **victory after wave 1.**

`wave_remaining` is set to the full wave count when the wave *starts*, not incremented per spawn,
so it cannot hit zero early while enemies are still being fed onto the board. Today's code already
works this way.

**A-3 · Breather.**
Another phase: `@export var breather_seconds: float = 12.0`, a Timer, and a skip method. Placement
and upgrades stay locked with zero new code because the round is still `IN_ROUND`.

**A-4 · Abort and reset.**
`abort()` stops both timers and clears phase. `reset()` returns to wave 0. Both called from
Step 0's hooks. `_clear_all_zombies()` already handles enemies; nothing currently handles a running
spawner.

**Signals throughout:** `wave_started(num, total, count)`, `wave_cleared(num)`,
`breather_started(seconds)`, `all_waves_complete()`. Signal-driven from day one even when the only
listener is a raw `Label` — per CLAUDE.md's Build order note, retrofitting structure is the
expensive part, not style.

**Design the API for the harness.** Small explicit methods — `begin()`, `abort()`,
`on_enemy_resolved()`, `force_clear_wave()`, `skip_breather()` — because `node_call_method` is the
reliable MCP verb and playing five full waves by hand after every tuning change is not a workable
loop.

### Track B — boulder (`game/systems/ability_manager.gd`, `game/entities/abilities/boulder/`)

**B-1 · `ability_manager.gd`.**
3s cooldown, `can_cast()`, `cast_boulder(world_pos) -> bool`, `cooldown_changed(remaining, total)`
signal. Enabled only while `IN_ROUND`, so it is inert during `PRE_ROUND` and after the round ends.
Cooldowns are round-scoped per CLAUDE.md's state boundary table — reset each round, never
persisted.

**B-2 · The boulder entity.**
`boulder.tscn` / `boulder.gd` plus a placeholder PNG, colocated in its own folder per the `dd49e82`
convention. Spawns at cast, arcs ~0.5s, deals damage **on impact, not on cast**. Cooldown starts at
cast. See *The highest-risk code in A1* above for the damage loop's one hard requirement.

**B-3 · Input routing.**
`_input()` gains an `IN_ROUND` branch: LMB press shows the aim marker, motion moves it, release
calls `cast_boulder()`. `_input()` does nothing but route — all logic lives in the manager.

Use a separate small aim marker rather than the existing tower `ghost`, which carries
tower-specific `set_tower()` / `update_validity()`.

The routing split matters for verification, not just tidiness: `get_global_mouse_position()` is not
reliably driven by `input_simulate` in this environment (CLAUDE.md, Gotchas), so calling
`cast_boulder(world_pos)` directly via `node_call_method` is the only way to verify this path. Same
workaround that got tower move/remove verified.

### Step 2 — UI (needs both tracks)

Bolt onto `round_ui.gd`. It is explicitly throwaway and A1's headline is mechanics; `ui_plan.md`
budgets interface work as 3% spread across the whole alpha run rather than front-loaded into the
first release. Do UI-0's theme before A2, not before A1.

Additions: wave counter (`Wave 3/5`), breather countdown with a Skip button, boulder cooldown bar.

Give every new button an explicit `.name`, as `round_ui` already does — anonymous procedurally
created `Control`s get auto-generated names like `@Button@42` that are not guessable in advance,
and `click_node` needs an exact path.

### Step 3 — tune and verify

Boulder numbers can only be judged against real wave density, so tuning is its own pass regardless
of build order.

Two things to prove that will not show up by simply playing:

1. **Lose during wave 3, then Play Again, then Start.** No ghost spawns from the abandoned wave.
   This is the Timer/token fix, and it is invisible until it isn't.
2. **Boulder into a dense cluster while a wizard fireball lands the same frame.** No
   `previously freed` crash.

Verification method, per CLAUDE.md's Gotchas: `node_call_method` for manager methods,
`click_node` for buttons by exact path, `runtime_get_script_vars` for phase and counter state.
Confirm what happened via state, never via an event's `dispatched: true`.

---

## Sequencing

**Solo:** Step 0 → Track B → Track A → Step 2 → Step 3.

Boulder first, even though waves are the larger item. It is smaller, self-contained, and testable
against the *existing* flat 50-enemy round with no waves in place. It de-risks the
ability-manager and MCP-verification pattern while the codebase is still simple, and it lands
"something to do during a round" as a playable thing before the structural work starts.

**Two people:** Step 0 is a blocking prerequisite for both. Then A and B run fully in parallel
with no shared files. Then Steps 2 and 3 join them back up.

**Commit boundaries:** Step 0, then A-1 through A-4 and B-1 through B-3 individually, then UI,
then tuning. Nine commits, none of which leaves the game unplayable.

---

## Knock-on effects to decide, not inherit

**1. Lives get much tighter.**
`base_health.reset()` is called once in `_start_round()` and must stay there — lives persist across
the whole round, so an early leak haunts you at wave 5. That tension is the point. But the
arithmetic shifts hard: today it is 20 lives against 50 enemies, a 40% leak tolerance. Under waves
it is 20 against 255, about 8%.

**Assumed decision: raise `max_lives` to 30.** Tune from there. The wrong outcome is inheriting a
substantially harder game as a side effect rather than choosing it.

**2. The archer's damage upgrade track is inert.**
Archer base damage is 10 and zombie HP is 10 — an exact one-shot. With HP fixed forever at 10,
buying archer damage does nothing: 10 → 12 → 14 still one-shots a 10 HP enemy. The player spends
silver, feels no difference, and learns the upgrade screen lies. Wizard is unaffected (damage 3,
so four hits, and upgrades genuinely reduce that).

Constant-across-waves and constant-at-*10* are separate decisions. Two ways out:

- **Raise the constant to ~16**, so archers need two shots and the track bites immediately.
  *(Recommended.)*
- **Accept it**, and let A2's Ogre and Troll fix it automatically.

**Still open — decide at the Step 3 tuning pass.**

**3. Silver per round roughly quintuples, and that is fine.**
~255 kills instead of 50 means ~510 silver per round instead of ~100. But the round is also
~4–5× longer, so silver *per minute* is roughly unchanged and the `10 * 1.35^level` cost curve
does not need retuning. What changes is cadence: a player clears a round and affords several
upgrades rather than one. Watch it in play; do not pre-emptively adjust.

---

## Out of scope for A1

Named explicitly so they are not drifted into:

- Rain of Arrows, Divine Smite, Dragon Fire (A2)
- The zombie → goblin rename and any new enemy type (A2)
- Overlapping waves, and anything that raises the concurrent-enemy ceiling (A3)
- The `TileMapLayer` migration (A3, bundled with the horde rewrite — see CLAUDE.md Known issue 5)
- UI-0's theme system (before A2)
- New tower types and gold sinks (A4)
- Level select and additional maps (A5)
