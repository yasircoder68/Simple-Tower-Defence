# A2 — "Enemy Variety" — Implementation Work Order

**Status: A2 COMPLETE.** Enemy track, A-1 Rain of Arrows, and the tune/verify pass all built and
verified. A-2 and A-3 moved to A5.

> [!IMPORTANT]
> **A-2 Divine Smite and A-3 Dragon Fire moved out of A2 to A5** (decision, 2026-09-06). A2 keeps
> **A-1 Rain of Arrows**, which is what proved the ability registry generalises. The two remaining
> abilities are no longer a gate on calling A2 done.
>
> This is a better fit than it first looks. A-1 already built the machinery the other two needed —
> the `aim_marker` `SHAPE` mechanism that this plan called "the one real system change" for A-3,
> and the drag-to-aim direction A-3 had planned to skip with a fixed axis. Both land in A5 cheaper
> than they would have been here.

> [!NOTE]
> **E-5 (ogre) is verified.** Ran 2026-09-05 against the reopened editor. All six checklist steps
> below passed; two defects were found and fixed in `_build_waves()` along the way.
>
> **What the checklist confirmed:**
> 1. `script_check` clean on `enemy_types.gd` and `wave_manager.gd`.
> 2. Game starts clean. `setup()` ran and `_assert_registries_agree()` stayed silent, so the ogre
>    has both registry halves. The hand-written `ogre.tscn` parses, `enemy_id` binds, and
>    `_resolve_stats()` returned every value: hp 80, speed 100, silver 12, life_cost 3,
>    `separation_weight` 0.15 — and it joined `Enemy.GROUP` **in code**, per R-0's guarantee.
> 3. Waves 3/4/5 each carry an ogre group. **Totals were wrong before the fix below** — see
>    *Two defects found in `_build_waves()`*.
> 4. **Life cost:** measured on a deliberately quiet board (spawn timer stopped, board cleared,
>    counters intact) so it was a genuine single-event reading. Lives 20 → **17**;
>    `enemies_to_resolve` and `wave_remaining` each **−1**. Exactly as designed.
> 5. **Known issue 1 closes.** `TowerStats` resolves archer damage to 10 at upgrade level 0 and
>    12 at level 1. A live ogre took 7 × 10 → hp 10 alive, and died on the **8th**; at 12 it took
>    6 → hp 8 alive, and died on the **7th**. The damage track is live and each upgrade removes a
>    shot. CLAUDE.md's Known issue 1 can be marked closed.
> 6. **Full round completes.** Post-fix: 408 spawned (336 goblin / 63 skeleton / 9 ogre), **won,
>    12/20 lives, 890 silver**, zero errors in `debugger_get_log`. Per-wave silver was exact at
>    every boundary (wave 3 `+154` = 71×2 + 1 ogre×12; wave 4 `+238` = 101×2 + 3×12), and the
>    round total reconciles precisely: 8 leaked × 2 silver = the 16 short of the 906 maximum.
>
> **Bench re-baseline, post-E-5** (the M-0 harness, as this plan intended it to be used):
> `| M-0 | V0 | 600 | packed | 133.33 | 144.88 | 40.00 | 52.24 | 66.7 | 180 | 1843 |`
> — **66.7 µs/enemy**, so the 60 Hz ceiling is `16600 / 66.7` ≈ **249 enemies**, consistent with
> CLAUDE.md's documented ~200–250 budget. E-1's `separation_weight` multiply cost nothing visible.
>
> **Caveat on the tuning signal.** This round was won on a heavily-upgraded save (archer range
> Lv11, fire-rate Lv7, damage Lv4), not a fresh one. It verifies the *mechanics*, not the
> difficulty curve — a fresh-save round still belongs in step 11.

### Two defects found in `_build_waves()` — both fixed

Both were in the same six lines, and neither was visible to the acceptance checks that had already
passed. Fixed together, then re-verified with a full round.

**1. Scaled wave totals drifted +1.** `_build_waves()` rounded **each group independently**, so
per-group rounding errors accumulated instead of cancelling: at `difficulty_scale` 1.6, wave 5's
76/16/3 became 122/26/5 = **153**, while the wave's authored total of 95 scales to **152**. Waves 3
and 5 were each one enemy over.

The drift only appeared once **E-5 added a third group** — with two groups the errors happened to
cancel, which is why waves 3 and 5 were exact before the ogre landed. A drift that surfaces when
you add content is precisely the kind that gets blamed on the content.

Fixed with **largest-remainder apportionment**: floor every group, then hand the leftover units to
whichever groups were rounded down hardest — deliberately the same rule `_build_spawn_plan()`
already uses to interleave types, applied here to counts. `maxi(1, ...)` still applies per group,
so a one-ogre group can never be scaled out of existence. Totals are now **32/48/72/104/152**,
exactly the authored curve × 1.6, and the round spawns **408** — matching A1's figure again.

**2. `SKELETON_PACK` was inert — E-4 shipped a feature that did nothing.** `_build_waves()`
constructed `{"type", "count"}` and **dropped the `pack` key**. `_build_spawn_plan()` reads `pack`
off the groups *that function produces*, not off `WAVE_TABLE`, so `g.get("pack", 1)` always
returned 1. Skeletons had never once arrived as a squad, in any round played or measured.

Confirmed by inspection of the real spawn plan rather than by reading: wave 2's plan contained six
skeletons, **every one isolated**. Feeding the same groups in by hand *with* `pack` present
produced contiguous runs of 4 and 2 — proving `_build_spawn_plan()` was correct all along and the
fault was entirely upstream.

**Why nothing caught it.** E-4's acceptance criterion was that wave totals stay on the authored
curve — and this bug does not affect totals at all. It produced no error, no warning, and a
perfectly valid-looking round. The lesson generalises past this project, and is the same shape as
R-0's: **an acceptance check that only reads the aggregate cannot see a defect in the arrangement.**
E-4 needed a check that looked at the *order* of the spawn plan, which is the thing it changed.

