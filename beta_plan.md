# Beta — Free Demo on Steam

**Audience:** Steam browsers who have never heard of the game. The demo's job is to convert a
stranger into a wishlist.

**Graphics: final quality.** Everything the player sees in the demo looks the way it will look
in the finished game. This is the stage where the art lands.

**Content: deliberately incomplete.** Fewer levels than the full game, with a few towers and a
few enemies held back for the paid release.

**Share of remaining work: ~50%**, up from 40% — alpha's **A3 horde engine moved here on
2026-09-07**, bringing ~10% with it. See *The horde engine* below for why.

*(These are rough relative weights, not a partition. They have summed to slightly over 100 since
A4 was added to alpha as its own stage.)*

---

## The shift from alpha

Alpha was judged by whether the game is fun. Beta is judged by whether it is *appealing* — and
those are different tests, run by different people. An itch player who followed the updates
forgives rough edges. A stranger scrolling Steam gives it about twenty seconds.

Everything below follows from that.

---

## What beta contains

### Full art integration · 15%

The single largest block of work in this stage, and the reason beta is 40% rather than 20%.

Every placeholder is replaced: towers, enemies, projectiles, environments, UI. The commission
was briefed during alpha; beta is where it arrives and gets integrated, which is real work in
its own right — sprites need placing, scaling, and animating, not just importing.

Budget for revision rounds. First delivery is rarely final.

### The horde engine · 10% · **moved here from alpha (2026-09-07)**

Getting from the current ~420-enemy ceiling to genuinely overwhelming numbers. This was alpha's
**A3** and it is the largest single technical item in the roadmap. **It was moved to beta for one
reason, and it is worth stating plainly so nobody moves it back on instinct:**

> **The performance work has no visible effect on the game anyone plays.** Waves top out at **152
> concurrent enemies**, which the game already ran at 60 FPS *before* any of A3's optimisation.
> The ceiling is headroom for a horde that has not been designed yet — while the actual blocker on
> shipping was, and is, the missing UI.

Alpha was stalling on an invisible problem. Beta is where a bigger horde earns its keep, because
beta is judged on whether the game is *appealing* to a stranger — and "the screen fills with
enemies" is a screenshot, a trailer shot, and a wishlist.

**What already shipped, in alpha, and does not need redoing:**

- **D-1 — density-gradient separation** (`4901672`). The pairwise 3x3 neighbour scan is gone;
  enemies deposit mass into a flat `PackedFloat32Array` and read its gradient. Measured
  **−40.7% `us_per_enemy`** at 600 packed, no behavioural change. The horde is a continuum now.
- **A working, trustworthy bench** (`systems/bench.gd`, `BENCH_TAG "M-0b"`) — after a real
  measurement bug was found and fixed in it.
- **Three refuted hypotheses**, each measured rather than argued: dictionary hashing (P-2),
  the physics broadphase (S-1), and the manager loop (bounded at ~10%).

**What is left, in the order it should be attempted:**

| | what it buys |
|---|---|
| **D-1b** density-damped speed | the *water* look rather than a diffusing gas. ~7 flops, values already read. **A difficulty change** — gate it off and verify it on its own |
| **D-2** Continuum Crowds proper | congestion feeds back into the flow field, so the horde routes around its own jams. **This is the "water pulled through a maze" the direction decision actually asks for**; D-1 bought the performance and a smoother push, not the routing |
| **X-\*** de-nodify + MultiMesh | the only rung aimed at what remains. Required for anything like 1500 |

The superseded micro-optimisation ladder (P-1, P-3, P-4, G-1, G-2) is kept in
[a3_plan.md](a3_plan.md) as a record of what was measured and refuted. **Do not re-attempt those
without reading it first** — several are already known to be dead ends, and two were refuted the
expensive way.

> [!IMPORTANT]
> **SEQUENCE THIS BEFORE FULL ART INTEGRATION, NOT AFTER.**
>
> `X-*` replaces one `Node2D`-plus-`Sprite2D` per enemy with MultiMesh instances. That is a change
> to **how enemy art is drawn**, not just to how it is simulated. Integrating final enemy art
> first and then de-nodifying means doing the enemy half of the art integration twice.
>
> This is the one hard ordering constraint the move creates. Art integration is 15% of beta and
> the horde engine is 10%; getting them the wrong way round is expensive.

**Timebox it, and keep the current engine as the fallback.** Every rung is independently committed
and measured, so the fallback is simply "stop climbing" — there is no second engine to maintain
and nothing to abandon. Worst case the demo ships with the horde it has today, which already
plays fine.

**One open measurement question inherited from alpha**, and it should be settled before any target
is set: **`16600 / us_per_enemy` may not be the enemy ceiling it is documented to be.** The bench's
`phys_ms` is a per-main-iteration total spanning up to 8 physics steps (Godot's
`max_physics_steps_per_frame` clamp), not a per-tick cost. Ratios between runs are unaffected;
absolute ceilings derived from it are not yet verified. See a3_plan.md's *D-1*.

### Audio · 7%

The project currently has **no audio at all**. Not a note, not a sound effect. This is the
largest unscoped gap in the whole project and it is easy to forget precisely because nothing
breaks without it.

- Sound effects: tower fire, impacts, enemy deaths, ability casts, placement, UI clicks.
- Music: at minimum a menu track and a combat track.

A silent demo reads as unfinished no matter how good it looks.

### All UI screens finished · 6%

The demo is the first time the interface is *judged* rather than merely used.

- Main menu, settings, upgrade screen, pause.
- The debug interface from alpha is retired completely.
- See `ui_plan.md` for the theme system these are built on.

### Demo content scoping · 4%

Deciding what the demo includes is a marketing decision, not an engineering one.

- A subset of levels — enough to show the progression hook, not enough to satisfy.
- A few towers and enemies held back, so the full release has something to reveal.
- The demo should end at a point that makes people want more, not at a point that feels like
  the game simply stopped.

### Steam presence · 4%

- Store page: description, tags, capsules, screenshots.
- Demo build pipeline and the wishlist funnel.

### Balance pass on the demo slice · 3%

Tuned for a **first-time player**, not for the developer who has been playing since alpha and
has a maxed-out upgrade tree. These are wildly different experiences of the same content.

The opening minutes matter more than anything else in the demo.

### Save robustness · 1%

Demo players' progress should survive updates. Getting this wrong once, publicly, costs
goodwill that is hard to win back.

---

## Exit criteria

- A stranger plays the demo start to finish and hits **no placeholder content** — visual or
  audio.
- **The horde is a screenshot.** Battles are large enough that "look at the size of that" is the
  reaction, with a `us_per_enemy` figure from the bench to back it — not an FPS reading, which is
  vsync-quantised and has misled this project repeatedly.
- The demo is visually indistinguishable in quality from the planned final release.
- It ends leaving people wanting the full game.
- Wishlists are accumulating.
