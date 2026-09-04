# Beta — Free Demo on Steam

**Audience:** Steam browsers who have never heard of the game. The demo's job is to convert a
stranger into a wishlist.

**Graphics: final quality.** Everything the player sees in the demo looks the way it will look
in the finished game. This is the stage where the art lands.

**Content: deliberately incomplete.** Fewer levels than the full game, with a few towers and a
few enemies held back for the paid release.

**Share of remaining work: 40%. Cumulative: 80%.**

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
- The demo is visually indistinguishable in quality from the planned final release.
- It ends leaving people wanting the full game.
- Wishlists are accumulating.