**It is a real difficulty change.** With packs working, the same round now loses **12/20** lives
instead of 14/20 — skeletons genuinely rush the choke as designed. Still a comfortable win, but
step 11's tuning pass should treat post-fix numbers as the only valid baseline; every skeleton
measurement taken before this was of a feature that was switched off.

Progress against the Sequencing table below:

| Step | State |
|---|---|
| 0 · R-0 harden the contract | ✅ **done and verified** — see *R-0: what actually shipped* |
| 1 · R-1 machinery rename → `enemy_*` | ✅ **done and verified** |
| 2 · R-2 entity rename → goblin | ✅ **done and verified** |
| **+ · M-0 bench harness** | ✅ **built and verified** — added scope, see below |
| 3 · E-1 enemy base + registry | ✅ **done and verified** |
| 4 · E-2 life-cost channel | ✅ **done and verified** |
| 5 · E-3 wave composition | ✅ **done and verified** |
| 6 · E-4 skeleton | ✅ **done and verified** — but its `pack` was inert until E-5's verification pass; see above |
| 7 · E-5 ogre | ✅ **done and verified** — Known issue 1 closed; see above |
| 8 · A-1 Rain of Arrows | ✅ **done and verified** — see below |
| 9–10 · A-2 Divine Smite, A-3 Dragon Fire | **moved to A5** |
| 11 · tune + verify + docs | **done** — see *Step 11* below |

### A-1 shipped — and what it cost the registry claim

**A-1 first shipped exactly as B-4 promised: one `ABILITIES` row and not one other line**, with a
circular point-aimed blast. Every consumer worked unedited — the bar built slot 2, `KEY_2`
selected, `get_radius` returned 110 off `payload.RADIUS`, and the marker resized itself.

**Then the aiming was changed by decision** to a rotatable rectangle: press pins the base edge,
moving the cursor swings the far end around it, release casts. **That ends the "one registry entry"
property**, and the honest statement of B-4's promise is now narrower:

> Adding a **point-aimed** ability is one registry entry plus one payload folder. Adding a new
> **aiming model** costs `ability_manager` and `aim_marker` as well — once per model, not once per
> ability.

That is still a good seam, and the second directional ability will cost a registry row again. But
the original claim was measured against the easy case, and saying so is the point of writing it
down.

**Numbers** (step-11 tuning material, not settled): `SHAPE "rect"`, `WIDTH 90`, `LENGTH 260`,
`DAMAGE_PER_TICK 4`, `TICK_INTERVAL 0.25`, `DURATION 3.0` — 12 ticks, 48 damage to anything that
stands in it — on a 30s cooldown. **Length is fixed and the cursor sets the angle only**, so the
covered area cannot be inflated by dragging further; that was a deliberate choice over a
stretch-to-cursor rectangle, whose area would have varied ~2.7x with drag distance.

**`aim_marker` gained `SHAPE` here rather than at A-3.** Built exactly as a2_plan specced it for
Dragon Fire — an optional const read off the payload, default `"circle"`, `match` in `_draw()` —
so it is general, not a Rain-specific branch. Read via `get_script_constant_map()` rather than
`payload.SHAPE`, because a *missing* optional constant is an error under direct access but a clean
default through the map; `boulder.gd` declares only `RADIUS` and is untouched by any of it.

**Knock-on for A-3:** drag-to-aim now exists, so Dragon Fire need not ship the fixed left→right
axis its section still describes. Deciding that is deferred to A-3 itself — noted here so it is a
choice rather than an oversight. a2_plan's *Out of scope* list still says "drag-to-aim direction",
which is now stale for that reason.

**Verified, all measured rather than asserted:**

- **Ticks over duration.** An 80 HP ogre parked in the blast finished on **32 HP** — exactly
  12 × 4, so every tick landed and the payload stopped on schedule.
- **Every edge of the rectangle, probed independently.** Five ogres around a cast aimed along +X
  from (275,425): one inside → **32**; one **behind the base** → 80; one **beyond `LENGTH`** → 80;
  one **outside half-width** → 80; one just inside half-width → **32**. Each of the four rejection
  branches is therefore covered by a case that fails if that branch is wrong.
- **Rotation proved by discriminator, not by inspection.** The same ogre that was inside the +X
  cast was left **untouched at 80** when the cast was re-aimed 90° from the same base, while one
  up-range took the full 48. Same anchor, same enemies, different aim, different victims — which
  a hit test that silently ignored rotation could not produce.
- **Aim maths:** cursor above the base → rotation −π/2; cursor right → 0; cursor up-left → −3π/4;
  and a cursor resting exactly **on** the anchor **holds the previous direction** instead of
  snapping to an arbitrary axis.
- **Boulder is unregressed in both respects:** still point-aimed (marker follows the cursor,
  rotation 0, circle r70) and still exactly 15 damage.
- **Silver routes normally.** Five goblins in the blast died and paid **+10**, straight through
  `_die()` → `on_enemy_killed()`. Nothing about scoring needed to know an ability existed.
- **Clicking slot 2 casts nothing.** It selected, spawned no payload and consumed no cooldown —
  the `_unhandled_input` guarantee, now demonstrated rather than reasoned about.
- **Per-ability cooldowns really are independent.** Boulder cooling at 0.08s while rain sat at 0.
- **A full round with barrages in it: won, 16/20 lives, +898 silver** — exact, being the 906
  maximum minus the four leaked enemies' 2 each. Every wave boundary reconciled to the silver
  (wave 3 `+154` = 71×2 + 1 ogre×12; wave 4 `+236` = 238 minus one leak). Casting into a
  100+ enemy wave produced no `previously freed`, which is the per-tick `is_instance_valid()`
  guard doing its job under real load rather than in a staged test.
- **Cooldown gating holds under play:** a cast attempted 20s into the 30s cooldown returned
  `false` and changed nothing.
- **A barrage that outlived its wave** — cast just as wave 4 cleared, ticking through the
  breather on an empty board — freed itself cleanly. The round stays `IN_ROUND` through a
  breather, so the round-check correctly does *not* fire there.
- Zero errors in `debugger_get_log` across every cast.

### The visual: real arrows, and two things only a frozen frame could show

Uses **the archer's `arrow.png`**, not a placeholder — a deliberate exception to colocation, on
the grounds that these are the same object and two copies would silently diverge. Each tick drops a
volley of 7 arrow sprites at random points in the box; they tween down and free themselves.

**The arrows are cosmetic and the damage is not.** Where a sprite lands has no bearing on the box
test. That line is deliberate: a payload whose real footprint depended on `randf()` would make
every acceptance figure in this plan unreproducible — the same argument `_build_spawn_plan()` makes
for a deterministic interleave over a shuffle.

**Two corrections the rotation forced**, neither obvious until drawn:

- **World-down must be computed in the payload's LOCAL frame** (`Vector2(0,1).rotated(-rotation)`),
  or the arrows fall along the rectangle's own axis — so a sideways-aimed barrage shows arrows
  flying *horizontally*, the one thing "rain" must never do. The zone rotates with the aim; the
  arrows must not.
- **The sprite's own facing needs the same correction** (`PI/2 - rotation`), since `arrow.png`
  points +X. Verified by casting at two aims and confirming the arrows' **`global_rotation` is
  π/2 in both** — a local rotation of π/2 under a zero-rotation payload, and π under one rotated
  −π/2. Same world-down either way.

**Two flaws that only a frozen frame revealed**, both invisible to any amount of reasoning:

1. **340px in 0.22s is ~1500 px/s** — faster than the eye tracks, so the barrage read as an empty
   zone with occasional flickers above it. Shortened to 220px over 0.32s.
2. **A volley spawned as a rigid horizontal line and landed in unison** — a falling ruler, not
   rain. Fixed with per-arrow jitter on the fall time, which desynchronises the volley and varies
   each arrow's speed.

Both were found by pausing in the same expression as the cast (the only way to freeze a 3s effect
when the round trip is ~3s) and *looking*. Worth remembering: this project verifies by measurement,
and measurement is exactly what could not have caught either of these.

### The multi-tick payload rule, and how it was actually proved

Payloads can now outlive the round, so every multi-tick payload checks the round at the top of each
tick and frees itself otherwise. `in`-guarded on `round_state`, so `clean_area.tscn` — which has no
round lifecycle — still runs payloads unmodified, the same tolerance `enemy.gd` extends it.

**The test was built so it could fail.** Ending the round with `_end_round(false)` would have been
worthless: the loss path force-clears the board, so a payload that ignored the rule entirely would
still damage nothing, and the check would pass for the wrong reason. Used the **win** path instead,
which leaves enemies standing: cast a barrage onto an 80 HP ogre and ended the round in the *same
frame*. The ogre finished on **80 HP** — untouched, where an unguarded payload would have taken 48
off it. That is the rule firing, not merely the absence of a crash.

Same shape as R-0's lesson and E-4's: **a check that passes whether or not the mechanism works is
not evidence.**

### Two implementation traps worth carrying to A-2 and A-3

1. **A payload must not read `global_position` — or now `global_rotation` — in `_ready()`.**
   `ability_manager.cast()` calls `add_child()` **before** assigning either, so `_ready()` still
   sees the origin and a zero angle. Rain reads both per tick; `boulder.gd` dodges the same trap by
   touching only `sprite.position` in `_ready()`. Directional aiming makes this sharper, because a
   payload now has *two* pieces of transform to get wrong. Divine Smite's acquisition query and
   Dragon Fire's aim point both want a position at spawn — this will bite them.
2. **`is_instance_valid()` on every tick, not once.** A 3s barrage reads a grid rebuilt ~180 times
   underneath it — Known issue 1b stretched over time rather than over one frame.

3. **A rotated hit test wants `to_local()`, not trigonometry.** The containment check is a plain
   axis-aligned box test in the payload's own frame — `0 ≤ x ≤ LENGTH`, `abs(y) ≤ WIDTH/2` — with
   rotation falling out of the node transform for free. No angle is stored twice, so the preview
   and the damage volume cannot drift apart. The grid is queried from the rectangle's **centre**
   with its half-diagonal (~138px) rather than from the base with its full length (260), which is
   a much tighter bound for the box test to filter.

**One deliberate departure from boulder:** the payload sits at `z_index 5`, below enemies (10),
where boulder is 30. A falling rock belongs on top of the horde; a ground-effect area belongs
under it, or it hides the enemies the player is trying to read. Confirmed visually.

## Step 11 — tune + verify: what the numbers actually said

Both proof cases pass, and the fresh-save measurement produced a real finding that is **not**
being "fixed", by decision.

### Proof case 1 — stale round-scoped state · PASS

Lost during **wave 4 with ogres and skeletons in flight**, then Play Again -> Start, both driven
through the real Buttons (`click_node`) rather than by calling the functions.

| After Play Again | Value |
|---|---|
| `round_state` | `PRE_ROUND` |
| `lives` | 20/20 |
| `enemies_to_resolve`, `wave_remaining`, `current_wave` | 0 |
| **`_spawn_plan.size()`** | **0** — E-3's new round-scoped state, cleared |
| `_waves.size()`, `_spawned_this_wave` | 0 |
| `towers_by_cell` | **4** — layout correctly survives, by design |

Restarting then built a **fresh 32-entry plan for wave 1**, not a resumed wave 4. No ghost spawns.
Both timers were already stopped by `abort()` at the moment of the loss.

### Proof case 2 — payloads outliving the round · PASS

A rain barrage ticking, a boulder mid-arc, and wizard fireballs in flight over **25 enemies**, with
`_end_round(false)` called in the **same frame** — so the board is force-cleared underneath all of
them. The boulder's 0.5s arc guarantees it impacts *after* every enemy node is freed.

Result: both payloads freed themselves, board cleared, and **zero errors** — no `previously freed`,
no invalid access. A-1's round check and the per-tick `is_instance_valid()` both held, as did
`boulder.gd`'s and `fire.gd`'s existing guards.

**The first attempt at this case was worthless and worth recording as such.** Draining lives with
`base_health.lose_life(20)` did not end the round at all (see below), and by the time the call
landed the towers had already cleared the board — so it staged neither the overlap nor the loss.
A test that sets up nothing passes for free.

### `lives_depleted` is emitted and never connected

`base_health.gd` declares and emits `lives_depleted`, and **nothing listens to it.** The loss is
actually driven by an inline `if base_health.lives <= 0` check inside
`level_controller.on_enemy_escaped()`.

**Not a live bug** — `on_enemy_escaped()` is the only caller of `lose_life()`, and it checks
immediately after. But it is a trap of exactly the shape M1's `save_data()` bug had: a mechanism
that looks like the one in charge, wired to nothing. Anyone adding a second way to lose lives — a
boss attack, a timer, a self-damage effect — would reasonably expect the signal to end the round,
and it would not. **Either connect it or delete it**; left alone for now because changing it is a
behaviour change outside A2's remit.

### The fresh-save measurement — a loss at wave 4, and that stays

First A2 round ever played on a **genuinely fresh save** (0 silver, every upgrade at 0, verified
from `PlayerData` at load). Four archers on the choke — the strongest fresh-player placement — with
boulder and rain used throughout.

| Wave | Lives after | Note |
|---|---|---|
| 1 (32) | 20/20 | zero leaks |
| 2 (48) | 20/20 | zero leaks |
| 3 (72) | **12/20** | ogre killed; 8 regulars leaked (silver confirms: 138 of a possible 154) |
| 4 (104) | **0 — round lost** | |

**Why**, and it is arithmetic rather than mystery: four base archers fire `4 / 0.5 = 8` shots per
second. Wave 4 delivers 104 enemies at a 0.06s interval, about **16.7 per second**. The wall is
literally twice the guns. At fire-rate Lv7 (0.29s) the same four towers make ~13.8/sec, which is
why the upgraded save wins comfortably.

**This is the design working, not failing.** CLAUDE.md's economy section already says every level
must be tuned against an assumed upgrade level, and that grinding is an intended mechanic rather
than a failure state. The loop closes correctly: the lost round still **banked 422 silver** (loss
keeps silver — verified), gold was correctly **not** awarded, and that silver buys the upgrades
that win the replay.

**Enemy counts were NOT reduced — explicit decision, 2026-09-06.** `difficulty_scale` stays at 1.6
and every wave stays on the authored curve. Do not "helpfully" lower these later; the loss is the
intended first-run outcome, and this is now the second entry (with goblin HP) on the list of
tempting difficulty edits that would be wrong.

**One thing this does surface, and it belongs to A4 not A2:** a brand-new player's *first ever game
is a loss*, with no explanation of why or of the fact that their silver was kept. That is an
onboarding and UI problem — the result screen currently says "Round Lost" and nothing else — and
A4's MVP UI is where it should be answered.

### Comparison against A1's tuning note

a1_plan recorded that a fresh save "lost **four** lives across the whole round". That figure is now
**dead** and should not be quoted: it predates skeletons, ogres, and the wave composition that
replaced plain goblins — and it predates the `SKELETON_PACK` fix, which made skeletons rush as
squads for the first time. A2 is meaningfully harder than A1 by design.

---

### Added scope: the bench harness (A3's M-0, pulled forward)

[a3_plan.md](a3_plan.md)'s measurement harness lands **here**, not in A3. It is purely additive —
a `systems/bench.gd` child of `level_controller` plus one ablation seam in `enemy.gd`.

Three reasons it belongs in A2:

- **A2's own acceptance criteria want it.** E-1's "a round is numerically identical", E-4's and
  E-5's "FPS holds at peak" are currently screenshot-reads of an FPS label. FPS is vsync-quantised,
  so anything between 3 ms and 16.6 ms of work reports "60" — those checks cannot currently detect
  a regression that matters.
- **It gets validated on real work** before A3 stakes its largest item on it.
- **A3's per-enemy cost figures are pre-E-1 and will go stale** the moment the enemy registry and
  three enemy types land. Building the harness here re-baselines them for free.

Slot it before E-1 so every later A2 step has a number to quote.

---

## R-0: what actually shipped

Three changes, all under the old names, all additive:

1. **Group membership moved from scene data into code.** `zombie.tscn` no longer declares
   `groups=["zombie"]`; `Enemy._ready()` calls `add_to_group(GROUP)`. Nine string literals across
   six files collapsed to `Enemy.GROUP` — a typo in the const *name* is now a parse error rather
   than a silent miss.
2. **Two independent `has_method()` guards → one cached probe.** `_die()` and `_escape()` can no
   longer disagree about whether the map is scoring; a partial contract `push_error`s naming
   exactly what is missing.
3. **Map-side self-check** in `level_controller._ready()`, plus loud fallbacks in `boulder.gd` and
   `fire.gd` when the splash query drifts — discriminated by the `"map"` group, which the testbed
   deliberately isn't in, so the testbed still falls back silently and correctly.

**`class_name Enemy` was brought forward from E-1.** It is what lets six consumer files say
`Enemy.GROUP`, which is the entire point of R-0. No cycle risk: enemies duck-type the map through
`map` and never name a controller class. The class now lives in a file still called `zombie.gd` —
the CLASS is already the shared base, the FILE name is what R-2 fixes.

**The group value stays `"zombie"` until R-1.** R-0 must change nothing observable so R-1's diff
is meaningful. Once every consumer reads the const, the value is a private detail.

### The net was verified by breaking it

Per this plan's own rule — a net you haven't fallen into is not a net. `on_zombie_escaped` was
deliberately renamed to `on_zombie_escaped_TYPO`; **both** guards fired naming the exact missing
member (the map-side check at startup, the enemy-side probe per spawn). Reverted, re-ran, clean.

### A verification gap this exposed, affecting A1's record

Finding those errors required looking somewhere this project had not been looking:
**runtime `push_error` goes to `debugger_get_log`, NOT `editor_get_console`.** On Godot 4.5+ the
latter shows the *editor's* console — it catches parse and load errors (it did surface W-5's), but
not a running game's runtime errors.

Every "zero errors" claim made during A1 was read from the wrong stream. Re-verified since: a full
408-enemy round on the current build, with two boulders impacting one cluster in a single frame,
produces zero errors in the game log. **A1's conclusions stand — but they stood on weaker evidence
than was stated at the time.**

---

## Context

A1 shipped: five escalating waves, a boulder ability, 408 enemies at 60 FPS. But **there is
exactly one enemy type**, so a wave is the same fight bigger. A2 is what makes the horde
*interesting* — three enemies with genuinely different roles, plus the three cooldown abilities
deferred out of A1.

It also pays off two debts A1 deliberately left open:

- **The archer's damage upgrade track is inert** (CLAUDE.md Known issue 1). Archer damage is
  exactly 10 and goblin HP is exactly 10, so buying damage does nothing. A1 measured that raising
  goblin HP is a binary cliff that breaks the difficulty curve. The Ogre at 80 HP fixes it for
  free — 8 archer hits, so upgrades bite immediately and measurably.
- **Divine Smite had no target worth a 60s cooldown** — the reason it moved out of A1. The Ogre
  gives it one. That debt is now *paid* even though Smite itself ships in A5: the target exists and
  is verified, so A5 inherits a solved design problem rather than an open one.

**Scope:** two renames, an enemy foundation, three enemy types, wave composition, a life-cost
channel, and **one** ability (A-1 Rain of Arrows). A-2 and A-3 moved to A5. No new autoloads, no save-format change, nothing persistent added.
`PlayerData` and `TowerStats` untouched.

**Decisions taken with the user:** Troll deferred; both renames done, machinery first; A2 ships
as one itch release.

Read [CLAUDE.md](CLAUDE.md) first — *Separation (the perf-critical path)*, *Waves (A1)*,
*Abilities (A1)*, *Known issues* 1 and 1b, and *Gotchas*.

---

## The central risk: a rename that fails silently

This is not an ordinary rename. Six couplings are **string literals**, so renaming a definition
without its literal produces no error at all:

| Site | Literal | Failure if missed |
|---|---|---|
| `zombie.gd:28` | `if "zombie_grid" in map` | separation silently disabled |
| `zombie.gd:124` | `has_method("on_zombie_killed")` | **kills stop awarding silver** |
| `zombie.gd:132` | `has_method("on_zombie_escaped")` | **escapes stop costing lives** |
| `boulder.gd:63`, `fire.gd:52` | `has_method("get_zombies_in_radius")` | AoE falls back to a full scene scan |
| `zombie.tscn:9` | `groups=["zombie"]` | **total blackout** — nothing targets, indexes or damages |

The last is the worst and the least obvious: **`zombie.gd` never calls `add_to_group()`.** Group
membership exists only as scene data, consumed by 9 call sites across 6 files. A2 adds two more
`.tscn` files, each able to forget the group independently.

**Two aggravating factors.** The testbed cannot catch any of this — `clean_area.gd` deliberately
lacks every one of these members, so it works whether the rename finished or not; it is a
silent-failure zone, not a canary. And the current design fails *partially*: kills work while
lives are silently free.

**So step 0 is not the rename. It is building the net.**

---

## Two renames, not one

| | Rename A — machinery | Rename B — entity |
|---|---|---|
| `zombie_grid` → `enemy_grid`, `zombies_to_resolve` → `enemies_to_resolve`, `on_zombie_killed` → `on_enemy_killed`, `on_zombie_escaped` → `on_enemy_escaped`, `get_zombies_in_radius` → `get_enemies_in_radius`, `_clear_all_zombies` → `_clear_all_enemies`, group `"zombie"` → `"enemy"` | `entities/enemies/zombie/` → `goblin/`, files, node name `Zombie` → `Goblin`, scene path strings, `clean_area`'s exports |

The machinery is consumed by archer, wizard, arrow, fire, boulder and level_controller — every one
means *any enemy*. `goblin_grid` would be wrong within one commit.

**The codebase already half-agrees.** A1 named its hook `on_enemy_resolved()`, its signal carries
`enemy_count`, and `project.godot:63` names collision layer 1 `"enemies"`. A1 reached for the
neutral word every time it wrote something new. This finishes a seam already drawn.

---

## Enemy foundation

**One shared script with `class_name Enemy`, numbers in a const registry, per-type `.tscn` for
visuals only, event-level virtual hooks — and no per-frame virtual hooks, ever.**

```
Enemy (class_name, extends Area2D)      ← the ENTIRE movement implementation
  ├─ const GROUP, const SEPARATION_RADIUS   (single-sourced; level_controller reads it)
  ├─ @export var enemy_id: String           (identity, set per-.tscn)
  ├─ resolved at _ready() from EnemyTypes:
  │     max_hp, speed, silver_reward, life_cost,
  │     ignore_separation, separation_weight
  ├─ _physics_process / _separation / _move_with_wall_slide / take_damage
  │     — flags checked INLINE, no dispatch
  └─ virtual hooks, empty in base:  _on_spawn()  _on_damaged(amount)  _on_death()
```

**Why no overridable `_separation()`.** CLAUDE.md's recommended next perf attempt is to move the
whole horde into a single manager loop on `level_controller`. Type differences that survive that
rewrite are **data the loop can branch on** (`ignore_separation`, `separation_weight`), not methods
it must dispatch. `if ignore_separation: return Vector2.ZERO` ports across; a subclass override
has to be untangled.

**Goblin, Skeleton and Ogre need no script of their own** — three `.tscn` files differing only in
sprite modulate, scale and `enemy_id`. That *is* "adding the next one is cheap". Only a type with
genuine behaviour (the Troll's enrage) gets a subclass.

This mirrors the house pattern: `archer.gd` has `const TOWER_TYPE` and pulls from
`TowerStats.get_stats()`. Registry-as-const-dict is already used twice (`TowerStats.BASE_STATS`,
`AbilityManager.ABILITIES`) — use it a third time rather than introducing Resource files.

**Circular-preload hazard — resolve before writing a line.** If `enemy_types.gd` preloads
`goblin.tscn`, which uses `enemy.gd`, which preloads `enemy_types.gd`, GDScript refuses it.
**Split by layer:** `systems/enemy_types.gd` holds *numbers only, no preloads*; the scene preloads
live in `wave_manager.gd`, where `ZOMBIE_SCENE` already is. Add a startup check that the two key
sets match.

### Stat table

| | max_hp | speed | silver | life_cost | ignore_sep | sep_weight |
|---|---|---|---|---|---|---|
| Goblin | 10 | **100** | 2 | 1 | false | 1.0 |
| Skeleton | 6 | 280 | 2 | 1 | **true** | 1.0 |
| Ogre | 80 | 100 | 12 | **3** | false | **0.15** |

**Trap — goblin speed is 100, not 200.** `zombie.gd:12` declares `@export var speed = 200.0` but
`zombie.tscn:15` overrides it to `100.0`. The shipped game runs at 100; implementation_plan §2.2's
table says 200. Carry **100** into the registry or you silently double enemy speed and rebalance
everything. Same discipline M1 used ("base stats set to match the pre-refactor game exactly").
Then **delete the `@export`**, so nobody thinks the inspector matters — same rule as tower stats.

---

## Carrying per-type data through uniform systems

### Life cost — cheap, because half of it already exists

`base_health.gd:23` already reads `lose_life(amount: int = 1)`. Only the call chain lacks a
channel: `Enemy._escape()` → `map.on_enemy_escaped(life_cost)` →
`base_health.lose_life(life_cost)`. Default argument keeps the testbed working and makes the
commit purely additive.

> **Guard this in a code comment:** `enemies_to_resolve` must still decrement by **exactly 1**.
> One spawned unit is one resolution unit; life cost is a damage number, not a count. Decrementing
> by 3 for an ogre desyncs `wave_remaining` and ends the round early — the "victory after wave 1"
> class of bug, re-entering through a new door.

The loss short-circuit already handles it: `lives = max(lives - 3, 0)` then `lives <= 0`.

**Expect a tuning consequence:** A1 measured four lives lost across a 408-enemy round. Three
leaked ogres is nine. The 20-life budget stops being generous — which is the point — so
`difficulty_scale = 1.6` must be re-measured, not inherited.

### Wave composition

`WAVE_TABLE` rows gain a `groups` array; `count` stops being authored and becomes **derived**:

```gdscript
{"groups": [{"type": "goblin", "count": 45}, {"type": "skeleton", "count": 8}],
 "spawn_interval": 0.09}
```

**Explicit groups, not weighted random.** This project verifies by measurement — randomised
composition makes every measurement noisy and every regression unreproducible. And "a heavy that
must not be allowed through" means *exactly one ogre in wave 3*, which weights cannot express.

1. Resolve group counts once in `_build_waves()` and derive `count` from the same numbers.
   **Assert `count == plan.size()`** — a one-off disagreement either hangs the round forever or
   resolves it early.
2. Decide `maxi(1, …)` per group deliberately: it means a 1-ogre group can never be scaled away.
   Probably right; don't inherit it by accident.
3. `_start_wave()` builds a flat `Array[String]` spawn plan of length `count`; `_spawn_one()`
   indexes it by `_spawned_this_wave`. Timer, phases, counter split and breather pre-reservation
   are all untouched.

**Deterministic interleave, not shuffle** — distribute each group evenly so the ogre isn't stapled
to the end, and so two runs of a wave are identical. Skeleton "packs of 4" falls out free: emit
them in runs in the plan; the existing 0.04–0.15s interval delivers them near-simultaneously.
**No change to the spawn timer.**

### The separation grid — leave it alone

`SEPARATION_RADIUS = 32.0` is simultaneously four things: grid cell size, query span divisor, the
enemy's own cell-key divisor, and force falloff distance. A per-type radius above 32 silently
misses neighbours, because the enemy scans a fixed 3×3 block. Fixing that means a variable-size
scan **in the hottest loop in the game** — the one still at 4 FPS at 600 enemies after six failed
optimisation attempts. The grid also stores bare `Vector2` deliberately; tagging entries re-opens
the measured lesson that Variant-shaped work in that loop cost 15×. And **A3 rewrites this layer
entirely** — per-type grid work done now is thrown away.

The gameplay need is ~80% met by two data flags needing no grid change:

- **`ignore_separation`** (skeleton) — an early-out; *faster* than a goblin.
- **`separation_weight`** — multiply the *result* of `_separation()` before adding it to the flow
  direction. An ogre at 0.15 barely gets pushed, so the crowd flows around it while it ploughs
  through. One float multiply, receiving side only. It still contributes its position to the grid,
  so it still pushes others — exactly the asymmetry wanted, for free.

Take one free hygiene fix: make `Enemy.SEPARATION_RADIUS` the single definition and have
`level_controller` reference it, retiring the duplicated-const-that-must-stay-equal.

### Tower targeting — a deliberate non-change

`zombies[randi() % zombies.size()]` gives an ogre no priority. **Do not add targeting priority.**
The design answer to "a heavy that must not be allowed through" is Divine Smite — the player's
ability, not the towers' AI. Priority targeting would quietly nullify the ogre's threat, undoing
the enemy just built. Note that `archer.gd:48-56` ≡ `wizard.gd:47-56`; extract nothing.

---

## The abilities — one here, two handed to A5

**A2 ships A-1 Rain of Arrows.** A-2 Divine Smite and A-3 Dragon Fire moved to A5 by decision.
Their design notes are kept below rather than moved wholesale, because they were written against
this codebase and are still accurate — minus the parts A-1 has already built.

**A1's registry generalises well.** Per-id cooldowns (90s and 3s already cannot collide),
selection, number keys, the bar (`for ability_id in manager.ABILITIES` — four slots free), the
`_unhandled_input` routing, and the "payload owns its own numbers" contract all carry unchanged.

**Rain of Arrows** (30s, area over time) — **built and verified.** See *A-1 shipped* above for what
it actually cost, which was more than "zero system change" once the aiming became directional.

### Handed to A5

**Divine Smite** (60s, single target) — fits, with one honest compromise. `cast(id, world_pos)`
gives a position, not a target. Give it a small acquisition radius (~40) and have the payload pick
the **highest-HP enemy** inside it. Eight lines, entirely in the payload; the small circle marker
is an honest preview of the acquisition area. **A whiff consumes the cooldown** — the boulder
already does, and refusing would force the manager to know about targets.

It is the **easy** case now: point-aimed and circular, so it takes the "one registry entry plus one
payload folder" path A-1 demonstrated, with no manager or marker change at all.

**Dragon Fire** (90s, strafing run) — was "the one place the system strains". **A-1 removed most of
that strain:**

- *Direction:* the plan was to **fix the axis** (left→right through the clicked Y) because
  drag-to-aim needed a second aim point and marker rotation. **Both now exist** — A-1's
  `"aim_mode": "directional"` is exactly that, so Dragon Fire can be genuinely aimed and the
  fixed-axis compromise dropped. Decide it at A5 rather than inheriting either answer.
- *Positioning:* costs nothing — but note A-1's correction: a payload **cannot** read its own
  `global_position` or `global_rotation` in `_ready()`, because `cast()` assigns both *after*
  `add_child()`. Read them at first tick, as rain does.
- *The marker:* was "**the one real system change**". **Already built by A-1** — `aim_marker.gd`
  reads an optional `SHAPE` const via `get_script_constant_map()`, defaults to `"circle"`, and
  matches in `_draw()`. Dragon Fire adds a `"strip"` branch to an existing mechanism rather than
  creating the mechanism.
- *The round rule:* a ~2s strafing run is a multi-tick payload, so it obeys A-1's rule — check the
  round at the top of every tick, and `is_instance_valid()` every tick, not once.

### A new bug class A2 introduces

**Payloads can now outlive the round.** The boulder lives 0.5s; a 3-second barrage and a ~2-second
strafing run can be alive when `_end_round(false)` force-clears the board. `is_instance_valid()`
prevents the crash but not the wrongness.

> **Shared rule, established now while there are three payloads and not seven:** any multi-tick
> payload checks `map.round_state == IN_ROUND` at the top of each tick and frees itself otherwise.

### Two tuning consequences to decide, not inherit

- **A 90s cooldown in a ~2.5-minute round is one cast, maybe two.** Rain lands ~4×, Smite ~2×,
  Dragon ~1×. That is a real statement — these are specials, not verbs — and it's correct, but
  know it going in.
- **`reset()` zeroes every cooldown**, so all four are available at wave 1, when they're least
  needed and most wasted. One-line lever:
  `cooldowns[id] = entry.get("initial_cooldown", 0.0)` in `_reset_cooldowns()`.
- Minor UI: a 90s veil drains ~0.7 px/s and reads as static. Add a numeric countdown to a slot
  when remaining > 10s.

---

## Sequencing

Twelve commits. **Every one leaves the game launchable and playable.**

| # | Commit | Files | Done when |
|---|---|---|---|
| 0 | ✅ **R-0 · Harden the contract.** Group joined in code via one const; guards → one cached probe + partial-contract `push_error`; map-side self-check. **No rename.** | `zombie.gd`, `zombie.tscn`, `boulder.gd`, `fire.gd`, `arrow.gd`, `archer.gd`, `wizard.gd`, `level_controller.gd` | ✅ Plays identically; net verified by deliberately breaking it. Self-check is **unconditional**, not gated on `debug_logging` as originally specced — a drifted contract should be loud in every build, and it costs one `has_method()` loop at startup. |
| 1 | **R-1 · Machinery rename** → `enemy_*`, group `"enemy"`. Mechanical. | same 12 files | Grep for machinery names returns 0. Full round **on level_01, not the testbed**, specifically exercising the **escape** path (no towers, watch lives drain). |
| 2 | **R-2 · Entity rename** → goblin. Folder, files, node name, path strings, testbed exports. | `entities/enemies/goblin/*`, `wave_manager.gd`, `clean_area.gd/.tscn` | `grep -ri zombie game/ --exclude-dir=addons` returns 0. Round identical; testbed launches. |
| 3 | ✅ **E-1 · Enemy base + registry, goblin only.** `enemy_types.gd`, stats resolved at `_ready()`, new flags at defaults, hooks empty, `SEPARATION_RADIUS` single-sourced. (`class_name Enemy` already landed in R-0 — it was the enabler for `Enemy.GROUP`.) | `enemy.gd`, `enemy_types.gd`, `goblin.tscn`, `level_controller.gd` | A round is **numerically identical**: same result, comparable lives, 60 FPS at peak. Goblin resolves to speed **100**, hp 10, silver 2. |
| 4 | **E-2 · Life-cost channel.** `on_enemy_escaped(life_cost := 1)`. Purely additive. | `enemy.gd`, `level_controller.gd` | `life_cost = 3` on a live goblin costs 3 lives **and decrements `enemies_to_resolve` by exactly 1**. |
| 5 | **E-3 · Wave composition.** `groups`, derived `count`, spawn plan array. Still 100% goblin. | `wave_manager.gd` | Totals match pre-change exactly (408 at scale 1.6). `count == plan.size()` asserted. |
| 6 | **E-4 · Skeleton.** Registry entry, `.tscn`, `ignore_separation`, pack runs. Waves 2+. | `enemy_types.gd`, `skeleton.tscn`, `wave_manager.gd` | Skeletons visibly slide through the crowd and reach the choke first. FPS holds. |
| 7 | **E-5 · Ogre.** hp 80, `life_cost 3`, `separation_weight 0.15`, bigger sprite, higher silver. Waves 3+. | `enemy_types.gd`, `ogre.tscn`, `wave_manager.gd` | One escaped ogre costs exactly 3 lives. Archer needs 8 hits — **buy a damage upgrade and measure it drop to 7.** That is Known issue 1 closing. |
| 8 | ✅ **A-1 · Rain of Arrows.** Registry entry, area-over-time payload, the shared round-ended rule. | `ability_manager.gd`, `entities/abilities/rain_of_arrows/` | Ticks over duration; silver routes normally; bar shows 2 slots, key `2` selects; **clicking slot 2 casts nothing**; no `previously freed`. |
| 9 | **A-2 · Divine Smite.** Acquisition radius, highest-HP target. No marker change. | `ability_manager.gd`, `entities/abilities/divine_smite/` | Smites an ogre out of a goblin crowd. Whiff still consumes cooldown. |
| 10 | **A-3 · Dragon Fire.** Fixed-axis run; `aim_marker` gains `SHAPE` + `"strip"`. | `ability_manager.gd`, `entities/abilities/dragon_fire/`, `ui/aim_marker/aim_marker.gd` | Run damages along the band; boulder's circle unchanged; a round ending mid-run neither crashes nor damages cleared enemies. |
| 11 | **Tune + verify + docs.** Composition, life budget vs ogres, `difficulty_scale` re-measure, `initial_cooldown`. Update CLAUDE.md (layout, separation, Known issues 1/1b, the `set_group("zombie", …)` gotcha), alpha_plan A2 → ✅. | numbers + docs | Proof cases below pass. |

**Ordering rules:**

- **R-0 → R-1 → R-2 block everything.** Do not write a new payload or enemy before R-1, or you
  write three new files against `get_zombies_in_radius` and rename them too.
- **After R-2, E (3–7) and A (8, now A2's only ability step) are independent** and touch disjoint files — except A-2's
  *verification* wants E-5's Ogre. Two people: parallel, rejoin at 11.
- **E-1 and E-2 are the A1 Step 0 pattern** — additive seams changing nothing observable, so the
  risky commits (E-3 accounting, E-5 balance) land against a proven-unmoved foundation.

---

## Verification

Per CLAUDE.md's *Gotchas*: `execute_code` with `scope_path` `/root/map1` for manager methods;
`click_node` by **runtime-resolved** path (`find_child(...).get_path()` — procedural parents are
auto-named and indices shift); `runtime_get_script_vars` for phase and counters.
`get_global_mouse_position()` is not drivable by `input_simulate` — cast abilities by calling
`cast(id, pos)` directly. Confirm via state, never `dispatched: true`. Hold a round open with a
zero-enemy wave; freeze the horde with `set_group(Enemy.GROUP, "speed", 0.0)` — but sample a live
enemy's position, since it freezes them where they are. No perf claim without a measured
screenshot.

**Two proof cases that will not show up by simply playing:**

1. **Lose during a wave with an ogre and skeletons mid-flight → Play Again → Start.** No ghost
   spawns, no stale spawn plan, both counters zero at PRE_ROUND. E-3's plan array is new
   round-scoped state that `reset()` must clear — the exact shape of the bug A1's Timer fix
   prevented.
2. **A rain barrage ticking, a boulder impacting and two fireballs landing on one dense cluster
   in the same frame — then lose the round during it.** No `previously freed`, no damage applied to
   force-cleared enemies. A1 proved four simultaneous boulders; A2 raises the bar because payloads
   now persist across the round boundary. (Dragon Fire dropped from this case with the A5 move;
   re-add it there.)

---

## Out of scope — named so they are not drifted into

- **The Troll boss** and any boss-wave structure. A2 owes it only the empty `_on_damaged()` hook;
  it then becomes a `.tscn`, a registry entry and a six-line subclass whenever scheduled.
- Per-type separation radius, mass, or any spatial-grid change (A3 owns this layer)
- Tower targeting priority (Divine Smite is the answer — now an A5 item)
- ~~Drag-to-aim direction for Dragon Fire~~ — **no longer out of scope, and no longer future work:**
  A-1 built directional aiming, so A5 inherits it. Struck rather than deleted, because "we decided
  not to" and "we already did" are different states and this list should not blur them.
- A-2 Divine Smite and A-3 Dragon Fire themselves (moved to A5)
- De-duplicating `archer.gd`/`wizard.gd` targeting blocks
- Overlapping waves; anything raising the concurrent-enemy ceiling (A3)
- `TileMapLayer` migration (A3, bundled — Known issue 5)
- Point-hitbox AoE vs large sprites (cosmetic under placeholder art)
